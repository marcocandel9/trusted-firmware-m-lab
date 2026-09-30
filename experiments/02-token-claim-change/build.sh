#!/usr/bin/env bash

set -euo pipefail

TFM_SOURCE="/work/trusted-firmware-m"
TFM_TESTS="/work/tf-m-tests"

CLAIM_CHANGE_BUILD="/work/build/02_token_claim_change"
SPE_BUILD="${CLAIM_CHANGE_BUILD}/build_spe"
TEST_BUILD="${CLAIM_CHANGE_BUILD}/build_test"

PATCH_DIR="/work/experiments/02-token-claim-change/patches"
DUMP_TOKEN_PATCH="${PATCH_DIR}/enable_dump_token.patch"
NONCE_PATCH="${PATCH_DIR}/nonce_change.patch"
IMPLEMENTATION_ID_PATCH="${PATCH_DIR}/implementation_id_change.patch"

dump_token_applied=false
nonce_applied=false
implementation_id_applied=false

cleanup() {
    exit_status=$?
    
    if [[ "${implementation_id_applied}" == true ]]; then
    	echo "Removing IMPLEMENTATION ID PATCH..."
	if ! git -C "${TFM_SOURCE}" apply -R "${IMPLEMENTATION_ID_PATCH}"; then
	    echo "WARNING: unable to remove IMPLEMENTATION ID PATCH" >&2
	fi
    fi

    if [[ "${nonce_applied}" == true ]]; then
        echo "Removing NONCE patch..."
        if ! git -C "${TFM_TESTS}" apply -R "${NONCE_PATCH}"; then
            echo "WARNING: unable to remove NONCE patch" >&2
        fi
    fi

    if [[ "${dump_token_applied}" == true ]]; then
        echo "Removing DUMP_TOKEN patch..."
        if ! git -C "${TFM_TESTS}" apply -R "${DUMP_TOKEN_PATCH}"; then
            echo "WARNING: unable to remove DUMP_TOKEN patch" >&2
        fi
    fi

    return "${exit_status}"
}

trap cleanup EXIT

if [[ -n "$(git -C "${TFM_TESTS}" status --short)" ]]; then
    echo "ERROR: tf-m-tests working tree is not clean" >&2
    git -C "${TFM_TESTS}" status --short >&2
    exit 1
fi

if [[ -n "$(git -C "${TFM_SOURCE}" status --short)" ]]; then
	echo "ERROR: trusted-firmware-m working tree is not clean" >&2
	git -C "${TFM_SOURCE}" status --short >&2
	exit 1
fi

echo "Checking IMPLEMENTATION_ID_CHANGE.patch..."
git -C "${TFM_SOURCE}" apply --check "${IMPLEMENTATION_ID_PATCH}"

echo "Applying IMPLMENTATION_ID patch..."
git -C "${TFM_SOURCE}" apply "${IMPLEMENTATION_ID_PATCH}"
implementation_id_applied=true

echo "Checking DUMP_TOKEN patch..."
git -C "${TFM_TESTS}" apply --check "${DUMP_TOKEN_PATCH}"

echo "Applying DUMP_TOKEN patch..."
git -C "${TFM_TESTS}" apply "${DUMP_TOKEN_PATCH}"
dump_token_applied=true

echo "Checking NONCE patch..."
git -C "${TFM_TESTS}" apply --check "${NONCE_PATCH}"

echo "Applying NONCE patch..."
git -C "${TFM_TESTS}" apply "${NONCE_PATCH}"
nonce_applied=true

cmake \
    -S "${TFM_TESTS}/tests_reg/spe" \
    -B "${SPE_BUILD}" \
    -DTFM_PLATFORM=arm/mps2/an521 \
    -DCONFIG_TFM_SOURCE_PATH="${TFM_SOURCE}" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DTFM_TOOLCHAIN_FILE="${TFM_SOURCE}/toolchain_GNUARM.cmake" \
    -DTEST_S=ON \
    -DTEST_NS=ON

cmake --build "${SPE_BUILD}" --target install

cmake \
    -S "${TFM_TESTS}/tests_reg" \
    -B "${TEST_BUILD}" \
    -DCONFIG_SPE_PATH="${SPE_BUILD}/api_ns" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DTFM_TOOLCHAIN_FILE="${SPE_BUILD}/api_ns/cmake/toolchain_ns_GNUARM.cmake"

cmake --build "${TEST_BUILD}"
