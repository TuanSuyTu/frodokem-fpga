# Random regression release validation — 2026-10-07

## Verified evidence

- Strict GCC build: C11, O2, Wall, Wextra, Werror.
- Existing PIO host protocol test passed all three operations, word packing,
  TLAST, duplex servicing, incompatible image and busy-state rejection.
- Dataset parser passed valid, corrupted, truncated, trailing-byte, count-limit,
  reserved-field, reference-identifier and bootstrap-zero tests.
- Input adapters matched existing Encaps and Decaps KAT byte arrays exactly.
- Host runner completed 1,000 distinct cases and 3,000 mock operations.
- Deliberate mismatch at case 999 Encaps stopped before that case's Decaps and
  before case 1000. Failure counts and NOT_RUN counts were verified.
- AddressSanitizer and UndefinedBehaviorSanitizer host run completed successfully.
- Official reference first matched every existing KeyGen/Encaps/Decaps KAT byte.
- All 1,000 generated reference encapsulation/decapsulation round trips passed.
- Independent regeneration produced the identical 29,852,128-byte dataset:
  `0b540cb6f22c005caf24a71454f995d245540900ff057f528df4045a757bf8ae`.
- Retained RTL files and shipped firmware are byte-identical to commit `6ecf015`.
- Physical-input and deployment SHA-256 manifests passed. Shell syntax and Git
  whitespace checks passed.

Raw logs are `random_host.log`, `random_sanitized.log` and `random_golden.log`.
An intentional HOST_MOCK_REGRESSION_FAIL in host logs is the negative test,
not a board failure. Host mock runtimes are not FPGA measurements.

## Still pending

The 1,000-case test has NOT been run on the physical KV260 by this release audit.
The previous single-vector three-operation board KAT passed. No new FPGA
performance or energy result is claimed. The user must run the updated driver
and preserve its actual board log before reporting random hardware PASS.

## Cleanup

Obsolete DMA transport and superseded bitstream/XSA artifacts were removed from
the active tree. Engineering reports, scripts and tests were moved to `_agent/`.
The current firmware remains in `board/`. Removed material is recoverable through
Git history and the external pre-cleanup archive, not irreversibly erased.
