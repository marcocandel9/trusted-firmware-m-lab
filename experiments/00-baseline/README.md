# TF-M AN521 regression baseline

## Goal

Build and run the TF-M regression tests on the emulated MPS2-AN521 board, then save a baseline attestation token for the later experiments. Its only test patch prints the token; it does not change the attestation inputs or claim values.

## Sources and platform

- TF-M release: `TF-Mv2.3.1`, checked in the local firmware repository with:

  ```bash
  git -C /work/trusted-firmware-m describe --tags --always --dirty
  ```

  Observed output: `TF-Mv2.3.1`.
- Tests: `/work/tf-m-tests`. Check its checkout with `git -C /work/tf-m-tests describe --tags --always --dirty` when reproducing the run.
- Platform: `arm/mps2/an521`, emulated in QEMU.

The `tf-m-tests` build first compiles TF-M with the Secure regression tests and exports the Non-Secure API as `api_ns`. It then builds the Non-Secure test application against that API. The baseline does not patch the `trusted-firmware-m` source tree.

## Patch and build

The only baseline patch, `patches/enable_dump_token.patch`, defines `DUMP_TOKEN` in `tf-m-tests/tests_reg/test/secure_fw/suites/attestation/attest_token_test.c`. This enables the test code to print the token it receives. It does not change the nonce or any attestation claim.

From `/work/experiments/00-baseline`:

```bash
./build.sh
```

The build outputs are kept outside the source repositories:

| Path | Content |
| --- | --- |
| `/work/build/00_baseline/build_spe/` | Secure build, including TF-M, BL2, Secure tests, and exported `api_ns` |
| `/work/build/00_baseline/build_test/` | Non-Secure regression-test build |

The second build needs `build_spe/api_ns`, which is produced by the Secure build's `install` target. The build script applies the dump patch before compiling and removes it from the test source tree afterward.

## Run and result

From the same experiment directory:

```bash
./run_qemu.sh 2>&1 | tee baseline.log
```

`run_qemu.sh` starts the QEMU board. The test firmware prints Secure and Non-Secure regression-suite output over the emulated UART. With `DUMP_TOKEN` enabled, the attestation test also prints the token bytes. `tee` saves the combined terminal output to `baseline.log` while showing it on screen.

The captured token is the reference used in the later experiments. In this setup it uses TF-M's dummy provisioning data and test key, so its identity and signature are suitable for testing, not for identifying a production device. Builds made later in different directories or at different times may produce different software-component hashes; see [01-control-rebuild](../01-control-rebuild/README.md).
