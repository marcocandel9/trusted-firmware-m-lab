# Non-Secure firmware change and attestation

## Goal

Change a string in the Non-Secure test firmware and check how the change appears in the built binary and attestation token.

## Build

`build.sh` applies two patches:

- `patches/ns_string_change.patch` changes the attestation test title in `tf-m-tests/tests_reg/test/secure_fw/suites/attestation/non_secure/attest_asymmetric_ns_interface_testsuite.c` by adding `[E1]`.
- `enable_dump_token.patch` prints the attestation token, as in the baseline experiment.

The build output is under `/work/build/01_measured_boot`.

## Run

From `/work/experiments/01-measured-boot`:

```bash
./build.sh
./run_qemu.sh 2>&1 | tee measured_boot.log
```

## Result and limitation

The changed string is present in the resulting Non-Secure binary:

```bash
arm-none-eabi-strings /work/build/01_measured_boot/build_test/bin/tfm_ns.bin | grep -F '[E1]'
```

For example, the output contains:

```text
Initial Attestation Service non-secure interface tests[E1](TFM_NS_ATTEST_TEST_1XXX)
```

This confirms that the patch reached `tfm_ns.bin`. Changing those bytes would also change the hash of that binary compared with an otherwise identical build without the patch.

However, the baseline and experiment are separate builds. The [control rebuild](../01-control-rebuild/README.md) shows that builds can produce different binaries and software-component hashes even without this patch. Therefore, comparing these two tokens does not isolate the effect of `[E1]` on the attestation claim. The experiment confirms the binary change, but it does not independently establish that the observed difference in the token's Non-Secure hash is caused only by that change.
