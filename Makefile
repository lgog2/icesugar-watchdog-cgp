# argumenty dla symulatora awari <LUT_ID(0-29)> <FAULT_PORT(0-3, 4-wyjscie)> <FAULT_TYPE(0,1)>
ARGS ?=

PROJ = watchdog
BUILD = build
MOUNT = /media/lg/iCELink

SRC = hardware/cgp_core.v hardware/wrapper.v
SRC_SEED = hardware/seed.v hardware/wrapper.v
SRC_MUTANT = hardware/mutant.v hardware/wrapper.v
SRC_SIM = software/main.cpp
HDR_SIM = software/cgp_core.hpp software/cgp_types.hpp
PCF = constraints/top.pcf

all: raw

# bez wydluzania sygnalow
raw: $(BUILD)/$(PROJ)_raw.bin

# z wydluzaniem sygnalow
stretch: $(BUILD)/$(PROJ)_stretch.bin

# seed wygenerowany automatycznie
seed: $(BUILD)/$(PROJ)_seed.bin

# mutant wygenerowany przez ewolucje CGP
mutant: $(BUILD)/$(PROJ)_mutant.bin

# prezentacja dryftu neutralnego
demo_drift:
	rm -f .intermediary hardware/seed.v hardware/mutant.v
	$(MAKE) hardware/mutant.v ARGS=""

# prezentacja naprawy awarii
demo_repair:
	rm -f .intermediary hardware/seed.v hardware/mutant.v
	$(MAKE) hardware/mutant.v ARGS="0 4 0" #<LUT_ID(0-29)> <FAULT_PORT(0-3, 4-wyjscie)> <FAULT_TYPE(0,1)>

#generowanie grafow
schemas: hardware/seed.v hardware/mutant.v
	rm -f seed_graph.svg mutant_graph.svg seed_graph.dot mutant_graph.dot
	@echo "\nGenerowanie reprezentacji graficznej (SVG)"
	yosys -p 'read_verilog hardware/seed.v; synth_ice40; opt; show -format svg -prefix seed_graph'
	yosys -p 'read_verilog hardware/mutant.v; synth_ice40; opt; show -format svg -prefix mutant_graph'
#sprawdzanie rownowaznosci logicznej
compare: hardware/seed.v hardware/mutant.v
	@echo "\nFormalna Weryfikacja Rownowaznosci mutanta i prototypu (SAT Solver)"
	yosys -p 'read_verilog hardware/cgp_core.v; prep -top cgp_core -flatten; design -stash gold; read_verilog hardware/mutant.v; read_verilog +/ice40/cells_sim.v; prep -top cgp_core -flatten; design -stash gate; design -copy-from gold -as gold cgp_core; design -copy-from gate -as gate cgp_core; equiv_make gold gate equiv; prep -top equiv -flatten; equiv_simple'

# kompilacja symulatora C++
software/sim: $(SRC_SIM) $(HDR_SIM)
	g++ -std=c++17 -O3 -Wall -Wextra $(SRC_SIM) -o $@

# generowanie netlist i kodu Verilog
hardware/seed.v hardware/mutant.v: .intermediary

.intermediary : software/sim
	#./software/sim 0 4 0 #<LUT_ID(0-29)> <FAULT_PORT(0-3, 4-wyjscie)> <FAULT_TYPE(0,1)>
	./software/sim $(ARGS)
	@touch .intermediary #stworzenia pliku ukrytego do sprawdzania daty (@ - w tle)

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

$(BUILD)/$(PROJ)_mutant.json: $(SRC_MUTANT)
	@mkdir -p $(BUILD)
	yosys -p 'read_verilog -D STRETCH_OUT $(SRC_MUTANT); synth_ice40 -top wrapper -json $@'

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

prog_mutant: $(BUILD)/$(PROJ)_mutant.bin
	@echo "Wgrywanie na iCE - uklad bedacy wynikiem ewolucji CGP (Mutant)"
	icesprog $<
	@echo "Koniec wgrywania."

clean:
	rm -rf $(BUILD)
	rm -f software/sim hardware/seed.v hardware/mutant.v .intermediary
	rm -f seed_graph.svg mutant_graph.svg seed_graph.dot mutant_graph.dot
.PHONY: all compare raw stretch seed mutant prog_raw prog_stretch prog_seed prog_mutant demo_drift demo_repair clean

#generowanie schematow przez yosys:
#yosys -p 'prep; show -format svg -prefix logic_view wrapper; synth_ice40 -top wrapper -json build/watchdog.json; show -format pdf -prefix physical_view wrapper' hardware/cgp_core.v hardware/wrapper.v

#gui nextpnr:
#nextpnr-ice40 --gui --lp1k --package cm36 --json build/watchdog.json --pcf constraints/top.pcf

#generowanie schematu grafu z plku Verilog (p.v) - p zastapic nazwa np seed, mutant, cgp_core:
#yosys -p 'read_verilog hardware/p.v; synth_ice40; opt; show -format svg -prefix p_graph'

#porownanie dwoch plkow verilog (p1.v , p2.v) - czy niezaleznie od topologi realzuja ta sama funkcje
#yosys -p 'read_verilog hardware/seed.v; prep -top cgp_core; design -stash seed; read_verilog hardware/mutant.v; prep -top cgp_core; design -stash mutant; equiv_make seed mutant equiv; hierarchy -top equiv; equiv_simple'
