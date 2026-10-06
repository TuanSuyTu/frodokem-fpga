#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
export PATH="${XCELIUM_BIN:-/home/tuan/tools/cadence/XCELIUM2503/tools/bin}:$PATH"
export CDS_LIC_FILE="${CDS_LIC_FILE:-/home/tuan/tools/cadence/license/cadence.dat}"
export LM_LICENSE_FILE="$CDS_LIC_FILE"
out="$(mktemp -d "$root/cadence-pio.XXXXXX")"
sources=("$root"/rtl/matrix/*.sv "$root"/rtl/helpers/*.sv "$root"/rtl/axi/frodokem_word_fifo.sv "$root"/rtl/axi/frodokem_axil_regs.sv "$root"/rtl/axi/frodokem_axi_shell.sv "$root"/_agent/tb/tb_pio.sv)
cd "$out"
for mode in stub real; do
 defs=()
 if [[ "$mode" == real ]]; then defs=(-define REAL_CORE -define FULL50_DISABLE_OLD_TRACE); fi
 timeout 900s xrun -64bit -sv "${defs[@]}" +incdir+"$root/rtl/core"+"$root/vectors" "${sources[@]}" -top tb_pio -snapshot "pio_$mode" -elaborate -l "$mode.elaborate.log"
 ! grep -Eq '\*E,|\*F,' "$mode.elaborate.log"
 timeout 1200s xrun -64bit -R -snapshot "pio_$mode" -l "$mode.log"
 grep -q PIO_ALL_TESTS_PASS "$mode.log"
 for op in 0 1 2; do grep -q "PIO_KAT_PASS op=$op" "$mode.log"; done
 ! grep -Eq '\*E,|\*F,|Fatal:|ERROR:' "$mode.log"
done
printf 'PIO_CADENCE_PASS output=%s\n' "$out"
