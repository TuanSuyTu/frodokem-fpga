#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
export PATH="${XCELIUM_BIN:-/home/tuan/tools/cadence/XCELIUM2503/tools/bin}:$PATH"
export CDS_LIC_FILE="${CDS_LIC_FILE:-/home/tuan/tools/cadence/license/cadence.dat}"
export LM_LICENSE_FILE="$CDS_LIC_FILE"
out="$(mktemp -d "$root/cadence-kat.XXXXXX")"
sources=("$root"/rtl/matrix/*.sv "$root"/rtl/helpers/*.sv "$root"/rtl/axi/frodokem_word_fifo.sv "$root"/rtl/axi/frodokem_axil_regs.sv "$root"/rtl/axi/frodokem_axi_shell.sv "$root"/_agent/tb/frodokem_axi_checks.sv "$root"/_agent/tb/tb_axi_shell.sv)
cd "$out"
timeout 900s xrun -64bit -sv -define REAL_CORE -define FULL50_DISABLE_OLD_TRACE +incdir+"$root/rtl/core"+"$root/vectors" "${sources[@]}" -top tb_axi_shell -snapshot packaged_kat -elaborate -l elaborate.log
! grep -Eq '\*E,|\*F,' elaborate.log
timeout 60s xrun -64bit -R -snapshot packaged_kat +EXPORT_ONLY -l export.log
grep -q AXI_VECTOR_EXPORT_PASS export.log
cmp frodokem_kat_vectors.h "$root/sw/frodokem_kat_vectors.h"
for op in 0 1 2; do
 timeout 2700s xrun -64bit -R -snapshot packaged_kat "+OP=$op" -l "op${op}.log"
 grep -q "AXI_REAL_KAT_PASS op=$op" "$out/op${op}.log"
 if grep -Eq '\*E,|\*F,|Fatal:|ERROR:' "op${op}.log"; then exit 62; fi
done
printf 'PACKAGED_CADENCE_ALL_KATS_PASS output=%s\n' "$out"
