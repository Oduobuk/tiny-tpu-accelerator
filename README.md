# Tiny-TPU Accelerator

[![Hardware Tests](https://img.shields.io/badge/Hardware%20Tests-100%25%20Passing-brightgreen.svg)](#verification--results)
[![Precision](https://img.shields.io/badge/Precision-INT8%20%7C%20INT32%20Acc-blue.svg)](#microarchitecture)
[![Verification](https://img.shields.io/badge/Verification-Cocotb%20%7C%20Icarus-orange.svg)](#verification--results)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

An open-source, synthesizable **$4 \times 4$ Weight-Stationary Systolic Array Neural Accelerator** implemented in SystemVerilog, modeled after the Google TPU v1 tensor processing unit architecture.

Designed for edge AI matrix-multiplication acceleration ($C = A \times B$), featuring integrated input activation skewing, localized Processing Element (PE) pipelining, and automatic output deskewing for synchronized matrix row collection.

---

## 🏛️ Microarchitecture Overview

```
                      Activations In (Row-wise unskewed)
                                     │
                             ┌───────▼───────┐
                             │  Data Skewer  │  (Temporal delay line: Row i delayed by i cycles)
                             └───────┬───────┘
                                     │
                 ┌───────────────────▼───────────────────┐
                 │       4x4 Systolic Array Grid         │
                 │                                       │
                 │   [PE 0,0] ──► [PE 0,1] ──► [PE 0,2] ──► [PE 0,3]
                 │      │            │            │            │
                 │      ▼            ▼            ▼            ▼
                 │   [PE 1,0] ──► [PE 1,1] ──► [PE 1,2] ──► [PE 1,3]
                 │      │            │            │            │
                 │      ▼            ▼            ▼            ▼
                 │   [PE 2,0] ──► [PE 2,1] ──► [PE 2,2] ──► [PE 2,3]
                 │      │            │            │            │
                 │      ▼            ▼            ▼            ▼
                 │   [PE 3,0] ──► [PE 3,1] ──► [PE 3,2] ──► [PE 3,3]
                 │      │            │            │            │
                 └──────┼────────────┼────────────┼────────────┼─────┘
                        │            │            │            │  (Staggered column partial sums)
                             ┌───────▼───────┐
                             │ Output Deskew │  (Inverted delay line: Col c delayed by 3-c cycles)
                             └───────┬───────┘
                                     │
                     Results Out (Parallel synchronized C rows)
```

### Key Technical Specs
* **Arithmetic Precision:** Signed **INT8** (`[-128, 127]`) activations and stationary weights; signed **INT32** accumulation buffer to eliminate numerical overflow.
* **Dataflow Paradigm:** **Weight-Stationary (WS)**:
  * Weights $B$ are preloaded into internal PE registers via single-cycle control strobe.
  * Input activations $A$ stream from West to East across horizontal registers.
  * Partial sums accumulate and stream from North to South across vertical registers.
* **Integrated Latency Management:**
  * **Input Skewer:** Staggers rows dynamically by $i$ clock cycles to establish a diagonal processing wavefront.
  * **Output Deskewer:** Re-synchronizes columns arriving at different timestamps so that full $1 \times N$ matrix rows emerge simultaneously on `result_row_out`.
* **Throughput:** $16$ MAC operations per clock cycle ($32$ operations/cycle).

---

## 📁 Repository Structure

```
tiny-tpu-accelerator/
├── Makefile                # Top-level build & test orchestration
├── rtl/
│   ├── pe.sv               # Individual Processing Element (MAC + Storage)
│   ├── data_skewer.sv      # Wavefront temporal skewing delay pipeline
│   ├── systolic_array.sv   # 2D N x N mesh interconnect
│   └── tiny_tpu_top.sv     # Top-level engine with FSM & output deskewer
├── tests/
│   ├── Makefile            # Cocotb simulation harness (Icarus / Verilator)
│   ├── test_pe.py          # Unit testbench for isolated PE arithmetic
│   └── test_tpu.py         # 10-batch random matrix regression against NumPy
└── README.md
```

---

## 🔬 Verification & Results

Following strict **evidence-based hardware verification**, the testbench does not rely on hardcoded static mocks. It utilizes **Cocotb** (coroutine-driven Python testbenches) driving **Icarus Verilog**:

1. **Unit Testing (`test_pe.py`):**
   * Verifies reset state, stationary weight latching, signed arithmetic limits, and boundary cases ($-128$, $127$, $0$).
2. **End-to-End Regression (`test_tpu.py`):**
   * Generates $10$ consecutive random signed INT8 matrix pairs ($A \in \mathbb{Z}^{4 \times 4}$, $B \in \mathbb{Z}^{4 \times 4}$).
   * Preloads weights, streams skewed inputs, and captures streaming output rows.
   * Compares the hardware output against a **NumPy / PyTorch golden reference**:
     $$\mathbf{C}_{\text{hardware}} \equiv \mathbf{A} \times \mathbf{B}$$
   * **Result:** **100% bit-exact mathematical parity across all batches.**

### Running Verification Locally

```bash
# 1. Install simulation dependencies (macOS)
brew install icarus-verilog

# 2. Setup virtual environment & run test suite
make test
```

Sample test output:
```text
Batch  1/10: PASS -> Bit-exact match with NumPy golden matrix
Batch  2/10: PASS -> Bit-exact match with NumPy golden matrix
...
Batch 10/10: PASS -> Bit-exact match with NumPy golden matrix
===================================================================
>>> 10/10 CONSECUTIVE RANDOM MATRIX MULTIPLICATIONS VERIFIED 100% <<<
===================================================================
```

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
