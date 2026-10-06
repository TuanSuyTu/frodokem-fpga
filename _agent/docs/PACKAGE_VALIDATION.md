# Package validation, 2026-10-06

Cadence/Xcelium 25.03-s001, Rocky Linux VM with 10 visible vCPUs.
The run used `scripts/test_rtl.sh`; MCE was not enabled. Providing 10 vCPUs
does not establish ten-way simulator parallelism.

- Compilation/elaboration: 6 seconds.
- Vector export: 1 second; exported C header equals the packaged driver header.
- KeyGen: 16 seconds, all 2486 output words pass.
- Encaps: 16 seconds, all 1221 output words pass.
- Decaps: 16 seconds, both output words pass.
- No simulator error/fatal or procedural failure was found in the run log.
- Concurrent protocol assertions were included; no assertion failure occurred.
- VM source checksums match the frozen package manifest. The XSA was not copied
  into the simulation VM; its host checksum was checked separately.
- Host driver tests pass, and Linux application compilation passes with
  `-Wall -Wextra -Werror`. No board execution has been performed.

Width-mismatch warnings remain in the inherited include-based core, including
constant/counter port sizing. This is not a warning-free lint signoff. The
recorded KAT scope does not prove correctness for all inputs or secure deployment.

Raw log: `CADENCE_KAT_20261006.txt`.
Next required evidence is the teacher's actual PetaLinux device tree, UIO maps,
reserved-memory configuration and cache-mapping semantics before DMA board tests.
