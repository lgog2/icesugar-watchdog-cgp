PROJ = blink
PIN_DEF = blink.pcf
DEVICE = lp1k
PACKAGE = cm36
MOUNT = /media/lg/iCELink

all: $(PROJ).bin

$(PROJ).json: $(PROJ).v
	yosys -p "synth_ice40 -top $(PROJ) -json $(PROJ).json" $(PROJ).v

$(PROJ).asc: $(PROJ).json $(PIN_DEF)
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --json $(PROJ).json --pcf $(PIN_DEF) --asc $(PROJ).asc

$(PROJ).bin: $(PROJ).asc
	icepack $(PROJ).asc $(PROJ).bin

prog: $(PROJ).bin
	@echo "wgrywanie na ice"
	cp $(PROJ).bin $(MOUNT)/
	sync
	@echo "koniec wgrywania"

clean:
	rm -f $(PROJ).json $(PROJ).asc $(PROJ).bin

.PHONY: all prog clean





