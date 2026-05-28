PROJ = watchdog
BUILD = build
MOUNT = /media/lg/iCELink

SRC = hardware/cgp_core.v hardware/wrapper.v
PCF = constraints/top.pcf


all: $(BUILD)/$(PROJ).bin

# synteza Yosys
$(BUILD)/$(PROJ).json: $(SRC)
	mkdir -p $(BUILD)
	yosys -p 'synth_ice40 -top wrapper -json $@' $(SRC)
	

# place & route NextPNR
$(BUILD)/$(PROJ).asc: $(BUILD)/$(PROJ).json $(PCF)
	nextpnr-ice40 --lp1k --package cm36 --json $< --pcf $(PCF) --asc $@
	

# generowanie bitstreamu Icepack
$(BUILD)/$(PROJ).bin: $(BUILD)/$(PROJ).asc
	icepack $< $@

# wgranie do pamieci Flash
prog: $(BUILD)/$(PROJ).bin
	@echo "wgrywanie na ice"
	#cp $< $(MOUNT)/
	#sync
	icesprog $<
	@echo "koniec wgrywania"

# wgranie bezposrednie do pamieci ulotnej SRAM (ochrona ukladu podczas ewolucji)
#prog_sram: $(BUILD)/$(PROJ).bin
#	icesprog -s $<
# -s ?
clean:
	rm -rf $(BUILD)

.PHONY: all prog prog_sram clean

#generowanie schematow przez yosys:
#yosys -p 'prep; show -format svg -prefix logic_view wrapper; synth_ice40 -top wrapper -json build/watchdog.json; show -format pdf -prefix physical_view wrapper' hardware/cgp_core.v hardware/wrapper.v

#gui nextpnr:
#nextpnr-ice40 --gui --lp1k --package cm36 --json build/watchdog.json --pcf constraints/top.pcf
