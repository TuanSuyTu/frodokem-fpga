# PetaLinux deployment prerequisites

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
