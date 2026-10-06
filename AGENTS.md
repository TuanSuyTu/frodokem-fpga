# Project execution rules

- Use Cadence/Xcelium for simulation. The user prohibits XSim.
- Never automatically fall back to XSim on a simulator failure.
- Preserve upstream baseline and use SystemVerilog for new RTL/testbenches.
- README files must be in English. Commit locally; never push without approval.
- Host tests are not board validation. Confirm reserved DDR, cache coherency
  and exclusive AXI DMA ownership before hardware transfers.
