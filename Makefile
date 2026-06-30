PROJ = watchdog
BUILD = build
MOUNT = /media/lg/iCELink

SRC = hardware/cgp_core.v hardware/wrapper.v
SRC_SEED = hardware/seed.v hardware/wrapper.v
SRC_SIM = software/main.cpp software/cgp_core.hpp software/cgp_types.hpp
PCF = constraints/top.pcf

all: raw

# bez wydluzania sygnalow
raw: $(BUILD)/$(PROJ)_raw.bin

# z wydluzaniem sygnalow
stretch: $(BUILD)/$(PROJ)_stretch.bin

# seed wygenerowany automatycznie
seed: $(BUILD)/$(PROJ)_seed.bin

software/sim: $(SRC_SIM)
	g++ -O3 -Wall -Wextra $< -o $@

hardware/seed.v: software/sim
	software/sim

# synteza Yosys
$(BUILD)/$(PROJ)_raw.json: $(SRC)
	@mkdir -p $(BUILD)
	yosys -p 'read_verilog $(SRC); synth_ice40 -top wrapper -json $@'

$(BUILD)/$(PROJ)_stretch.json: $(SRC)
	@mkdir -p $(BUILD)
	yosys -p 'read_verilog -D STRETCH_OUT $(SRC); synth_ice40 -top wrapper -json $@'

$(BUILD)/$(PROJ)_seed.json: $(SRC_SEED)
	@mkdir -p $(BUILD)
	yosys -p 'read_verilog -D STRETCH_OUT $(SRC_SEED); synth_ice40 -top wrapper -json $@'

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
	
prog_stretch: $(BUILD)/$(PROJ)_stretch.bin
	@echo "wgrywanie na ice - wersja z wydluzonymi syganalami"
	#cp $< $(MOUNT)/
	#sync
	icesprog $<
	@echo "koniec wgrywania"

prog_seed: $(BUILD)/$(PROJ)_seed.bin
	@echo "wgrywanie na ice - seed wygenerowany automatycznie"
	#cp $< $(MOUNT)/
	#sync
	icesprog $<
	@echo "koniec wgrywania"

clean:
	rm -rf $(BUILD)
	rm -f software/sim hardware/seed.v

.PHONY: all raw stretch seed prog_raw prog_stretch prog_seed clean

#generowanie schematow przez yosys:
#yosys -p 'prep; show -format svg -prefix logic_view wrapper; synth_ice40 -top wrapper -json build/watchdog.json; show -format pdf -prefix physical_view wrapper' hardware/cgp_core.v hardware/wrapper.v

#gui nextpnr:
#nextpnr-ice40 --gui --lp1k --package cm36 --json build/watchdog.json --pcf constraints/top.pcf
