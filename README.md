# APB memory RTL with a UVM testbench

A synthesizable APB4 slave memory verified with the Accellera UVM library and
Verilator 5.050. The repository includes the RTL, reusable UVM components,
three seeded regressions, independently checked VCD waveforms, and Linux CI.

## DUT behavior

- 32-bit APB data and 12-bit byte address.
- 256 words (1 KiB), initialized to zero by active-low synchronous reset.
- APB4 `PSTRB` byte-write support.
- One programmable wait cycle (`WAIT_CYCLES=1` in the testbench).
- `PSLVERR=1` for unaligned addresses or addresses outside `0x000–0x3ff`.
- Invalid writes do not modify memory; invalid reads return zero.

A transfer follows APB's setup phase (`PSEL=1`, `PENABLE=0`) and access phase
(`PSEL=1`, `PENABLE=1`). The request remains stable until `PREADY=1`.

## UVM verification

The testbench contains a sequence item, sequence, sequencer, driver, monitor,
scoreboard, environment, and test. The scoreboard maintains an independent
256-word reference memory and predicts byte-strobe writes, reads, reset, and
error responses.

Each seed performs one reset and 312 transfers:

- full-word write/read;
- partial byte-strobe write/read;
- final valid address `0x3fc`;
- unaligned and out-of-range write/read errors;
- 300 seeded mixed reads and writes;
- final reads of directed locations.

The scoreboard also requires reads, writes, partial writes, four errors, and a
wait state on every transfer. A 200 us watchdog detects deadlock.

## Build and run

Prerequisites: Verilator 5.050, C++20 compiler, GNU Make, Python 3, and Git.

```sh
git clone --recurse-submodules https://github.com/sponnuru/apb-memory-uvm.git
cd apb-memory-uvm
make test             # seeds 1, 42, and 2026
make run SEED=123     # one seed
```

Use `VERILATOR=/absolute/path/to/verilator` if it is not on `PATH`.

## Waveforms

Every run writes `build/apb_seed_<seed>.vcd`. Saved regression traces are in
`results/`. Open one using:

```sh
gtkwave results/apb_seed_1.vcd
```

Inspect `pclk`, `preset_n`, `psel`, `penable`, `pwrite`, `paddr`, `pwdata`,
`pstrb`, `prdata`, `pready`, and `pslverr` under `TOP.tb_top.dut`.

The VCD validator checks protocol properties independently of UVM: `PENABLE`
requires `PSEL`, every access has a setup, address/control/data remain stable
through wait states, all 312 transfers complete, and exactly four complete with
`PSLVERR`.

```sh
python3 scripts/check_vcd.py results/apb_seed_*.vcd
```

UVM implementation state is intentionally excluded from VCD files. Use the run
logs for phase completion and scoreboard reports.

## Main files

- `rtl/apb_memory.sv` — synthesizable APB memory slave.
- `tb/apb_pkg.sv` — complete UVM verification environment.
- `tb/apb_if.sv`, `tb/tb_top.sv` — interface and integration.
- `tb/sim_main.cpp`, `tb/trace.vlt` — Verilator runner and focused VCD tracing.
- `scripts/run_test.py` — UVM result gate and regression runner.
- `scripts/check_vcd.py` — independent waveform/protocol checker.

The UVM submodule retains its upstream Apache-2.0 license and notices.
