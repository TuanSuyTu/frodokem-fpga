# Project execution rules

- Use Cadence/Xcelium for simulation. The user prohibits XSim.
- Never automatically fall back to XSim on a simulator failure.
- Preserve upstream baseline and use SystemVerilog for new RTL/testbenches.
- README files must be in English. Commit locally; never push without approval.
- Host tests are not board validation. PIO uses accelerator UIO only and must
  reject the old DMA bitstream ID. Never substitute /dev/mem or reserved DDR.
- Deployment uses AXI-Lite PIO only. Obsolete DMA transport is archived outside
  this repository. Engineering scripts, evidence and tests live in _agent/.
- Never label host mock results as FPGA random-test results. Job cycles include
  PIO stalls; MMIO service timers overlap job execution and affect performance.
