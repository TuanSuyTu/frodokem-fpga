# Matched native-core energy audit

## Verdict

MEASURED CORRELATION: The candidate reduces estimated full-operation native-core dynamic energy by approximately 53.24% for KeyGen, 37.93% for Encaps and 37.65% for Decaps against the matched LightSec baseline. All three exceed the 25% research target in this measurement. These are tool estimates, not silicon measurements or final hardware signoff.

## Evidence and arithmetic

Both designs use K26 xck26-sfvc784-2LV-c, approximately 55 MHz, the same testbench/vector files and operation capture boundaries, Cadence routed functional-netlist activity, and Vivado 2022.2 report_power. AXI is excluded. Reset/setup is excluded from the operation window.

| Operation | Baseline cycles | Candidate cycles | Baseline dynamic W | Candidate dynamic W | Baseline dynamic energy uJ | Candidate dynamic energy uJ | Saving |
|---|---:|---:|---:|---:|---:|---:|---:|
| KeyGen | 132125 | 42393 | 0.188 | 0.274 | 451.63 | 211.20 | 53.24% |
| Encaps | 135170 | 46608 | 0.165 | 0.297 | 405.51 | 251.69 | 37.93% |
| Decaps | 136539 | 47979 | 0.164 | 0.291 | 407.14 | 253.86 | 37.65% |

Energy uses E[uJ] = P[W] * duration[ps] / 1e6. Baseline durations: 2402296750, 2457660940, 2482552098 ps. Candidate durations: 770789526, 847426656, 872354178 ps. Power summaries are rounded to 0.001 W; energy and percentage digits must not imply higher measurement precision.

Estimated total on-chip energy reductions are approximately 62.06%, 55.42%, and 54.85%, respectively. They include device static power over the shorter execution interval, not board idle/active power or energy at a specified fixed transaction duty cycle.

FACT: Both designs pass the selected valid KAT: 2486 KeyGen words, 1221 Encaps words and 2 Decaps words. Baseline runner checks all input hashes after each operation. Baseline Encaps is 135170 cycles in this exact harness, not the previously quoted 135169; this audit uses the measured duration rather than the older count.

FACT: Baseline report_power matches 28075/28075 nets. Candidate matches 99041/99058, approximately 99.983%. Both report High confidence; no Power 33-334 frequency mismatch is present. Default thermal settings match: ambient 25 C, airflow 250 LFM, medium heat sink and board. The SAIF clock annotation warning is handled by design clock constraints.

MEASURED CORRELATION: Candidate instantaneous dynamic power is higher in every operation, but the operation durations are sufficiently shorter to reduce dynamic energy. This establishes the energy tradeoff; it does not independently prove the contribution of each architectural change.

## Raw evidence

- Baseline simulation: /mnt/windows-data/sharedfoderVM/baseline-native55-mce-20261006/workflow.log
- Baseline power: /mnt/windows-data/sharedfoderVM/baseline-native55-mce-20261006/power/{KeyGen,Encaps,Decaps}/power_saif.rpt
- Candidate simulation: /mnt/windows-data/sharedfoderVM/native-ring-mce-scoped-20261006/workflow.log
- Candidate power: /mnt/windows-data/sharedfoderVM/native-ring-mce-scoped-20261006/power/{KeyGen,Encaps,Decaps}/power_saif.rpt
- Baseline checkpoint: /mnt/windows-data/sharedfoderVM/native-ring-mce-scoped-20261006/baseline55/baseline55.dcp
- Candidate checkpoint: family_ae/full50/runs/ring-55mhz.MiJdYW/post_route.dcp

## How this conclusion could be wrong / remaining signoff

- Functional netlist simulation has no SDF; high matched coverage does not guarantee accurate glitch power or silicon energy.
- One valid KAT per operation and two invalid-ciphertext differential checks are not exhaustive random regression or an independent software fallback validation.
- The comparison uses one routed implementation per design, not an implementation-variation uncertainty bound.
- Matched checkpoint audit confirms internal setup/hold closure for both designs. External OOC input hold failures remain; neither entire timing summary should be labeled fully closed.
- These results cover the native full-operation boundary, not AXI, PS, board rails or a new ISO compliance validation.

## Matched timing classification completed

FACT: Read-only audit of the exact checkpoints, without changing constraints, reports baseline internal setup +2.340 ns and internal hold +0.011 ns; candidate internal setup +0.590 ns and internal hold +0.010 ns. All reported negative hold endpoints are input-port-to-pin: 40 baseline and 6 candidate. There are no negative register-to-register hold paths in this audit.

Evidence: family_ae/full50/runs/matched-native-timing.ecUrjB/{baseline,candidate}/classification.txt, negative_hold.tsv, internal_hold.rpt and internal_setup.rpt. The checkpoint hashes are unchanged. This establishes internal timing closure under the existing constraints, not board-interface closure. External input arrival/reset assumptions still require closure in the final wrapper/board implementation; do not waive these paths blindly.

Next authorized work: correctness regression and packaging without rerunning the completed energy simulations unnecessarily. Preserve the measured candidate and baseline artifacts.

## Consecutive Decaps regression

FACT: Two consecutive valid-vector Decaps transactions pass bit-exact comparison of both 64-bit shared-secret words per transaction without an intermediate reset. Both operations take 47,979 cycles. The test reissues setupTest before each operation and reuses vector 0; this is not a mixed-operation, different-payload or invalid-ciphertext regression.

Evidence: family_ae/full50/runs/ring-full-kats.V92cNJ/Decaps/testDecaps.sv and its simulation logs. The generated testbench asserts reset only at startup, retains mismatch fatal checks, and reports REPEATED_DECAPS_PASS. Source hash verification passes and tracked baseline src remains unchanged. This RTL regression uses 62.5 MHz, not the 55 MHz energy measurement, and adds no new energy result.

