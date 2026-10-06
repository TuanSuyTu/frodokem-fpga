# Engineering material

The public deployment interface is AXI-Lite PIO only. This directory holds
generator code, tests, build scripts and historical reports, not extra runtime
dependencies. Historical reports may mention former paths, DMA or older images;
they are evidence snapshots, not current deployment instructions.

## Golden reproducibility

```sh
git clone https://github.com/microsoft/PQCrypto-LWEKE official-reference
git -C official-reference checkout e1edeb3af1fae0d5727683bd2f5465280ec2437a
bash _agent/generate_random.sh "$PWD/official-reference"
```

Generation first verifies the official software against all existing KeyGen,
Encaps and Decaps KAT output bytes. Each case uses SHAKE128 with a fixed public
32-byte test seed, case index and domain tag to derive distinct entropy. The
reference verifies each valid encapsulation/decapsulation round trip.
Reference randomness calls are checked for exact expected lengths. The official
reference is external, not vendored; its source remains under its upstream license.

Dataset format is specified by `sw/frodokem_random.h`. Explicit byte packing
avoids host struct padding and endianness dependence. Header and record CRC32
detect accidental corruption, not hostile replacement. The complete dataset is
validated before FPGA mapping. SHA-256 is recorded in `DEPLOYMENT.sha256`.

## Validation

`make -C sw test` checks PIO protocol through a host mock, malformed datasets,
KAT-derived wire mapping, all 1,000 runner cases, distinct bootstraps and fail-fast
behavior. Runner tests deliberately inject a mismatch; a failure report inside
the test log is expected. Host mock timing is meaningless for FPGA performance.
Use only the real board report for screenshots and performance results.

`bash _agent/scripts/test_pio.sh` and `test_rtl.sh` use Cadence/Xcelium, not XSim.
`bash _agent/scripts/build_pio.sh` builds the clock-adapted image with Vivado.
Long tool runs must be launched through the configured process-job lifecycle.
Moving tests/scripts does not change retained RTL or the shipped firmware.
`docs/PIO_SOURCES.sha256` verifies current physical-build inputs; the old manifest
is retained as `docs/PIO_SOURCES.historical.sha256`.

Removed DMA sources and superseded bitstreams are recoverable from Git history.
The local pre-cleanup archive is outside the repository at
`/home/tuan/frodokem-deployment-evidence/20261007-random/deployment-before-cleanup/`.

## Timing semantics

Wall time covers driver execution, polling, transfer and FPGA processing.
Hardware job cycles cover START→DONE and include output/input backpressure.
MMIO profiling measures CPU service intervals only; it adds observer overhead.
Pure arithmetic time and transfer-only latency cannot be isolated from these
counters. No energy claims may be inferred from this board regression alone.
