#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
out="$(mktemp -d)"
source "${VIVADO_SETTINGS:-/tools/Xilinx/Vivado/2022.2/settings64.sh}"
sources=("$root"/rtl/matrix/*.sv "$root"/rtl/helpers/*.sv "$root"/rtl/axi/frodokem_word_fifo.sv "$root"/rtl/axi/frodokem_axil_regs.sv "$root"/rtl/axi/frodokem_axi_shell.sv "$root"/tb/frodokem_axi_checks.sv "$root"/tb/tb_axi_shell.sv)
cd "$out"
timeout 180s xvlog -sv -d REAL_CORE -d FULL50_DISABLE_OLD_TRACE -i "$root/rtl/core" -i "$root/vectors" "${sources[@]}" "$XILINX_VIVADO/data/verilog/src/glbl.v" --log compile.log
timeout 300s xelab tb_axi_shell glbl -L unisims_ver -debug typical -s packaged_kat --log elaborate.log
timeout 30s xsim packaged_kat -testplusarg EXPORT_ONLY -runall --log export.log
cmp frodokem_kat_vectors.h "$root/sw/frodokem_kat_vectors.h"
for op in 0 1 2; do
 timeout 2700s xsim packaged_kat -testplusarg "OP=$op" -runall --log "op${op}.log"
 grep -q "AXI_REAL_KAT_PASS op=$op" "$out/op${op}.log"
done
printf 'RTL_TEST_OUTPUT=%s\n' "$out"
