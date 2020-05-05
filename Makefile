
OUTPUT_BASE_DIR = output
SIM_OUTPUT = $(OUTPUT_BASE_DIR)/sim
SYNTH_OUTPUT = $(OUTPUT_BASE_DIR)/synth

CORES = $(shell getconf _NPROCESSORS_ONLN)
THREADS = $(shell echo $$((2 * $(CORES))))

SRC_DIR := $(shell readlink -m src)
TEST_DIR := $(shell readlink -m tests)
SRC = $(shell find -L $(SRC_DIR) -type f \
		-name '*.v' -o -name '*.sv' -o -name '*.vh' | sort)

CORES = $(shell getconf _NPROCESSORS_ONLN)
THREADS = $(shell echo $$((2 * $(CORES))))
SIM_CC = vcs
SIM_CFLAGS = -sverilog -debug_all +memcbk -q -j $(THREADS) +warn=all \
		+lint=PCWM,IWU,TFIPC,ONGS,VNGS,IRIMW,UI,CAWM-L +error+20 \
		-xzcheck nofalseneg
SIM_INC_FLAGS = $(addprefix +incdir+,$(SRC_DIR) $(TEST_DIR))

VCS_BUILD_FILES = csrc $(SIM_EXECUTABLE).daidir
BUILD_EXTRA_FILES = $(addprefix $(SIM_OUTPUT)/,$(VCS_BUILD_FILES))

.PHONY: clean

# The user-facing target to compile the processor simulator into an executable.
build: dirs sim

dirs:
	@mkdir -p $(SIM_OUTPUT)
	@mkdir -p $(SYNTH_OUTPUT)

TOP_FILE := $(shell readlink -m tests/$(TOP))

# Compile the processor into a simulator executable. This target only depends on
# the output directory existing, so don't force it to re-run because of it.
sim: $(SRC) $(TOP_FILE)
	@printf "Compiling design into a simulator in $u$(SIM_OUTPUT)$n...\n"
	@cd $(SIM_OUTPUT) && $(SIM_CC) $(SIM_CFLAGS) $(SIM_INC_FLAGS) \
			$(filter %.v %.sv,$^)

clean:
	@rm -rf $(SIM_OUTPUT)/*
	@rm -rf $(SYNTH_OUTPUT)/*

run:
	@cd $(SIM_OUTPUT) && ./simv

gui:
	@cd $(SIM_OUTPUT) && ./simv -gui &

SYNTH_SCRIPT = dc_synth.tcl
SYNTH_CC = dc_shell-xg-t
DC_SCRIPT := $(shell readlink -m $(SYNTH_SCRIPT))

# If the user specified a clock period, pass it to the DC script
ifneq ($(strip $(CLKP)),)
    SET_CLOCK_PERIOD = set clock_period $(CLKP)
endif

ifneq ($(strip $(TOP)),)
    SET_TOP = set top_module $(TOP)
else
    SET_TOP = set top_module synth_top
endif

# Synthesize the processor into a physical design, generating reports on its
# area, timing, and power
synth: $(SRC) $(DC_SCRIPT)
	@printf "Synthesizing design in $u$(OUTPUT)$n..."
	@cd $(SYNTH_OUTPUT) && $(SYNTH_CC) -f $(DC_SCRIPT) -x "set project_dir $(PWD);  \
		$(SET_TOP) ; $(SET_CLOCK_PERIOD)"

