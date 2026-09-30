#!/usr/bin/env bash

set -euo pipefail

TOKEN_CHANGE_BUILD="/work/build/02_token_claim_change"

BL2_IMAGE="${TOKEN_CHANGE_BUILD}/build_spe/bin/bl2.axf"
SIGNED_IMAGE="${TOKEN_CHANGE_BUILD}/build_test/tfm_s_ns_signed.bin"

if [[ ! -f "${BL2_IMAGE}" ]]; then
    echo "Error: BL2 image not found: ${BL2_IMAGE}" >&2
    echo "Run ./build.sh first." >&2
    exit 1
fi

if [[ ! -f "${SIGNED_IMAGE}" ]]; then
    echo "Error: signed TF-M image not found: ${SIGNED_IMAGE}" >&2
    echo "Run ./build.sh first." >&2
    exit 1
fi

#
# -M : Device name
# -m : memory size
# -nographic : terminal cli output
# -device: elf of the secure bootloader, bin of the s and ns 
exec qemu-system-arm \
    -M mps2-an521 \
    -m 16M \
    -nographic \
    -device loader,file="${BL2_IMAGE}" \
    -device loader,file="${SIGNED_IMAGE}",addr=0x10080000
