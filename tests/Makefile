SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES = $(CURDIR)/../rtl/pe.sv \
                  $(CURDIR)/../rtl/data_skewer.sv \
                  $(CURDIR)/../rtl/systolic_array.sv \
                  $(CURDIR)/../rtl/tiny_tpu_top.sv

TOPLEVEL ?= tiny_tpu_top
MODULE ?= test_tpu

COMPILE_ARGS += -g2012

include $(shell cocotb-config --makefiles)/Makefile.sim
