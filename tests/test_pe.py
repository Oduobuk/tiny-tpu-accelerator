import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ReadOnly
import random

@cocotb.test()
async def test_pe_reset(dut):
    """Test PE reset behavior."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.en.value = 0
    dut.load_weight.value = 0
    dut.act_in.value = 0
    dut.weight_in.value = 0
    dut.sum_in.value = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    assert dut.act_out.value.to_signed() == 0, "act_out not zero after reset"
    assert dut.sum_out.value.to_signed() == 0, "sum_out not zero after reset"


@cocotb.test()
async def test_pe_mac_operations(dut):
    """Verify weight-stationary MAC computation across random vectors."""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # 1. Reset
    dut.rst_n.value = 0
    dut.en.value = 0
    dut.load_weight.value = 0
    dut.act_in.value = 0
    dut.sum_in.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test across multiple stationary weights
    test_weights = [-128, -50, -1, 0, 1, 42, 127]

    for weight in test_weights:
        # 2. Load weight
        dut.load_weight.value = 1
        dut.weight_in.value = weight
        await RisingEdge(dut.clk)
        dut.load_weight.value = 0

        current_sum = 0
        for step in range(10):
            act = random.randint(-128, 127)
            sum_in = current_sum

            dut.en.value = 1
            dut.act_in.value = act
            dut.sum_in.value = sum_in

            await RisingEdge(dut.clk)
            await Timer(1, unit="ps")  # Allow non-blocking assignments to settle

            expected_act_out = act
            expected_sum_out = sum_in + (act * weight)

            actual_act_out = dut.act_out.value.to_signed()
            actual_sum_out = dut.sum_out.value.to_signed()

            assert actual_act_out == expected_act_out, (
                f"Mismatch act_out at step {step}: expected {expected_act_out}, got {actual_act_out}"
            )
            assert actual_sum_out == expected_sum_out, (
                f"Mismatch sum_out at step {step} (W={weight}, Act={act}, SumIn={sum_in}): "
                f"expected {expected_sum_out}, got {actual_sum_out}"
            )
            current_sum = expected_sum_out

    dut._log.info("Processing Element (PE) MAC verification passed 100%!")
