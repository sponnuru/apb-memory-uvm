# Validation results — 2026-08-31

Local platform: macOS arm64 with Apple Clang 21.0.0, Verilator 5.050
(commit `848d926ebd4addacacd294dc84e35d9d4ae8078c`), and UVM 2020.3.1
(commit `656f20d087370a7c742e00188d20bbf30fa95339`).

Command: `make test VERILATOR=<local-verilator>/bin/verilator JOBS=8`.

| Seed | Transfers | Valid reads | Valid writes | Partial writes | Error responses | Waited transfers | UVM errors | UVM fatals |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 312 | 154 | 154 | 137 | 4 | 312 | 0 | 0 |
| 42 | 312 | 157 | 151 | 141 | 4 | 312 | 0 | 0 |
| 2026 | 312 | 144 | 164 | 154 | 4 | 312 | 0 | 0 |

All simulations finished normally at 12,520 ns. The four errors in each row are
intentional `PSLVERR` responses to two unaligned and two out-of-range transfers;
they are not UVM failures.

Each saved VCD independently passed `scripts/check_vcd.py`. The checker found
1,252 rising edges, 312 setup phases, 312 completed accesses, at least one wait
cycle on every transfer, stable request signals throughout access phases, and
exactly four error responses per seed.

As a negative validation, a truncated copy of the seed-1 VCD was rejected by the
checker for having an incomplete transfer count. The temporary corrupted file is
not included.

Known non-failing warnings are an upstream missing-timescale warning, an upstream
C++ `sprintf` deprecation warning, two UVM warnings caused by intentionally using
`UVM_NO_DPI`, and a macOS stack-size request warning. These tests exercise the
specified APB memory behavior; they do not prove every parameter combination or
all APB system-level behavior.

The adjacent logs are actual output with local paths normalized to `<project>`
and `<verilator>`. GitHub Actions separately repeats the regression on Linux.
