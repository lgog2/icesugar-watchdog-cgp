PROJ = watchdog
BUILD = build
MOUNT = /media/lg/iCELink

SRC = hardware/cgp_core.v hardware/wrapper.v
PCF = constraints/top.pcf

all:raw

raw: $(BUILD)/$(PROJ)_raw.bin
safe: $(BUILD)/$(PROJ)_safe.bin

# synteza Yosys
$(BUILD)/$(PROJ)_raw.json: $(SRC)
	mkdir -p $(BUILD)
	yosys -p 'read_verilog $(SRC); synth_ice40 -top wrapper -json $@'
	
$(BUILD)/$(PROJ)_safe.json: $(SRC)
	mkdir -p $(BUILD)
	yosys -p 'read_verilog -D SAFE_MODE $(SRC); synth_ice40 -top wrapper -json $@'

# place & route NextPNR
$(BUILD)/%.asc: $(BUILD)/%.json $(PCF)
	nextpnr-ice40 --lp1k --package cm36 --json $< --pcf $(PCF) --asc $@

# generowanie bitstreamu Icepack
$(BUILD)/%.bin: $(BUILD)/%.asc
	icepack $< $@

# wgranie do pamieci Flash
prog_raw: $(BUILD)/$(PROJ)_raw.bin
	@echo "wgrywanie na ice - wersja raw"
	#cp $< $(MOUNT)/
	#sync
	icesprog $<
	@echo "koniec wgrywania"
	
prog_safe: $(BUILD)/$(PROJ)_safe.bin
	@echo "wgrywanie na ice - wersja safe"
	#cp $< $(MOUNT)/
	#sync
	icesprog $<
	@echo "koniec wgrywania"


clean:
	rm -rf $(BUILD)

.PHONY: all raw safe prog_raw prog_safe clean

#generowanie schematow przez yosys:
#yosys -p 'prep; show -format svg -prefix logic_view wrapper; synth_ice40 -top wrapper -json build/watchdog.json; show -format pdf -prefix physical_view wrapper' hardware/cgp_core.v hardware/wrapper.v

#gui nextpnr:
#nextpnr-ice40 --gui --lp1k --package cm36 --json build/watchdog.json --pcf constraints/top.pcf
