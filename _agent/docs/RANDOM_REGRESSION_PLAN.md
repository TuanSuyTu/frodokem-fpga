# 1,000 random-case board regression and deployment cleanup

## Scope and acceptance

Use the official Microsoft PQCrypto-LWEKE software reference, freeze its exact
commit and license, and establish compatibility with the packaged LightSec
FrodoKEM-640-SHAKE vectors before generating any golden data. Salt and enlarged
seedSE in existing vectors must be preserved. Do not infer spec compatibility
from an algorithm name. No changes to RTL or the validated bitstream.

1. Fetch and inspect reference source outside the deployment repository.
2. Run deterministic reference calls using exact randomness from existing
   vectors; compare every pk/sk/ct/ss byte after documented wire-format mapping.
   If current reference fails, find the matching revision before proceeding.
3. Generate 1,000 distinct reproducible random cases from a recorded public
   test seed. This is test-only entropy, never production key generation.
   Include KeyGen, Encaps, valid Decaps per case. Verify software round-trip.
4. Store compact binary golden records with version, sizes, count and integrity
   metadata. Prefer no duplicated pk/sk payloads. Board does not need reference
   libraries. Validate truncation, lengths and all records before MMIO writes.
5. Driver supports this dataset, compares every byte and feeds subsequent ops
   from verified hardware outputs. Print final 10 cases and per-op PASS/FAIL,
   planned/completed/not-run counts, elapsed/mean/min/max timing. Abort on first
   hardware/transport error rather than replaying a potentially stalled core.
6. Report RTL cycles as job elapsed cycles including PIO stalls, not pure compute.
   TX/RX CPU-service timing is optional instrumentation with overhead disclosed;
   overlap prevents additive core+TX+RX accounting. Frequency conversion must
   use an explicitly stated approximate board clock. No board energy claim.
7. Host-test binary parsing and transport/profile paths, including malformed
   data and deterministic byte mappings. Preserve single-KAT board invocation.
8. Simplify deployment repo after dependency review: retain active RTL, active
   100-to-50 MHz firmware, minimal board driver/tests and concise instructions.
   Move raw forensic reports to an agent/evidence folder or external archive.
   Remove obsolete DMA software/platform exports from this deployment repo,
   preserving a recoverable local archive and Git history. Retain licenses.
9. Update source hashes and compile commands; commit only, no push until approval.

## Remaining limitations

Host verification is not board random-regression PASS. Only the user's actual
KV260 run can supply that result. Existing KAT board screenshot passed one
known vector for all three operations; 1,000 new cases are not yet validated.
Constant-time schedule does not establish resistance to power side channels.
