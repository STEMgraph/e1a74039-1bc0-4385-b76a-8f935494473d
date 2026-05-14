TOPLEVEL  = blinky
PCF       = constraints/icestick.pcf
DEVICE    = hx1k
PACKAGE   = tq144

SRC = src/blinky.vhd

# ---------- Simulation ----------
SIM_TOP = tb_blinky
SIM_SRC = src/blinky.vhd \
          sim/tb_blinky.vhd

sim: $(SIM_TOP).ghw
	gtkwave $(SIM_TOP).ghw sim/tb_blinky.gtkw &

$(SIM_TOP).ghw: $(SIM_SRC)
	ghdl -a --std=08 $(SIM_SRC)
	ghdl -e --std=08 $(SIM_TOP)
	ghdl -r --std=08 $(SIM_TOP) --wave=$(SIM_TOP).ghw

# ---------- Synthesis & Flash ----------
synth: $(TOPLEVEL).bin

$(TOPLEVEL).v: $(SRC)
	ghdl synth --std=08 --out=verilog $(SRC) -e $(TOPLEVEL) > $@

$(TOPLEVEL).json: $(TOPLEVEL).v
	yosys -p "synth_ice40 -top $(TOPLEVEL) -json $@" $<

$(TOPLEVEL).asc: $(TOPLEVEL).json $(PCF)
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --json $< --pcf $(PCF) --asc $@

$(TOPLEVEL).bin: $(TOPLEVEL).asc
	icepack $< $@

flash: $(TOPLEVEL).bin
	iceprog $<

clean:
	rm -f *.o *.cf *.ghw work-obj08.cf $(TOPLEVEL).v $(TOPLEVEL).json $(TOPLEVEL).asc $(TOPLEVEL).bin tb_blinky tb_clock_divider

.PHONY: sim synth flash clean
