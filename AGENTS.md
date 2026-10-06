# Project execution rules

- Use Cadence/Xcelium for simulation. The user prohibits XSim.
- Never automatically fall back to XSim on a simulator failure.
- Preserve upstream baseline and use SystemVerilog for new RTL/testbenches.
- README files must be in English. Commit locally; never push without approval.
- Host tests are not board validation. PIO uses accelerator UIO only and must
  reject the old DMA bitstream ID. Never substitute /dev/mem or reserved DDR.
- The retained DMA transport requires reserved DDR, cache coherency and
  exclusive AXI DMA ownership before hardware transfers.
