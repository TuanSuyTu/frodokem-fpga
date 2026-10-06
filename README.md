# FrodoKEM FPGA — KV260 PIO deployment

FrodoKEM-640-SHAKE hardware with AXI-Lite PIO. No DMA, reserved DDR, Vitis or
`/dev/mem` is needed. The board must expose the accelerator through UIO at
`0xA0000000`. The driver rejects an incompatible FPGA image before writing.

## Files you need

- `board/`: one ready-to-load firmware image, PS input 100 MHz → PL about 50.024 MHz.
- `sw/`: GCC application, PIO driver and test-data reader.
- `vectors/random_1000.bin`: 1,000 distinct pseudorandom cases with software golden outputs.
- `rtl/`: hardware sources and reused LightSec modules.
- `_agent/`: engineering evidence, build scripts, generator and host/RTL tests.

The existing image passed all three KAT operations on KV260. The new 1,000-case
suite is prepared and host-tested; its FPGA result remains pending your board run.
No RTL or firmware change was made for the random-test driver.

## Build and run on the board

Enter this repository on KV260. If the PIO firmware is already loaded, skip
the firmware-loading commands. Do not reprogram a shared board without ownership.

```sh
sudo cp board/frodokem_pio_ps100_pl50.bit.bin /lib/firmware/
printf '0\n' | sudo tee /sys/class/fpga_manager/fpga0/flags
printf 'frodokem_pio_ps100_pl50.bit.bin\n' | sudo tee /sys/class/fpga_manager/fpga0/firmware
cat /sys/class/fpga_manager/fpga0/state
```

The state should be `operating`. Compile with GCC, then validate the dataset
without accessing FPGA registers:

```sh
cd sw
gcc -std=c11 -O2 -Wall -Wextra frodokem_pio.c frodokem_pio_driver.c -o frodokem_pio
./frodokem_pio --check ../vectors/random_1000.bin
```

Run all 1,000 cases, each containing KeyGen → Encaps → Decaps, and save the report:

```sh
set -o pipefail
sudo timeout 600s ./frodokem_pio --random ../vectors/random_1000.bin | tee board_random_1000.log
```

The final screen includes the last 10 attempted cases, PASS/FAIL/NOT_RUN counts,
per-operation mean/min/max wall time, mean job cycles and total elapsed time.
Successful completion ends with `KV260_RANDOM_REGRESSION_PASS`.
Every output byte is compared to software golden. The run stops at the first
mismatch or hardware error, with no automatic replay. Public test seeds and
keys are for testing only, never production.

Optional TX/RX CPU service profiling:

```sh
sudo timeout 600s ./frodokem_pio --random ../vectors/random_1000.bin --profile-io | tee board_random_profile.log
```

Profiling adds timer overhead. TX/RX service overlaps FPGA execution, so do not
add TX + RX + job time. Job cycles include PIO stalls, not pure arithmetic time.
`job_ms_est` assumes PL clock 50,024,473 Hz; override with `--clock-hz HZ` if
independently measured. This driver does not measure board power or energy.

Other commands: `--probe` reads UIO sysfs only; `--run` executes the original KAT.

## Reference and development

Golden outputs come from the [official Microsoft reference](https://github.com/microsoft/PQCrypto-LWEKE),
revision `e1edeb3af1fae0d5727683bd2f5465280ec2437a`, verified against all existing
LightSec KAT output bytes. Dataset size: 29,852,128 bytes, about 28.5 MiB.
The board does not need to compile or execute that reference.

Run `make -C sw test` for host tests. These are not board verification.
See [_agent/README.md](_agent/README.md) for reproducibility and build details.
