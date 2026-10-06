#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
out="$(mktemp -d)"
sources=(rtl/matrix/*.sv rtl/helpers/*.sv rtl/axi/frodokem_word_fifo.sv rtl/axi/frodokem_axil_regs.sv rtl/axi/frodokem_axi_shell.sv tb/frodokem_axi_checks.sv tb/tb_axi_shell.sv)
iverilog -g2012 -DREAL_CORE -DFULL50_DISABLE_OLD_TRACE -Irtl/core -Ivectors -s tb_axi_shell -o "$out/kat" "${sources[@]}"
for op in 0 1 2; do
 timeout 600s vvp "$out/kat" "+OP=$op"
done
printf 'RTL_TEST_OUTPUT=%s\n' "$out"
