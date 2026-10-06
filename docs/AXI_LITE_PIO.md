# AXI-Lite PIO deployment

This transport removes AXI DMA and reserved physical DDR from board bring-up.
The arithmetic core, matrix memories, bootstrap format and operation lengths
are unchanged. Linux ordinary application memory is still used for KAT arrays;
there is no DMA mapping or physical DDR buffer.

## Register contract

The original control registers at 0x000 through 0x040 are retained. PIO ID is
0x46524F32 and capability bits 0..4 are set. The old DMA ID is 0x46524F31; the
PIO driver rejects it before writing any register.

| Offset | Access | Meaning |
| --- | --- | --- |
| 0x100 | W | Low 32 bits of one input word |
| 0x104 | W | High 32 bits; commits the assembled 64-bit word |
| 0x108 | R | Captures the output FIFO head and returns low 32 bits |
| 0x10C | R | Returns captured high 32 bits and pops the FIFO exactly once |
| 0x110 | R | bit 0 TX-low ready, bit 1 TX-high ready, bit 2 RX-low ready, bit 3 RX-high ready, bit 4 RX word TLAST |
| 0x114 | W | TLAST for the next input word, 0 or 1; write before TX-low |

FIFO writes require all four WSTRB bits. Out-of-order, duplicate, empty and
unaligned accesses return AXI SLVERR. Read data is captured before response
backpressure. TX data and TLAST hold until the wrapper accepts the word.
Only one CPU process may own the interface. The application's advisory lock
cannot prevent other software that ignores that lock from accessing hardware.

Bootstrap is 12 words. Input lengths are 0, 1202 and 3705 words for KeyGen,
Encaps and Decaps. Output lengths are 2486, 1221 and 2 words. TLAST must be set
on the final bootstrap word and final non-empty payload word independently.
The application interleaves sending input and reading output; blocking on an
entire input packet before reading output can deadlock a small-FIFO interface.

## Build software on the board

The new artifacts are `board/frodokem_pio_kv260.bit` and
`board/frodokem_pio_kv260.xsa`. Do not load the old DMA bitstream.
See `PIO_VALIDATION.md` for functional and physical evidence. Before loading,
confirm exclusive use of the shared board and collect the runtime PL clock:

```sh
uname -m
cat /sys/class/fpga_manager/fpga0/state
sudo cat /sys/kernel/debug/clk/clk_summary | grep -E 'pl0|pl_clk|fclk'
```

If clock debugfs is absent, report that rather than guessing the clock.
The routed platform uses 52.631054 MHz. Loading .bit does not apply the PS
clock/reset settings from the XSA; those must match the live Linux platform.
Do not execute generated psu_init code on a live Linux board.

```sh
cd sw
gcc -std=c11 -O2 -Wall -Wextra frodokem_pio.c frodokem_pio_driver.c -o frodokem_pio
./frodokem_pio --probe
```

Probe reads sysfs only. After the new PIO bitstream is loaded and the board
owner verifies the accelerator UIO mapping and PS clock/reset configuration:

```sh
./frodokem_pio --run
```

Only one accelerator UIO map0 at 0xA0000000 is required. The map must cover at
least 0x118 bytes with offset 0. Existing MY_IP may be usable if its actual
mapping is appropriate, but its name does not identify the currently loaded
core. No dma-controller or ddr_high node is used. No /dev/mem fallback exists.

This is deterministic KAT validation, not a production entropy-backed API.
Success requires three BOARD_PIO_KAT_PASS lines and KV260_PIO_ALL_KAT_PASS.
Stop after any timeout/error. No automatic replay or board reprogramming.

## Validation and build

Run `bash scripts/test_pio.sh` with Cadence/Xcelium. It tests skewed AW/W,
response stalls, invalid FIFO accesses, slow output reads, a native stub and
all three real-core KAT operations. Run `make -C sw test` for host drivers.
Vivado is used only for synthesis/P&R/bitstream via `board/build_pio.tcl`.
The Verilog-only BD bridge is required by the Vivado 2022.2 module-reference
flow; all new transport logic and testbench are SystemVerilog.

PIO wall latency includes CPU/MMIO traffic and core backpressure. Previous
native-core power/energy results do not quantify PIO system-level energy or
board rail energy. Old DMA XSA is not a PIO artifact; keep names distinct.
