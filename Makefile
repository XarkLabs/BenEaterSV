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
SRCDIR := rtl
#   Name of the "main" module for design (in ".sv" file with same name)
MAIN := cpu_main
# SystemVerilog preprocessor definitions common to all modules
DEFINES :=
#   Verilog source files for design
SRC := $(wildcard $(SRCDIR)/*.sv)
#   Verilog include files for design
INC := $(wildcard $(SRCDIR)/*.svh)
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

#   Name of "top" SystemVerilog UUT module (below testbench)
VTOP := cpu_main

# === Icarus Verilog simulation (using Verilog testbench) ===
#   Icarus Verilog output directory
ISIMDIR := isim
#   Name of the SystemVerilog testbench module for Icarus Verilog (in ".sv" file with same name)
ISIM_TB := cpu_tb
#   Name of Icarus Verilog simulation "vvp" output file
ISIMOUT := cpu_isim
#   Icarus Verilog executables
IVERILOG := iverilog
VVP := vvp
#   Icarus Verilog options: (language version, library dir, include dir, warning options)
IVERILOG_OPTS := -g2012 -l$(TECH_LIB) -I$(SRCDIR) -Wall

# == Verilator simulation (using C++ testbench) ==
#   Verilator output directory
VSIMDIR := vsim
#   Verillator C++ testbench
VSIMCSRC := cpu_vsim.cpp
#   C++ flags used when building C++ testbench
VSIMCFLAGS := -Wall -Wextra
#   Command line options to pass Verilog simuation executable
VRUN_OPTS :=
#   Basename for synthesis output files
VOUTNAME := cpu_vsim
#   Verilator executable
VERILATOR := verilator
#   Verilator options (used for "lint" for much more friendly error messages - and also strict warnings)
#   If you are getting "annoyed", you can add -Wno-fatal so warnings aren't fatal, but IMHO better to just fix them. :)
#   Also, a few overly annoying ones are disabled here, but you can also disable other ones to you don't wish to heed
#   e.g. -Wno-UNUSED
#   A nice guide to the warnings, what they mean and how to appese them is https://verilator.org/guide/latest/warnings.html
#   (SystemVerilog files, language version, lib dir, include dir and warning options)
VERILATOR_OPTS := -sv --language 1800-2012 --trace-fst -v $(TECH_LIB) -I$(SRCDIR) -Wall -Wno-DECLFILENAME

# NOTE: These are for Yosys "count" and "show" operations (not "real" FPGA)
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

# show info on make targets
info:
	@echo "make targets:"
	@echo "    make all        - build all targets below (except USB prog)"
	@echo "    make isim       - build Icarus Verilog simulation for design"
	@echo "    make irun       - run Icarus Verilog simulation of design"
	@echo "    make vsim       - build Verilator C++ simulation for design"
	@echo "    make vrun       - run Verilator C++ simulation of design"
	@echo "    make count      - show design module resource usage counts"
	@echo "    make show       - show graphical diagram of design modules"
	@echo "    make upd        - synthesize UPduino FPGA bitstream for design"
	@echo "    make upd_prog   - program UPduino FPGA bitstream via USB"
	@echo "    make iceb       - synthesize iCEBreaker FPGA bitstream for design"
	@echo "    make iceb_prog  - program iCEBreaker FPGA bitstream via USB"
	@echo "    make clean      - clean most files that can be rebuilt"

# defult target is to make FPGA bitstream for design
all: isim vsim count

# synthesize UPduino FPGA bitstream for design
upd:
	@cd upduino && make -f Makefile

# program UPduino FPGA via USB (may need udev rules or sudo on Linux)
upd_prog:
	@cd upduino && make -f Makefile prog

# synthesize iCEBreaker FPGA bitstream for design
iceb:
	@cd icebreaker && make -f Makefile

# program iCEBreaker FPGA via USB (may need udev rules or sudo on Linux)
iceb_prog:
	@cd icebreaker && make -f Makefile prog

# run Yosys with "noflatten", which will produce a resource count per module
count: $(SRC) $(INC) $(MAKEFILE_LIST)
	@echo === Couting Design Resources Used ===
	@mkdir -p $(LOGS)
	$(YOSYS) $(YOSYS_OPTS) -l $(LOGS)/$(VTOP)_yosys_count.log -q -p 'verilog_defines $(DEFINES) ; read_verilog -I$(SRCDIR) -sv $(SRC) ; synth_ice40 $(YOSYS_SYNTH_OPTS) -noflatten'
	@sed -n '/Printing statistics/,/Executing CHECK pass/p' $(LOGS)/$(VTOP)_yosys_count.log | sed '$$d'
	@echo === See $(LOGS)/$(VTOP)_yosys_count.log for resource use details ===

# use Icarus Verilog to build and run simulation executable
isim: $(ISIMDIR)/$(ISIMOUT) $(ISIMDIR)/$(ISIM_TB).sv $(SRC) $(INC) $(MAKEFILE_LIST)
	@echo === Icarus Verilog files built, use \"make irun\" to run ===

# use Icarus Verilog to run simulation executable
irun: $(ISIMDIR)/$(ISIMOUT) $(MAKEFILE_LIST)
	@echo === Running Icarus Verilog simulation ===
	@mkdir -p $(LOGS)
	$(VVP) $(ISIMDIR)/$(ISIMOUT) -fst
	@echo === Icarus Verilog simulation done, use \"gtkwave logs/$(ISIM_TB).fst\" to view waveforms ===

# build native simulation executable
vsim: $(VSIMDIR)/obj_dir/V$(VTOP) $(MAKEFILE_LIST)
	@echo === Completed building Verilator simulation, use \"make vrun\" to run.

# run Verilator to build and run native simulation executable
vrun: $(VSIMDIR)/obj_dir/V$(VTOP) $(MAKEFILE_LIST)
	@echo === Running Verilator simulation ===
	@mkdir -p $(LOGS)
	$(VSIMDIR)/obj_dir/V$(VTOP) $(VRUN_OPTS)
	@echo === Verilator simulation done, use \"gtkwave logs/cpu_vsim.fst\" to view waveforms ===

# use Icarus Verilog to build vvp simulation executable
$(ISIMDIR)/$(ISIMOUT): $(ISIMDIR)/$(ISIM_TB).sv $(INC) $(SRC) $(MAKEFILE_LIST)
	@echo === Building Icarus Verilog simulation ===
	@mkdir -p $(LOGS)
	@rm -f $@
	$(VERILATOR) --lint-only $(VERILATOR_OPTS) -Wno-STMTDLY $(DEFINES) --top-module $(ISIM_TB) $(ISIMDIR)/$(ISIM_TB).sv $(SRC)
	$(IVERILOG) $(IVERILOG_OPTS) $(DEFINES) -o $@ -s $(ISIM_TB) $(ISIMDIR)/$(ISIM_TB).sv $(SRC)

# use Verilator to build native simulation executable
$(VSIMDIR)/obj_dir/V$(VTOP): $(VSIMDIR)/$(VSIMCSRC) $(INC) $(SRC) $(MAKEFILE_LIST)
	@echo === Building Verilator simulation ===
	$(VERILATOR) $(VERILATOR_OPTS) --Mdir $(VSIMDIR)/obj_dir --cc --exe --trace $(DEFINES) -CFLAGS "$(VSIMCFLAGS)" $(LDFLAGS) --top-module $(VTOP) $(SRC) $(VSIMCSRC)
	cd $(VSIMDIR)/obj_dir && make -f V$(VTOP).mk

# delete all targets that will be re-generated
clean:
	rm -f $(ISIMDIR)/$(ISIMOUT) $(wildcard $(VSIMDIR)/obj_dir/*)
	@cd upduino && make -f Makefile clean
	@cd icebreaker && make -f Makefile clean


# prevent make from deleting any intermediate files
.SECONDARY:

# inform make about "phony" convenience targets
.PHONY: info all bin prog count isim irun vsim vrun clean
