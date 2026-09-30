# COSE_Sign1 signature check

This experiment verifies the signature of a TF-M baseline attestation token. It uses an existing token; no firmware is rebuilt.

## Input and key

The baseline token is decoded with `/work/token_decoder.py`. From `/work`, save its output with:

```bash
python3 token_decoder.py > /work/experiments/03-token-sign-check/token_decoder_baseline_out.txt
```

The token's 64-byte COSE signature is:

```text
764e1a4a9722667ecf7d89dd12c0ea0a40e2a7fa0efd0508e33466c48a8ca06d3b683dfc3e78b5c505143d941579edd53a47c201f359f7bc564a3d8812e8edf7
```

For this test build, the dummy Initial Attestation Key (IAK) is defined in `/work/trusted-firmware-m/platform/ext/common/provisioning.c`:

```text
a9b454b26d6f90a4ea31193564cba91fec6f9a002a7dc0504b92a1937134585f
```

`dummy_signature_verify.py` derives the P-256 public key from this known dummy private key. The private key is used here only to obtain the corresponding public key for the experiment.

## Verification

Run from `/work/experiments/03-token-sign-check`:

```bash
python3 dummy_signature_verify.py
```

The script uses the fixed, 548-byte baseline token to extract its protected header (`A1 01 26`) and 472-byte payload. It deliberately keeps the baseline signature in `DUMMY_SIGNATURE_BYTES`, separate from the token bytes, so that the supplied signature can be changed independently. The baseline constant matches the 64-byte signature decoded above.

COSE signs the CBOR-encoded `Sig_structure` consisting of `"Signature1"`, the protected header bytes, an empty external AAD, and the payload bytes. The verifier converts `DUMMY_SIGNATURE_BYTES` from COSE's `r || s` format to DER and checks it with ECDSA P-256 and SHA-256. For each negative check, change one input in the script and run it again.

| Check | Result |
| --- | --- |
| Baseline signature with the public key derived from the dummy IAK | Valid |
| Same signature with a public key derived from a different IAK | Invalid |
| Changed `DUMMY_SIGNATURE_BYTES` with the original public key | Invalid |

These checks show that the supplied signature validates for these exact signed bytes and this public key. The script does not extracts the signature extracted from the embedded token as its verification input, the embedded hard-coded token is just used to extract the prodected header bytes, the empty external AAD and the payload bytes, which are the SIGNED DATA. Changing only that embedded signature will not affect this test. However, the hard-coded DUMMY_SIGNATURE_KEY is the extracted signature from the token. It was hard-coded in order to make it easy to modify and run the experiment. The verifier is specific to this token's CBOR layout and lengths; it is not yet a general COSE_Sign1 verifier. The dummy IAK is a test key and provides no production device identity.
