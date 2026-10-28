# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
FST ?= -fst
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src

# Core RTL files (No physical SRAM .v model needed here)
PROJECT_SOURCES =   tt_um_pio_core.sv \
                    asic_top.sv \
                    core_top.sv \
                    alu.sv \
                    decoder.sv \
                    dp_sram.sv \
                    fifo.sv \
                    reg_file.sv \
                    smu.sv \
                    spi.sv \
                    timing_controller.sv

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD       = sim_build/rtl
COMPILE_ARGS   += -g2012
COMPILE_ARGS   += -DFUNCTIONAL
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate level simulation:
SIM_BUILD       = sim_build/gl
COMPILE_ARGS   += -DGL_TEST
COMPILE_ARGS   += -DFUNCTIONAL
COMPILE_ARGS   += -DSIM

# IHP SG13G2 primitives
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_io/verilog/sg13g2_io.v
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v
VERILOG_SOURCES += $(PWD)/models/SRAM_2P_core_behavioral_bm_bist_ideal.v
VERILOG_SOURCES += $(SRC_DIR)/RM_IHPSG13_2P_512x16_c2_bm_bist.v

# The synthesized gate-level netlist
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS    += -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# MODULE is the basename of the Python test file
MODULE = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim