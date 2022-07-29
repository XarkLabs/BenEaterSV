# BenEaterSV - Ben Eater inspired SAP-1 computer in SystemVerilog
#
# vim: set noet ts=8 sw=8
#
# SPDX-License-Identifier: MIT
#
# File types:
# *.sv           - SystemVerilog design source files
# *.svh          - SystemVerilog design source include headers
# *.json         - intermediate representation for FPGA deisgn from yosys
# *.asc          - intermediate ASCII "bistream" from nextpnr-ice40
# *.bin          - final binary "bitstream" output file used to program FPGA

# This is a "make hack" so make exits if command fails (even if command after pipe succeeds, e.g., tee)
SHELL := /bin/bash -o pipefail

# === SystemVerilog source ===
#   SystemVerilog source and include directory info (uses all *.sv files here in design)
SRCDIR := ../rtl
#   Name of the "main" module of design (in ".sv" file with same name)
FPGATOP := cpusys_iceb
#   SystemVerilog preprocessor definitions common to all modules
DEFINES :=
#   Verilog source files for design
SRC := $(wildcard *.sv) $(wildcard $(SRCDIR)/*.sv)
#   Verilog include files for design
INC := $(wildcard *.svh) $(wildcard $(SRCDIR)/*.svh)
#   iCEBreaker pin definitions file
PIN_DEF := icebreaker.pcf
#   iCEBreaker FPGA device type
DEVICE := up5k
#   iCEBreaker FPGA package
PACKAGE := sg48

# log output directory for tools (spammy, but detailed useful info)
LOGS := logs

# icestorm tools:
# all tool binaries assumed in default path (e.g. oss-cad-suite with:
# source <extracted_location>/oss-cad-suite/environment"
YOSYS := yosys
YOSYS_CONFIG := yosys-config
ICEPACK := icepack
# Use iceprog.exe under WSL (due to USB issues with Linux utlity)
# NOTE: Windows may still require Zadig driver installation. For more info see
# https://gojimmypi.blogspot.com/2020/12/ice40-fpga-programming-with-wsl-and.html
ifneq ($(shell uname -a | grep -i Microsoft),)
ICEPROG := iceprog.exe
else
ICEPROG := iceprog
endif
# Invokes yosys-config to find the proper path to the iCE40 simulation library (primitive definitions)
TECH_LIB := $(shell $(YOSYS_CONFIG) --datdir/ice40/cells_sim.v)
# nextpnr iCE40 tool:
NEXTPNR := nextpnr-ice40

# Yosys warning/error options:
# (makes "no driver" warning an error, you can also suppress spurious warnings
# so they only appear in log file with -w, e.g. adding:  -w "tri-state"
# would suppress the warning shown when you use 1'bZ: "Yosys has only limited
# support for tri-state logic at the moment.")
YOSYS_OPTS := -e "no driver"
# Yosys synthesis options:
# ("ultraplus" device, enable DSP inferrence, ABC9 logic optimization and explicitly set top module name)
YOSYS_SYNTH_OPTS := -device u -dsp -abc9
# (this prevents spurious warnings in TECH_LIB files)
DEFINES += -DNO_ICE40_DEFAULT_ASSIGNMENTS
# nextpnr-ice40 options
# (use "heap" placer, enable promotion of logic to global nets, optimize for best timing)
NEXTPNR_OPTS := --placer heap --promote-logic --opt-timing
#   Verilator executable
VERILATOR := verilator
#   Verilator options (used for "lint" for much more friendly error messages - and also strict warnings)
#   If you are getting "annoyed", you can add -Wno-fatal so warnings aren't fatal, but IMHO better to just fix them. :)
#   Also, a few overly annoying ones are disabled here, but you can also disable other ones to you don't wish to heed
#   e.g. -Wno-UNUSED
#   A nice guide to the warnings, what they mean and how to appese them is https://verilator.org/guide/latest/warnings.html
#   (SystemVerilog files, language version, lib dir, include dir and warning options)
VERILATOR_OPTS := -sv --language 1800-2012 --trace-fst -v $(TECH_LIB) -I$(SRCDIR) -Wall -Wno-DECLFILENAME
VLT_CONFIG := ice40_config.vlt

all: $(FPGATOP).bin

# show info on make targets
info:
	@echo "make targets:"
	@echo "    make iceb       - synthesize iCEBreaker FPGA bitstream for design"
	@echo "    make prog       - program iCEBreaker bitstream via USB"
	@echo "    make clean      - clean most files that can be rebuilt"

iceb: $(FPGATOP).bin

prog: $(FPGATOP).bin
	$(ICEPROG) -d i:0x0403:0x6010 $(FPGATOP).bin

# disable UNUSED and UNDRIVEN warnings in cells_sim.v library for Verilator lint
$(VLT_CONFIG):
	@echo >$(VLT_CONFIG)
	@echo >>$(VLT_CONFIG) \`verilator_config
	@echo >>$(VLT_CONFIG) lint_off -rule UNUSED  -file \"$(TECH_LIB)\"
	@echo >>$(VLT_CONFIG) lint_off -rule UNDRIVEN  -file \"$(TECH_LIB)\"

# defult target is to make FPGA bitstream for design
$(FPGATOP).json: $(SRC) $(INC) $(VLT_CONFIG) $(PIN_DEF) $(MAKEFILE_LIST)

$(FPGATOP).bin: $(FPGATOP).json

# delete all targets that will be re-generated
clean:
	rm -f $(VLT_CONFIG) $(FPGATOP).asc $(FPGATOP).json $(FPGATOP).bin

# common rules to run FPGA tools
include ../common.mk

# prevent make from deleting any intermediate files
.SECONDARY:

# inform make about "phony" convenience targets
.PHONY: all info bin prog clean
