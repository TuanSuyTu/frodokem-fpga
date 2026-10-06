# Energy-efficient FrodoKEM FPGA accelerator

This repository packages the validated ring candidate, LightSec-derived core,
AXI wrapper, KAT testbench, KV260 hardware platform and Linux UIO driver.
It contains no obsolete architectural experiments. It is not a production
cryptographic implementation or a board-validation claim.

## Layout

- `rtl/core`: merged include-based LightSec core; preserve `.v` compatibility.
- `rtl/matrix`: nine SystemVerilog accelerator modules.
- `rtl/helpers`: three required helpers.
- `rtl/axi`: AXI-Lite, AXI-Stream and FIFO logic.
- `tb`, `vectors`: full-operation AXI KAT test and deterministic vectors.
- `sw`: platform-independent job driver, Linux UIO backend and host tests.
- `board`: exported XSA containing the routed KV260 bitstream.
- `docs`: measured native energy results and deployment prerequisites.

## Linux/PetaLinux, without Vitis

`sw/FPGA_Driver.c` follows the existing LeNet application's UIO/sysfs/mmap
approach. It does NOT reuse LeNet's PS ZDMA register map: this hardware uses
PL AXI DMA at `0xA0010000`, with accelerator control at `0xA0000000`.
Register offsets in the new driver are BYTES, not LeNet's word indices.
UIO devices are found by their sysfs names, not assumed device numbers.

Before enabling transfers, the board owner must confirm the device tree,
exclusive DMA ownership, reserved DDR range and uncached/coherent mapping.
LeNet's comment describes its DDR mapping as cached; copying that mapping
without a cache-maintenance mechanism is unsafe. `O_SYNC` and CPU fences do
not establish DMA coherency. `fpga_open` requires explicit acknowledgment
of these prerequisites. No guessed DDR address or automatic FPGA programming
is provided. Do not use `/dev/mem` over ordinary Linux RAM.

Hardware board clock is 52.631054 MHz. Native energy comparisons were measured
at approximately 55 MHz and must not be presented as board measurements.
After a timeout, quiesce DMA before unmapping/reusing buffers; never replay a
cryptographic job automatically.

## Host checks

Run `make -C sw test`. These checks do not establish board or DMA correctness.
Run `bash scripts/test_rtl.sh` with Cadence/Xcelium in a writable VM-local copy.
Set `XCELIUM_BIN` and `CDS_LIC_FILE` if installation paths differ. The runner checks
that C driver vectors exactly match the testbench's exported vectors.
Icarus cannot compile the concurrent SVA/bind checker and its scanner fails
on this vector file; it is not a supported simulator for this packaged test.
XSim is prohibited by the project owner; no automatic fallback is allowed.
RTL source compilation must use include directories `rtl/core` and `vectors`,
define `REAL_CORE` and `FULL50_DISABLE_OLD_TRACE`, compile `.sv` modules and
`tb/tb_axi_shell.sv`; do NOT compile all core `.v` files separately because
`main.v` owns the include chain. Run the test with `+OP=0`, `+OP=1`, `+OP=2`.

## Provenance

LightSec baseline commit: `50c8fceae60ab4eb12399396fee7242b2ff72598`.
Packaged sources originate from the audited ring AXI KAT bundle and current
KV260 platform export. See `SOURCE_SHA256.txt` for frozen package hashes.
Retain upstream license notices. No remote push is authorized.
