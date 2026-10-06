# AXI-Lite PIO validation

Date: 2026-10-06. Target: xck26-sfvc784-2LV-c, KV260 SOM preset 1.4,
Vivado 2022.2. Generated PL clock: 52,631,054 Hz; timing period: 19.000 ns.

## Functional evidence

- Cadence Xcelium 25.03-s001: stub and real-core PIO KATs passed KeyGen,
  Encaps and Decaps, checking every output word: 2486, 1221 and 2 respectively.
- Original DMA-shell three-operation KATs also passed after the optional PIO
  additions, and exported C vectors remained bit-exact.
- AW/W skew, AXI response backpressure, invalid partial writes, missing low
  words, empty reads, duplicate reads and slow output reads are exercised.
- AXI R/B and queued TX stability assertions passed. Initial unknown TLAST
  status bug was fixed by qualifying TLAST with RX valid.
- C tests pass -Wall -Wextra -Werror, plus ASan/UBSan for the PIO driver test.
  They check three operations, byte order, TLAST, duplex service, timeout,
  wrong DMA-ID and active-core rejection. These are mocked host tests.
- Exact simulation sources were compared across local and VM copies. Native
  core, matrix and helper RTL were not modified. Remaining inherited width
  warnings are present; this is not a lint-clean claim.

Raw functional log: PIO_CADENCE.txt. Final PIO top additionally passed
compile/elaboration after constant-net declaration compatibility repair;
raw log: PIO_TOP_ELAB.txt. No XSim was used.

## Routed physical evidence

| Metric | AXI-Lite PIO SoC |
| --- | ---: |
| Total LUTs | 42,280 |
| FFs | 33,717 |
| RAMB36 | 78 |
| RAMB18 | 1 |
| BRAM36 equivalents | 78.5 |
| DSP48E2 | 128 |
| Setup WNS | +6.107 ns |
| Hold WHS | +0.010 ns |
| TNS / THS | 0 / 0 |
| Routing errors | 0 |
| Unconstrained internal endpoints | 0 |
| DRC Error / Critical Warning | 0 / 0 |
| DRC warnings | 385 |

Raw reports are in pio_physical. Warnings comprise DSP input-pipeline
recommendations, DSP MREG recommendations and unloaded nets; they are not
hidden or interpreted as power signoff. No new power/energy claim is made
for CPU-driven PIO. Previous native-energy figures are separate measurements.

Completed build: job-muwmeqir-0fd39173. Source hashes passed before and after
implementation. AXI DMA is absent from the new platform. Control remains at
0xA0000000 and needs only a matching accelerator UIO map, not reserved DDR.

## Artifacts and remaining board gate

- board/frodokem_pio_kv260.bit, 7,797,810 bytes.
- board/frodokem_pio_kv260.xsa, same embedded bitstream plus hardware metadata.
- Bitstream SHA256:
  e23663a40f202d292cf3f6f2b5aba46313efd3ef11fde6d25e9c98c884fec7c3
- The old board/frodokem_kv260.xsa is the DMA reference, not the PIO platform.

No board was programmed and no silicon PASS is claimed. Before loading on
the shared teacher board, confirm exclusive use, actual PS PL clock/reset and
UIO map. A .bit load does not apply psu_init.c or change Linux device tree/PS
clock configuration. Do not run the generated PS initialization blindly on
a live Linux system. Real acceptance requires all three BOARD_PIO_KAT_PASS
and KV260_PIO_ALL_KAT_PASS from the actual KV260.
