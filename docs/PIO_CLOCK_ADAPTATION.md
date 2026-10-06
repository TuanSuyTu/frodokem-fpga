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
