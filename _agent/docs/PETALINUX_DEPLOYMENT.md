# PetaLinux deployment prerequisites

This page describes the original DMA transport only. For the requested
AXI-Lite-only, no-reserved-DDR deployment, use `AXI_LITE_PIO.md` instead.

## Minimal GCC workflow

From `sw` on the KV260:

```sh
gcc -std=c11 -O2 -Wall -Wextra frodokem_petalinux.c FPGA_Driver.c frodokem_driver.c -o frodokem
./frodokem
```

The default action lists UIO map0 names, addresses and sizes from sysfs only.
It does not mmap MMIO, write registers, start DMA or load a bitstream. Send
this output and the DDR driver's mapping/reservation configuration for review.
After reservation, exclusive ownership and uncached/coherent mapping are
confirmed by the board owner, run:

```sh
./frodokem --run ACTUAL_DDR_UIO_NAME --confirmed-reserved-uncached-ddr
```

The application auto-discovers the two MMIO UIO nodes by their hardware base
addresses. It refuses ambiguity. The DDR node is explicit: a UIO name cannot
establish cache coherency. Do not acknowledge the flag based only on a name.
No root privilege is needed for sysfs probing; transfers require UIO access
permissions. A clean GCC build is not evidence of board compatibility.

The backend follows AMD PG021 direct-register programming and tracks pending
transfers separately from initial Halted status:
https://docs.amd.com/r/en-US/pg021_axi_dma/Direct-Register-Mode-Simple-DMA

This software follows LeNet's UIO userspace style, not its hardware protocol.
Do not load LeNet's `system.bin` or reuse its PS ZDMA addresses for this design.
The exported XSA supplies this accelerator's bitstream and hardware metadata.
Loading that bitstream and creating a matching device-tree overlay depend on
the teacher's FPGA manager setup and are intentionally not automated here.

Before any DMA run, collect read-only board evidence:

```sh
uname -a
cat /proc/iomem
for d in /sys/class/uio/uio*; do
  echo "$d"
  cat "$d/name"
  for m in "$d"/maps/map*; do
    cat "$m/name" "$m/addr" "$m/size" "$m/offset"
  done
done
```

Request the actual device-tree source or decompiled tree, reserved-memory
definition and DDR mapping driver's source. The existence of `ddr_high` alone
does not prove memory is reserved, uncached or safe for AXI DMA. DMA registers
must not be simultaneously owned by a Linux kernel AXI DMA driver and this
userspace backend. AXI DMA is simple mode, 64-bit addresses, no DRE, 16-bit
length, 64-bit streams. Accelerator map0 base must be `0xA0000000`, DMA map0
base `0xA0010000`. DDR base is discovered, never assumed to be LeNet's base.

Build on the board with `make -C sw test`, or supply an AArch64 cross-compiler
using `make -C sw CC=aarch64-linux-gnu-gcc`. Host tests use mocked hardware.
After the board owner confirms the reservation/cache/ownership contract:

```sh
cd sw
./frodokem_petalinux ACTUAL_ACCEL_NAME ACTUAL_AXI_DMA_NAME ACTUAL_DDR_NAME \
  --confirmed-reserved-uncached-ddr
```

Expected success: three `BOARD_KAT_PASS` lines and `KV260_ALL_KAT_PASS`.
The application is deterministic KAT validation, not an entropy-backed KEM API.
After timeout, stop and diagnose/quiesce DMA before any further DDR access.
No board PASS is claimed until real board logs are collected.
