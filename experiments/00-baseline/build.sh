#!/usr/bin/env bash

set -euo pipefail

TFM_SOURCE="/work/trusted-firmware-m"
TFM_TESTS="/work/tf-m-tests"

BASELINE_BUILD="/work/build/00_baseline"
SPE_BUILD="${BASELINE_BUILD}/build_spe"
TEST_BUILD="${BASELINE_BUILD}/build_test"

#Applied patch during build. For more info, check /work/experiments/00-baseline/README.md
DUMP_TOKEN_PATCH="/work/experiments/00-baseline/patches/enable_dump_token.patch"

patch_applied=false

cleanup() {
    exit_status=$?

    if [[ "${patch_applied}" == true ]]; then
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

echo "Checking DUMP_TOKEN patch..."

git -C "${TFM_TESTS}" apply \
    --check \
    "${DUMP_TOKEN_PATCH}"

echo "Applying DUMP_TOKEN patch..."

git -C "${TFM_TESTS}" apply \
    "${DUMP_TOKEN_PATCH}"

patch_applied=true

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
