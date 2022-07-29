# Makefile fragment with common FPGA synthesis rules

ifndef DEVICE
$(error FPGA DEVICE is not set)
endif
ifndef PACKAGE
$(error FPGA PACKAGE is not set)
endif
ifndef PIN_DEF
$(error FPGA PIN_DEF is not set)
endif
ifndef FPGATOP
$(error FPGA FPGATOP is not set)
endif
LOGS ?= .

# synthesize SystemVerilog and create json description of design
%.json : %.sv
	@echo === Synthesizing FPGA design ===
	@rm -f $@
	@mkdir -p $(LOGS)
	$(VERILATOR) --lint-only $(VERILATOR_OPTS) $(DEFINES) --top-module $(FPGATOP) $(VLT_CONFIG) $(filter %.sv,$^) 2>&1 | tee $(LOGS)/$(basename $(notdir $@))_verilator.log
	$(YOSYS) $(YOSYS_OPTS) -l $(LOGS)/$(basename $(notdir $@))_yosys.log -q -p 'verilog_defines $(DEFINES) ; read_verilog -sv -I$(SRCDIR) $(filter %.sv,$^) ; synth_ice40 $(YOSYS_SYNTH_OPTS) -json $@'

# make BIN bitstream from JSON description and device parameters
%.bin : %.json
	@echo === Routing FPGA design ===
	@rm -f $@
	@mkdir -p $(LOGS)
	$(NEXTPNR) -l $(LOGS)/$(basename $(notdir $@))_nextpnr.log -q $(NEXTPNR_OPTS) --$(DEVICE) --package $(PACKAGE) --json $< --pcf $(PIN_DEF) --asc $(basename $(notdir $@)).asc
	$(ICEPACK) $(basename $(notdir $@)).asc $@
	@rm $(basename $(notdir $@)).asc
	@echo === Synthesis stats for $(basename $(notdir $@)) on $(DEVICE) === | tee $(LOGS)/$(basename $(notdir $@))_stats.txt
	@-tabbyadm version | grep "Package" | tee -a $(LOGS)/$(basename $(notdir $@))_stats.txt
	@$(YOSYS) -V 2>&1 | tee -a $(LOGS)/$(basename $(notdir $@))_stats.txt
	@$(NEXTPNR) -V 2>&1 | tee -a $(LOGS)/$(basename $(notdir $@))_stats.txt
	@sed -n '/Device utilisation/,/Info: Placed/p' $(LOGS)/$(basename $(notdir $@))_nextpnr.log | sed '$$d' | grep -v ":     0/" | tee -a $(LOGS)/$(basename $(notdir $@))_stats.txt
	@grep "Max frequency" $(LOGS)/$(basename $(notdir $@))_nextpnr.log | tail -1 | tee -a $(LOGS)/$(basename $(notdir $@))_stats.txt
	@echo
