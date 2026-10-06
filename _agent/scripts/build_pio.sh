#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
export FK_PIO_CLOCK_PROFILE="${FK_PIO_CLOCK_PROFILE:-ps100_pl50}"
if (( $#>1 )); then echo 'Usage: build_pio.sh [EXISTING_PIO_PROJECT_XPR]' >&2; exit 2; fi
if (( $#==1 )); then
 export FK_PIO_RESUME_PROJECT="$(realpath "$1")"
 [[ "$FK_PIO_RESUME_PROJECT" == "$root"/build-pio/*/project/frodokem_pio.xpr ]]
 test -s "$FK_PIO_RESUME_PROJECT"
else
 unset FK_PIO_RESUME_PROJECT
fi
# Evidence must describe precisely the source used for this physical build.
grep -q PIO_CADENCE_PASS "$root/_agent/docs/PIO_CADENCE.txt"
grep -q PACKAGED_CADENCE_ALL_KATS_PASS "$root/_agent/docs/PIO_CADENCE.txt"
if grep -Eq '\*E,|\*F,|Fatal:|ERROR:' "$root/_agent/docs/PIO_CADENCE.txt"; then exit 62; fi
cd "$root"
sha256sum -c _agent/docs/PIO_SOURCES.sha256
make -C sw test
source /tools/Xilinx/Vivado/2022.2/settings64.sh
mkdir -p "$root/build-pio"
out="$(mktemp -d "$root/build-pio/run.XXXXXX")"
cd "$out"
timeout 14400s vivado -mode batch -source "$root/_agent/scripts/build_pio.tcl" \
  -log physical.log -journal physical.jou -tclargs "$out/project"
grep -q PIO_BOARD_ARTIFACTS_READY physical.log
if grep -q '^ERROR:' physical.log; then exit 63; fi
artifact_dir="$out/project"
if [[ -n "${FK_PIO_RESUME_PROJECT:-}" ]]; then artifact_dir="$(dirname "$FK_PIO_RESUME_PROJECT")"; fi
unzip -j "$artifact_dir/frodokem_pio_kv260.xsa" '*.bit' -d "$out"
cd "$root"
sha256sum -c _agent/docs/PIO_SOURCES.sha256
printf 'PIO_BUILD_PASS output=%s\n' "$out"
