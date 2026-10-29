# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
FST ?= -fst # Use more efficient FST format
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
VERILOG_SOURCES += $(PWD)/models/RM_IHPSG13_2P_core_behavioral_bm_bist_ideal.v
VERILOG_SOURCES += $(PWD)/models/RM_IHPSG13_2P_512x16_c2_bm_bist.v

else

# Gate level simulation:
SIM_BUILD       = sim_build/gl
COMPILE_ARGS   += -g2012
COMPILE_ARGS   += -DGL_TEST
COMPILE_ARGS   += -DFUNCTIONAL
COMPILE_ARGS   += -DSIM

# Cell models for the PDK in $(PDK) (ihp-sg13cmos5l or ihp-sg13g2), e.g. sg13cmos5l_stdcell.v
PDK ?= ihp-sg13cmos5l
PDK_CELL_PREFIX = $(patsubst ihp-%,%,$(PDK))
PDK_LIBS_REF = $(PDK_ROOT)/$(PDK)/libs.ref
VERILOG_SOURCES += $(PDK_LIBS_REF)/$(PDK_CELL_PREFIX)_io/verilog/$(PDK_CELL_PREFIX)_io.v
# Newer PDK versions ship the UDP (user-defined primitive) models in a separate file
VERILOG_SOURCES += $(wildcard $(PDK_LIBS_REF)/$(PDK_CELL_PREFIX)_stdcell/verilog/$(PDK_CELL_PREFIX)_udp.v)
VERILOG_SOURCES += $(PDK_LIBS_REF)/$(PDK_CELL_PREFIX)_stdcell/verilog/$(PDK_CELL_PREFIX)_stdcell.v

# SRAM behavioral models for GL simulation
VERILOG_SOURCES += $(PWD)/models/RM_IHPSG13_2P_core_behavioral_bm_bist_ideal.v
VERILOG_SOURCES += $(PWD)/models/RM_IHPSG13_2P_512x16_c2_bm_bist.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS    += -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# List test modules to run, separated by commas and without the .py suffix:
COCOTB_TEST_MODULES = test
MODULE = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim