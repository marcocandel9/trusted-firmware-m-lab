# TF-M attestation experiments

These experiments build TF-M 2.3.1 and its regression tests for the QEMU MPS2-AN521 board. They follow an attestation token from the test's nonce, through firmware measurements and provisioned claims, to signature verification. This repo can be used as a baseline to study and test the Trusted-Firmware-M in a easy to manage virtualized environment. An Apple Silicon Mac Air M5 has been used as host during the environment building and the experiments. The instructions to run on a different machine have been included in [SETUP.md](SETUP.md). 

## Workspace

The project folder is mounted as `/work` in the container:

| Path under `/work` | Purpose |
| --- | --- |
| `Dockerfile` | Defines the build and QEMU environment. |
| `trusted-firmware-m/` | Secure firmware, attestation service, platform code, and provisioning. |
| `tf-m-tests/` | Secure and Non-Secure regression tests. |
| `experiments/` | One directory per experiment, with its README, scripts, patches, and logs. |
| `build/` | Build output for each experiment, kept outside the source trees. |
| `token_decoder.py`, `token.bin` | Token analysis script and a captured token sample. |
| `SETUP.md` | Full environment installation and initial QEMU instructions. |

Experiment build scripts temporarily apply their patches to the source repositories and use separate directories under `/work/build`. Read the experiment's README for its exact commands and evidence.

## Experiments

| Experiment | Goal and finding |
| --- | --- |
| [00-baseline](experiments/00-baseline/README.md) | Build the reference firmware with a token-dump patch, print the token, and keep the baseline run. |
| [01-measured-boot](experiments/01-measured-boot/README.md) | Change a Non-Secure source string and confirm the change is present in `tfm_ns.bin`. A token comparison with a separately built baseline cannot isolate its effect on the hash. |
| [01-control-rebuild](experiments/01-control-rebuild/README.md) | Rebuild the same sources and patches. Show how the Secure timestamp and Non-Secure build paths differ, along with other unresolved Non-Secure bytes. The software-component hashes differ without an intentional source edit. |
| [02-token-claim-change](experiments/02-token-claim-change/README.md) | Trace a changed test nonce into the token and study how changing the provisioned dummy Implementation ID affects its claim. |
| [03-token-sign-check](experiments/03-token-sign-check/README.md) | Verify the baseline COSE_Sign1 signature with the public key derived from the dummy IAK; reject a changed signature or key. No new firmware build is needed for this experiment. |

## Getting started

Follow [SETUP.md](SETUP.md) once to prepare Colima or Docker, the toolchain, Python dependencies, and QEMU. Then start with [00-baseline](experiments/00-baseline/README.md). Each experiment documents its own build, run, and comparison commands.

`SETUP.md` is the detailed environment guide. This README is the map of the repository, so the installation procedure is kept in one place.
