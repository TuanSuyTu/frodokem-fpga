#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
# Evidence must describe precisely the source used for this physical build.
grep -q PIO_CADENCE_PASS "$root/docs/PIO_CADENCE.txt"
grep -q PACKAGED_CADENCE_ALL_KATS_PASS "$root/docs/PIO_CADENCE.txt"
if grep -Eq '\*E,|\*F,|Fatal:|ERROR:' "$root/docs/PIO_CADENCE.txt"; then exit 62; fi
cd "$root"
sha256sum -c docs/PIO_SOURCES.sha256
make -C sw test
source /tools/Xilinx/Vivado/2022.2/settings64.sh
mkdir -p "$root/build-pio"
out="$(mktemp -d "$root/build-pio/run.XXXXXX")"
cd "$out"
timeout 14400s vivado -mode batch -source "$root/board/build_pio.tcl" \
  -log physical.log -journal physical.jou -tclargs "$out/project"
grep -q PIO_BOARD_ARTIFACTS_READY physical.log
if grep -q '^ERROR:' physical.log; then exit 63; fi
unzip -j "$out/project/frodokem_pio_kv260.xsa" '*.bit' -d "$out"
cd "$root"
sha256sum -c docs/PIO_SOURCES.sha256
printf 'PIO_BUILD_PASS output=%s\n' "$out"
