# Teacher-board clock adaptation

Observed runtime: Linux 5.15.36-xilinx-v2022.2, PL0_REF clock ID 71,
99,999,999 Hz. A request for 50 MHz through fclk0/set_rate left the
readback unchanged. Firmware/driver root cause is not established.

Build with FK_PIO_CLOCK_PROFILE=ps100_pl50. The direct-clock build remains
the default. Never resume a direct-clock project with this new profile.

PS PL0 is configured for 100 MHz. Clocking Wizard produces 50 MHz.
Accelerator, SmartConnect, reset synchronizer and PS HPM0 FPD ACLK all
use the same 50 MHz clock. There is no added RTL clock-domain crossing.
Wizard locked drives reset/dcm_locked, holding fabric reset until locked.
The arithmetic, PIO transport and software are unchanged.

Acceptance before deployment:

- BD validation, source checksums and host driver tests pass.
- Verify generated clock topology and 100 MHz input / 50 MHz output.
- Routed setup and hold slack are nonnegative; no unconstrained internal paths.
- No DRC errors or critical warnings; bitstream and XSA export succeed.
- Audit raw reports and preserve the earlier bitstream separately.
- Previous Cadence KATs prove the unchanged core/transport, not the new physical
  clock/reset platform. Board acceptance still requires all three KATs.
- Do not claim new power/energy results from this deployment build.

Risks: live PS reset configuration, actual input clock and UIO ownership must
still match. Clock lock alone does not prove arithmetic or board correctness.
No Linux clock, device-tree or PS register mutation is performed by this build.

First build stopped during BD validation, before synthesis: BD 41-238 reported
100,000,000 Hz at the explicitly configured Wizard input versus 99,999,001 Hz
at the preset PS output. Host tests and source checks passed. The repair leaves
PRIM_IN_FREQ under BD propagation rather than a USER override, following the
installed clk_wiz_v6_0/bd/bd.tcl pre_propagate/propagate implementation. This
does not waive frequency checks. Setup/hold and output clock remain subject
to audit after the corrected build completes.

## Audited corrected build

Build run.n0dvRZ completed in approximately 21 minutes. Raw reports are in
pio_ps100_pl50_physical/. The preset PS rate is 99,999,001 Hz; the propagated
fabric rate is 50,023,973 Hz. MMCM uses DIVCLK_DIVIDE=9,
CLKFBOUT_MULT_F=127.750 and CLKOUT0_DIVIDE_F=28.375. The live teacher-board
input of 99,999,999 Hz produces approximately 50.024 MHz as well.

Routed setup WNS +6.526 ns, hold WHS +0.010 ns. No unconstrained internal
endpoints, missing clocks or routing errors. Resources: 42,280 LUTs,
33,716 FFs, 78 RAMB36, one RAMB18, 128 DSPs. DRC has 385 warnings:
256 DPIP-2, 128 DPOP-4 and one RTSTAT-10; zero errors/critical warnings.
Warnings remain visible and are not suppressed. These results are not a
board PASS or a new energy measurement.

Artifacts use distinct ps100_pl50 names. The original direct-clock package
is retained. The extracted .bit matches the .bit embedded in the new XSA.
Bootgen 2022.2 generated .bit.bin using the committed .bif for Linux FPGA
Manager. Do not run psu_init on live Linux. No new clock sysfs write is needed.

## Board acceptance

Confirm exclusive PL ownership, stop any previous hardware application, and
confirm PL0 still reads approximately 100 MHz before loading this variant.
Loading replaces the current PL design; it does not update boot firmware.
On the teacher board, from the repository root:

```sh
sudo cp board/frodokem_pio_ps100_pl50.bit.bin /lib/firmware/
printf '0\n' | sudo tee /sys/class/fpga_manager/fpga0/flags
printf 'frodokem_pio_ps100_pl50.bit.bin\n' | sudo tee /sys/class/fpga_manager/fpga0/firmware
cat /sys/class/fpga_manager/fpga0/state
```

Stop if any write fails or state is not operating. Read dmesg rather than
retrying blindly. After a successful load:

```sh
cd sw
sudo timeout 40s ./frodokem_pio --run
```

Acceptance is three BOARD_PIO_KAT_PASS lines and KV260_PIO_ALL_KAT_PASS.
Stop on timeout or mismatch. A timeout may not interrupt a stalled kernel
MMIO access; it is not a guarantee against a bus hang. Clock/reset, UIO map
and physical PS configuration are still runtime integration risks.
