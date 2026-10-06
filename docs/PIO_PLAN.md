# AXI-Lite PIO implementation and acceptance

User request: remove DMA and physical DDR-buffer prerequisites from KV260
deployment, preserve the existing FrodoKEM core, and notify at board bring-up.

## Scope

- Add optional PIO FIFO registers to the existing shell; default DMA behavior
  remains unchanged. Keep the native core, matrix/helper RTL and vectors frozen.
- Add a PIO-only SystemVerilog top plus Vivado-required Verilog BD adapter.
- Add a standalone GCC/UIO application and a transport driver with no DMA or
  physical DDR mapping. CPU TX/RX service must be duplex, with bounded timeout.
- Build a separate KV260 PS + control interconnect + PIO accelerator platform.
  No AXI DMA, HP memory interconnect or new DDR reservation is needed.
- Do not program the shared teacher board automatically. Do not push without
  authorization. No XSim or production-entropy claim.

## Gates

1. Host C tests compile with -Wall -Wextra -Werror and pass all three operation
   flows, byte order, last-word checks, busy/old-bitstream rejection and timeout.
2. Cadence stub and real-core PIO KATs pass KeyGen, Encaps and Decaps, checking
   every output word. Stagger AW/W and response ready; inject invalid, empty,
   duplicate and unaligned FIFO accesses. Assert stable AXI responses and TX.
3. Re-run existing DMA-shell KATs to detect default-mode regression.
4. Freeze checked source hashes, preserve raw logs and verify them before and
   after synthesis/P&R. No baseline core source modification.
5. Full SoC synthesis/P&R completes, setup and hold slack are nonnegative,
   no DRC Error/Critical Warning, bitstream and XSA are exported separately.
6. Only then notify the user to transfer the new PIO artifacts and verify actual
   board clock/reset, UIO mapping and exclusive ownership before programming.
7. Hardware acceptance is three BOARD_PIO_KAT_PASS and KV260_PIO_ALL_KAT_PASS
   lines from the real KV260. Host/simulator PASS does not satisfy this gate.

## Current evidence

Host driver tests and ASan/UBSan pass. Initial stub Cadence run exposed an
uninitialized RX TLAST status when FIFO was empty. RTL now qualifies TLAST
with RX valid. Full regression completed with exit code 0 as the finite VM
service `frodokem-pio-kat-v2-20261006.service`. Raw log was independently read
and preserved in `PIO_CADENCE.txt`: both stub and real PIO KATs passed all three
operations; original DMA-shell KATs also passed all three operations. No
assertion failure or simulator Error/Fatal was present. Inherited baseline
port-width warnings remain and are not misrepresented as warning-free RTL.
Exact simulation-source hashes on VM match local sources. All native core,
matrix and helper files remain unchanged from the frozen package. Synthesis,
P&R and board validation are the remaining gates; no physical or board PASS
is claimed yet.

## First physical-build correction

The first build stopped in accelerator synthesis, before P&R, with Synth
8-1577 at frodokem_pio_top.sv lines 31-32. Mixed initialized/uninitialized net
declarations were replaced with plain declarations and explicit constant
assignments; no transport or arithmetic behavior changed. The exact PIO top
then passed Cadence compile/elaboration, recorded in PIO_TOP_ELAB.txt.
PIO_BUILD_FAILURE.txt preserves the original failure. The existing project
is reused; the failed accelerator and dependent top runs are reset, not the
entire platform recreated. Setup/hold and bitstream gates remain unchanged.
The generated platform clock is 52,631,054 Hz, not the requested 55 MHz.
