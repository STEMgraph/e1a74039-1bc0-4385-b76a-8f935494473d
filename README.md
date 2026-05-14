# FPGA Blinky — VHDL Clock Divider on iCEstick

This project implements a clock divider in VHDL, embeds it in a simulatable testbench, and blinks LED D5 on a Lattice iCEstick at 1 Hz (500 ms on, 500 ms off) using a 12 MHz input clock.

---

## Prerequisites

### Hardware

| Component | Details |
|---|---|
| **Lattice iCEstick HX1K** | Evaluation board with iCE40HX1K-TQ144, onboard 12 MHz oscillator, 5 green LEDs (D1–D5), USB-A connector |
| **USB-A port** | Directly on the PC or via an active hub; provides power and the SPI programming interface |

> Other iCE40 boards (iCEBreaker, ULX3S, etc.) work in principle but require adjusted pin numbers in the `.pcf` file and possibly a different `--package` option in nextpnr.

### Software

All tools are open-source and packaged in most Linux distributions.

| Tool | Purpose | Install (Debian/Ubuntu) |
|---|---|---|
| **GHDL** | VHDL analysis, simulation, synthesis to Verilog | `apt install ghdl` |
| **GTKWave** | Waveform viewer for `.ghw` files | `apt install gtkwave` |
| **Yosys** | RTL synthesis (Verilog → iCE40 netlist) | `apt install yosys` |
| **nextpnr-ice40** | Place & Route for iCE40 | `apt install nextpnr-ice40` |
| **icepack** | Converts `.asc` → binary bitfile `.bin` | part of `apt install icestorm` |
| **iceprog** | Flashes the bitfile to the iCEstick via USB | part of `apt install icestorm` |
| **make** | Drives the full build flow | `apt install make` |

#### USB permissions (Linux)

`iceprog` needs write access to the USB device. Without root, add a udev rule:

```bash
echo 'ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6010", MODE="0660", GROUP="plugdev"' \
  | sudo tee /etc/udev/rules.d/53-lattice-icestick.rules
sudo udevadm control --reload-rules
sudo usermod -aG plugdev $USER
# Then log out and back in, or: newgrp plugdev
```

---

## Project structure

```
fpga/
├── Makefile
├── README.md
├── constraints/
│   └── icestick.pcf          # Pin constraints: CLK → pin 21, LED D5 → pin 99
├── sim/
│   ├── tb_blinky.vhd         # VHDL testbench
│   └── tb_blinky.gtkw        # GTKWave save file (pre-configured signal layout)
└── src/
    └── blinky.vhd            # Top-level: 12 MHz input → 1 Hz LED blink
```

---

## Design description

### `src/blinky.vhd`

```
clk ──┐
      │  counter 0 .. DIVISOR/2 - 1
      │  → toggles led_reg on overflow
      │
led ◄─┘
```

A single synchronous counter counts from 0 to `DIVISOR/2 − 1`. On overflow it toggles `led_reg`, which drives the LED directly as a normal data signal — not a clock net. The `DIVISOR` generic defaults to 6,000,000 for hardware and can be overridden to a small value in simulation so the run stays short.

**Calculation for 500 ms blink period at 12 MHz:**

```
f_clk  = 12,000,000 Hz
Toggle interval (half period) = 0.5 s
Cycles until toggle = 12,000,000 × 0.5 = 6,000,000
```

The counter toggles `led_reg` every 6,000,000 cycles:

- 6,000,000 cycles **on**  → 500 ms
- 6,000,000 cycles **off** → 500 ms
- **Full period: 1 Hz**

`DIVISOR` must be even for an exact 50 % duty cycle. 6,000,000 is even, so this holds for the hardware target.

### `constraints/icestick.pcf`

```
set_io clk  21   # Onboard 12 MHz oscillator
set_io led  99   # LED D5 (green, rightmost)
```

The Physical Constraints File tells nextpnr which logical ports map to which physical FPGA pins. Pin numbers are taken from the official iCEstick schematic published by Lattice.

---

## Build flow

### Simulation (`make sim`)

```
VHDL sources
    │
    ▼
ghdl -a   ← analyse both VHDL files (syntax check, elaboration into work library)
    │
    ▼
ghdl -e   ← elaborate top-level entity tb_blinky
    │
    ▼
ghdl -r   ← run simulation; writes waveform data to tb_blinky.ghw
    │
    ▼
gtkwave   ← opens .ghw with pre-configured .gtkw layout (clk, led)
```

The testbench instantiates `blinky` with `DIVISOR=10` and a ~12 MHz simulation clock (83,333 ps period). It runs 200 clock cycles — 20 complete LED periods — then stops with `std.env.stop`. This is the same VHDL code path that runs on hardware; only the generic value differs.

### Synthesis & flash (`make synth` / `make flash`)

```
src/blinky.vhd
    │
    ▼
ghdl synth --out=verilog -e blinky
    │   GHDL synthesises the VHDL internally and emits structural Verilog.
    │   Yosys has no built-in VHDL frontend; this step bridges that gap
    │   since the ghdl-yosys-plugin (LLVM backend) is not installed.
    ▼
blinky.v  ← structural Verilog (auto-generated, do not edit manually)
    │
    ▼
yosys -p "synth_ice40 -top blinky -json blinky.json"
    │   RTL synthesis: logic optimisation, technology mapping onto iCE40
    │   primitives (SB_LUT4, SB_DFF, SB_CARRY). Output: JSON netlist.
    ▼
blinky.json
    │
    ▼
nextpnr-ice40 --hx1k --package tq144 --json blinky.json --pcf icestick.pcf --asc blinky.asc
    │   Place & Route: assigns logic cells to physical LUT/FF resources,
    │   routes connections, and checks timing constraints.
    │   Result: max clock frequency 168 MHz → PASS at 12 MHz
    ▼
blinky.asc  ← ASCII bitstream (human-readable intermediate format from IceStorm)
    │
    ▼
icepack blinky.asc blinky.bin
    │   Converts the ASCII bitstream to the binary format expected by iCE40.
    ▼
blinky.bin
    │
    ▼  (make flash only)
iceprog blinky.bin
    └── Writes via USB/FTDI to the iCEstick's SPI flash.
        The FPGA loads the design autonomously on the next power-on.
```

---

## Timing result (nextpnr output)

```
Max frequency for clock 'clk$SB_IO_IN_$glb_clk': 168.75 MHz
Required: 12.00 MHz
→ PASS  (ample slack)
```

The blinky counter is combinatorially trivial. The design could run up to ~168 MHz; at 12 MHz there are no timing concerns.

---

## Quick start

```bash
# Enter the project directory
cd fpga/

# Run simulation (opens GTKWave automatically)
make sim

# Synthesise the bitfile
make synth

# Connect the iCEstick via USB, then flash
make flash

# Remove all generated files
make clean
```

---

## Known limitations

- **`DIVISOR` must be even.** An odd value produces a non-50 % duty cycle because the counter only reacts to one clock edge. For the hardware target (6,000,000) this is not an issue.
- **Tested on iCEstick HX1K only.** Other iCE40 variants require adjusting `--device`/`--package` in the Makefile and pin numbers in the `.pcf` file.
- **No true clock output.** The LED signal is driven from a data flip-flop, not a clock buffer. This is intentional: routing a toggling counter output through the Global Buffer network and onto an IO pin is not recommended practice. For a real derived clock signal, use the onboard PLL (`SB_PLL40_CORE`) via `icepll`.