## Invalid-ciphertext differential regression

FACT: Baseline and candidate produce identical 128-bit outputs for vector 0, a one-bit mutation in c1, and a one-bit mutation in c2. Both mutated outputs differ from the valid shared secret. Each design runs all three transactions without an intermediate reset, reissuing setupTest before each operation. Baseline takes 136,539 cycles for each case; candidate takes 47,979 cycles for each case. This demonstrates cycle equality for these cases, not general constant-time or side-channel security.

Evidence: family_ae/full50/runs/invalid-decaps.ETJc2d/result.json and baseline/candidate functional.log. Compilation and elaboration precede the simulations, all source hash checks pass, and tracked baseline src remains unchanged. Total batch wall time is approximately 38 minutes. No RTL or energy artifacts were changed.

Per-case STATUS PASS in the logs means the transaction completed; invalid-case correctness is established by the differential analyzer and the independent fallback hash check below, not that marker alone.

## Independent fallback hash check

FACT: check_invalid_fallback.cjs independently computes SHAKE128(c1 || c2 || salt || s, 16 bytes) through Node/OpenSSL 3.5.5. Both recorded invalid outputs from both designs match the expected digest. The c1 mutation digest is 02b0ba4a7f30b44ad24a48428fd6289c; the c2 mutation digest is d0037f5f4e4055cd85b132302d5063b1. The valid KAT confirms conversion between canonical bytes and the two little-endian 64-bit bus words. Vector file SHA256: 84f0df03684be6931626493db1af7118e4ba5128b252f5fd3aa34dfaff494a01.

Reference for the fallback formula: https://github.com/microsoft/PQCrypto-LWEKE/blob/master/FrodoKEM/src/kem.c, decapsulation final ct_select/shake; FrodoKEM/src/frodo640.c defines shake as shake128 and 32-byte salt. The script implements only this hash oracle, not the upstream full decapsulation implementation. This is not a complete rejection test suite, a constant-time proof or ISO compliance signoff. No additional simulation or energy measurement was needed.

## Current ring core through AXI

FACT: Cadence Xcelium 25.03-s001 RTL simulation passes full AXI KAT for KeyGen 2,486 words, Encaps 1,221 words and Decaps 2 words. The testbench checks output contents, packet lengths, input/output/bootstrap counters and DONE/IRQ behavior with deterministic randomized stalls. One payload and one stall seed per operation are covered.

Evidence: /mnt/windows-data/sharedfoderVM/ring-axi-rtl-fixed.hSawAF/workflow.log; VM /home/tuan/sim-ring-axi-rtl-fixed-hSawAF/op{0,1,2}.log and source_manifest.sha256. Source hashes verify after all simulations. Elaboration contains full50_ring4_permute and full25_keygen_memory_path from full50_ring_memory_path.sv. Compile uses an explicit nine-file ring list and a single effective core include directory with overlay ownership, not all architecture variants. Wall times: elaboration 6.40 seconds; KeyGen 14.85, Encaps 14.65, Decaps 14.59 seconds. No SAIF/waveform is dumped. This is a functional regression at 62.5 MHz, not new physical timing or energy signoff.

The old full25 SoC checklist/bitstream belongs to an earlier core and must not be presented as board validation or PPA of this measured ring candidate. Current ring SoC integration and board validation remain separate signoff items.

FACT: Read-only classification of the existing ring AXI OOC checkpoint reports internal setup +3.592 ns and hold +0.010 ns at 55 MHz. All 284 negative hold endpoints are port-to-pin; no negative register-to-register hold paths are reported. Evidence: family_ae/full50/runs/ring-axi-timing-audit.WRPsd0/classification.txt and negative_hold.tsv. Checkpoint hash remains unchanged. This does not close the external OOC interface or the full PS/DMA SoC.

## Ring KV260 full-SoC physical implementation

FACT: New project family_ae/full25/soc_axi/reports/kv260_20261006_114315/frodokem_kv260.xpr includes the explicit ring source list, AXI shell, DMA, SmartConnect and PS. Requested PL clock is 55 MHz; the PS reports actual 52,631,054 Hz. Interface metadata follows that actual value. RING_CLOCK_MANIFEST.txt supersedes the preparation-stage 62.5 MHz clock entry in PLATFORM_MANIFEST.txt.

Post-route full-SoC resources: 46,316 LUTs, 40,891 FFs, 80 RAMB36 and 3 RAMB18, equivalent to 81.5 BRAM36 tiles, 128 DSPs. Full timing summary: setup +5.439 ns, hold +0.010 ns, no failing setup/hold endpoints. Route report shows zero routing errors. DRC has 389 warnings: DPIP-2 256, DPOP-4 128, REQP-1934 2, REQP-1935 2, RTSTAT-10 1. No Error/Critical Warning appears in the report summary; this is not DRC-clean or board validation.

Evidence: project physical_reports/{timing,utilization,route_status,drc}.rpt; family_ae/full50/runs/ring-soc-physical.Pzr45l/physical.log and source_manifest.sha256. Source hashes pass. Implementation wall time approximately 18 minutes. Native energy results remain at 55 MHz and are not recomputed or claimed as SoC/board energy at 52.631 MHz. No board was programmed.

FACT: Bitstream and XSA export completed with timing and DRC gates. The XSA archive contains frodokem_kv260.bit, system.hwh and PS initialization files. Archive listing and recorded SHA256 verify. Artifact: family_ae/full25/soc_axi/reports/kv260_20261006_114315/board_artifacts/frodokem_kv260.xsa. Export evidence: family_ae/full50/runs/ring-soc-export.Vb4LCc/export.log and artifact.sha256. These are local build artifacts only, not a successful board boot or KAT.
