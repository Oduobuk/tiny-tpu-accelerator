import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import numpy as np

ARRAY_SIZE = 4
DATA_WIDTH = 8
ACC_WIDTH  = 32

def pack_weights(matrix_b):
    """Packs an (ARRAY_SIZE x ARRAY_SIZE) matrix into a single flat integer for Verilog."""
    val = 0
    flat = matrix_b.flatten()
    for idx, item in enumerate(flat):
        uval = int(item) & 0xFF
        val |= (uval << (idx * 8))
    return val

def pack_row(row):
    """Packs a 1D vector of length ARRAY_SIZE into an integer."""
    val = 0
    for idx, item in enumerate(row):
        uval = int(item) & 0xFF
        val |= (uval << (idx * 8))
    return val

def unpack_row(val):
    """Unpacks an integer into a list of signed 32-bit integers."""
    row = []
    for idx in range(ARRAY_SIZE):
        uval = (val >> (idx * 32)) & 0xFFFFFFFF
        if uval & 0x80000000:
            uval -= 0x100000000
        row.append(uval)
    return row

@cocotb.test()
async def test_matrix_multiplication_golden(dut):
    """Verify end-to-end 4x4 matrix multiplication across 10 random batches against NumPy."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # 1. Hardware Reset
    dut.rst_n.value = 0
    dut.load_weights.value = 0
    dut.start_compute.value = 0
    dut.act_row_in.value = 0
    dut.weights.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    num_batches = 10
    for iteration in range(num_batches):
        # Ensure TPU is idle before configuring next job
        while int(dut.busy.value) == 1:
            await RisingEdge(dut.clk)

        # Generate random signed INT8 matrices
        A = np.random.randint(-40, 40, size=(ARRAY_SIZE, ARRAY_SIZE), dtype=np.int8)
        B = np.random.randint(-40, 40, size=(ARRAY_SIZE, ARRAY_SIZE), dtype=np.int8)
        
        # Golden reference: C = A x B in int32
        C_golden = np.matmul(A.astype(np.int32), B.astype(np.int32))

        # 2. Preload weights
        dut.load_weights.value = 1
        dut.weights.value = pack_weights(B)
        await RisingEdge(dut.clk)
        dut.load_weights.value = 0
        dut.weights.value = 0
        await RisingEdge(dut.clk)

        # 3. Stream activations and capture outputs
        captured_rows = []

        for r in range(ARRAY_SIZE):
            dut.start_compute.value = 1 if r == 0 else 0
            dut.act_row_in.value = pack_row(A[r, :])
            await RisingEdge(dut.clk)
            await Timer(1, unit="ps")
            if int(dut.valid_out.value) == 1:
                captured_rows.append(unpack_row(int(dut.result_row_out.value)))

        dut.start_compute.value = 0
        dut.act_row_in.value = 0

        # Drain pipeline until all ARRAY_SIZE rows are collected
        for _ in range(ARRAY_SIZE * 4):
            await RisingEdge(dut.clk)
            await Timer(1, unit="ps")
            if int(dut.valid_out.value) == 1:
                captured_rows.append(unpack_row(int(dut.result_row_out.value)))
            if len(captured_rows) == ARRAY_SIZE:
                break

        C_hardware = np.array(captured_rows, dtype=np.int32)

        # Assert bit-exact mathematical parity
        np.testing.assert_array_equal(
            C_hardware, C_golden,
            err_msg=f"Matrix mismatch at batch iteration {iteration}!"
        )
        dut._log.info(f"Batch {iteration+1:2d}/{num_batches}: PASS -> Bit-exact match with NumPy golden matrix")

    dut._log.info("\n===================================================================")
    dut._log.info(">>> 10/10 CONSECUTIVE RANDOM MATRIX MULTIPLICATIONS VERIFIED 100% <<<")
    dut._log.info("===================================================================")
