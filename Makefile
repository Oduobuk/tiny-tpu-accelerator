.PHONY: all test test-pe test-tpu clean help

PYTHON ?= .venv/bin/python
SIM ?= icarus

all: test

test: test-pe test-tpu
	@echo ""
	@echo "=========================================================="
	@echo "  ALL TINY-TPU HARDWARE REGRESSION SUITES PASSED 100%!"
	@echo "=========================================================="

test-pe:
	@echo ">>> Running Processing Element (PE) Unit Verification..."
	PATH="$(CURDIR)/.venv/bin:/opt/homebrew/bin:$(PATH)" \
	$(MAKE) -C tests clean
	PATH="$(CURDIR)/.venv/bin:/opt/homebrew/bin:$(PATH)" \
	$(MAKE) -C tests MODULE=test_pe TOPLEVEL=pe

test-tpu:
	@echo ">>> Running End-to-End Matrix Multiplication Suite..."
	PATH="$(CURDIR)/.venv/bin:/opt/homebrew/bin:$(PATH)" \
	$(MAKE) -C tests clean
	PATH="$(CURDIR)/.venv/bin:/opt/homebrew/bin:$(PATH)" \
	$(MAKE) -C tests MODULE=test_tpu TOPLEVEL=tiny_tpu_top

clean:
	$(MAKE) -C tests clean
	rm -rf tests/sim_build tests/__pycache__ tests/*.vcd tests/*.xml .pytest_cache

help:
	@echo "Tiny-TPU Verification Commands:"
	@echo "  make test      : Runs PE and full TPU matrix multiplication tests"
	@echo "  make test-pe   : Runs PE unit testbench only"
	@echo "  make test-tpu  : Runs top-level TPU testbench only"
	@echo "  make clean     : Removes simulation artifacts"
