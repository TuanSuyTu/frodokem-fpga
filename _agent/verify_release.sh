#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
ref="${1:?Provide locked official reference checkout}"
evidence=/home/tuan/frodokem-deployment-evidence/20261007-random
cd "$root"
make -C sw clean
make -C sw test > "$evidence/host_release.log" 2>&1
grep -q 'HOST_RANDOM_RUNNER_PASS' "$evidence/host_release.log"
./sw/frodokem_pio --check vectors/random_1000.bin
sha256sum -c _agent/DEPLOYMENT.sha256
sha256sum -c _agent/docs/PIO_SOURCES.sha256
bash -n _agent/scripts/*.sh _agent/generate_random.sh _agent/verify_release.sh
git diff --check
# No retained RTL changes or firmware changes from the already board-tested image.
while IFS= read -r source; do
    git show "6ecf015:$source" | cmp - "$source"
done < <(rg --files rtl)
git show 6ecf015:board/frodokem_pio_ps100_pl50.bit.bin | cmp - board/frodokem_pio_ps100_pl50.bit.bin
gcc -std=c11 -O1 -g -Wall -Wextra -Werror -fsanitize=address,undefined \
    -fno-omit-frame-pointer -Isw _agent/tests/test_random_host.c \
    -o "$evidence/test_random_sanitized"
ASAN_OPTIONS=detect_leaks=1 timeout 120s "$evidence/test_random_sanitized" vectors/random_1000.bin \
    > "$evidence/host_sanitized.log" 2>&1
grep -q 'HOST_RANDOM_RUNNER_PASS' "$evidence/host_sanitized.log"
bash _agent/generate_random.sh "$ref" > "$evidence/golden_reproduced.log" 2>&1
output="$(sed -n 's/^GOLDEN_OUTPUT=//p' "$evidence/golden_reproduced.log")"
[[ "$output" == "$root"/random-build.* ]]
cmp "$output/random_1000.bin" vectors/random_1000.bin
printf 'RELEASE_VERIFIED host_driver format packing 3000_mock_ops fail_fast sanitizers golden_reproducibility unchanged_RTL unchanged_firmware\n'
