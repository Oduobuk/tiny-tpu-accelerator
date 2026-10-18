import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import numpy as np
from test_tpu import pack_weights, pack_row, unpack_row, ARRAY_SIZE

@cocotb.test()
async def trace_exact_latency(dut):
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.load_weights.value = 0
    dut.start_compute.value = 0
    dut.act_row_in.value = 0
    dut.weights.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Simple Identity weights matrix B = I
    B = np.eye(ARRAY_SIZE, dtype=np.int8) * 2
    dut.load_weights.value = 1
    dut.weights.value = pack_weights(B)
    await RisingEdge(dut.clk)
    dut.load_weights.value = 0
    dut.weights.value = 0

    # Matrix A has row k = [k+1, k+1, k+1, k+1]
    A = np.array([
        [1, 2, 3, 4],
        [5, 6, 7, 8],
        [9, 10, 11, 12],
        [13, 14, 15, 16]
    ], dtype=np.int8)

    C_golden = np.matmul(A.astype(np.int32), B.astype(np.int32))
    dut._log.info(f"Target Golden C:\n{C_golden}")

    for cycle in range(25):
        if cycle < ARRAY_SIZE:
            dut.start_compute.value = 1 if cycle == 0 else 0
            dut.act_row_in.value = pack_row(A[cycle, :])
        else:
            dut.start_compute.value = 0
            dut.act_row_in.value = 0

        await RisingEdge(dut.clk)
        await Timer(1, unit="ps")

        res_row = unpack_row(int(dut.result_row_out.value))
        dut._log.info(f"Cycle {cycle:2d}: result_row = {res_row}, valid_out = {int(dut.valid_out.value)}, busy = {int(dut.busy.value)}")

