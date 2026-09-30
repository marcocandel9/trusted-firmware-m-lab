# Attestation token claim changes

This experiment uses one build to change two inputs to the attestation token: the challenge supplied by the regression test and the dummy Implementation ID provisioned by TF-M. The changes are kept in separate patches so their origins remain clear.

## Nonce supplied by the test

The Secure regression test defines a 64-byte challenge in `tf-m-tests/tests_reg/test/secure_fw/suites/attestation/attest_token_test_values.h` and passes it to `psa_initial_attest_get_token()`. TF-M handles the request in its Secure Initial Attestation service (`trusted-firmware-m/secure_fw/partitions/initial_attestation/attest_core.c`).

`nonce_change.patch` changes challenge bytes 4–7 (zero-based) from `00 00 00 00` to `DE AD BE EF`, leaving bytes 0–3 at zero. In the token already captured from this change, `58 40` introduces the 64-byte nonce, which starts `00 00 00 00 DE AD BE EF`. The regression test passes. Its pass result alone is not independent evidence, because the test uses the same fixture as input and as the expected value; the token dump shows the changed bytes directly.

## Implementation ID supplied by provisioning

In the dummy provisioning configuration (TFM_DUMMY_PROVISIONING CMAKE OPTION activated during build), `trusted-firmware-m/platform/ext/common/provisioning.c` defines `psa_rot_prov_data` with a sample Implementation ID: eight `AA` bytes, eight `BB`, eight `CC`, and eight `DD`. These are the bytes observed in the baseline token. The separate `implementation_id_change.patch` will change this sample value for this experiment.

`TFM_DUMMY_PROVISIONING` is a CMake option, not a lifecycle state. It selects sample data for provisioning. When the platform is not yet provisioned, TF-M writes `psa_rot_prov_data.implementation_id` to the OTP element identified by `PLAT_OTP_ID_IMPLEMENTATION_ID`. After provisioning is complete, the lifecycle advances to `TFM_SLC_SECURED`. Later, the platform attestation HAL in `trusted-firmware-m/platform/ext/common/template/attest_hal.c` reads that OTP element to build the token. The attestation service does not read the constant directly from `provisioning.c`.

`PLAT_OTP_ID_IMPLEMENTATION_ID` names a logical element, not a memory address. The platform's OTP implementation maps it to storage; the default TF-M implementation uses on-chip flash as OTP backing. Changing `provisioning.c` and rebuilding changes the token's Implementation ID **if the new value is provisioned**. If the OTP area already contains the old value and the lifecycle is already `TFM_SLC_SECURED`, rebuilding alone does not repeat provisioning. For this comparison, the QEMU run must start from an appropriate unprovisioned OTP state, or the new token must be checked to confirm which value was read. See the [TF-M v2.3.1 provisioning guide](https://trustedfirmware-m.readthedocs.io/en/tf-mv2.3.1/integration_guide/platform_provisioning.html).

The same dummy provisioning structure contains the test IAK. This experiment leaves it unchanged and does not test signature verification.

## Build and evidence

The build will apply `nonce_change.patch` to `tf-m-tests` and `implementation_id_change.patch` to `trusted-firmware-m`. It will also apply `enable_dump_token.patch` to `tf-m-tests` to print the token, and remove all applied patches when the build finishes. Once `build.sh` includes the Implementation ID patch, run from `/work/experiments/02-token-claim-change`:

```bash
./build.sh
./run_qemu.sh 2>&1 | tee token_claim_change.log
```

The nonce change is already confirmed by the token dump. The changed Implementation ID (Starting bytes changed in 0xDE 0xAD 0xBE 0xEF) are also visible in the token inside the qemu output log. Since the token is signed and the firmware is rebuilt, this experiment will not infer that every other token byte stays the same.

From `trusted-firmware-m/platform/ext/common/provisioning.c` is also possible to extract the DUMMY IAK provisioning KEY, which will be used for checking the validity of the ECDSA Asymmetric sign of the token.
DUMMY IAK:
```bash
static const struct tfm_psa_rot_provisioning_data_t psa_rot_prov_data = {
    PSA_ROT_PROV_DATA_MAGIC,
    /* IAK */
    {
        0xA9, 0xB4, 0x54, 0xB2, 0x6D, 0x6F, 0x90, 0xA4,
        0xEA, 0x31, 0x19, 0x35, 0x64, 0xCB, 0xA9, 0x1F,
        0xEC, 0x6F, 0x9A, 0x00, 0x2A, 0x7D, 0xC0, 0x50,
        0x4B, 0x92, 0xA1, 0x93, 0x71, 0x34, 0x58, 0x5F
    },
```

