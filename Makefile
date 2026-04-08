PROJ = watchdog
BUILD = build
MOUNT = /media/lg/iCELink

SRC = hardware/cgp_core.v hardware/watchdog_wrapper.v hardware/top.v
PCF = constraints/top.pcf


all: $(BUILD)/$(PROJ).bin

# synteza Yosys
$(BUILD)/$(PROJ).json: $(SRC)
	mkdir -p $(BUILD)
	yosys -p 'synth_ice40 -top top -json $@' $(SRC)

# place & route NextPNR
$(BUILD)/$(PROJ).asc: $(BUILD)/$(PROJ).json $(PCF)
	nextpnr-ice40 --lp1k --package cm36 --json $< --pcf $(PCF) --asc $@

# generowanie bitstreamu Icepack
$(BUILD)/$(PROJ).bin: $(BUILD)/$(PROJ).asc
	icepack $< $@

# wgranie do pamieci Flash
prog: $(BUILD)/$(PROJ).bin
	@echo "wgrywanie na ice"
	cp $< $(MOUNT)/
	sync
	@echo "koniec wgrywania"

# wgranie bezposrednie do pamieci ulotnej SRAM (ochrona ukladu podczas ewolucji)
#prog_sram: $(BUILD)/$(PROJ).bin
#	icesprog -t $<

clean:
	rm -rf $(BUILD)

.PHONY: all prog prog_sram clean
