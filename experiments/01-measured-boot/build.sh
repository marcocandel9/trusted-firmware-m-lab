#!/usr/bin/env bash

set -euo pipefail

TFM_SOURCE="/work/trusted-firmware-m"
TFM_TESTS="/work/tf-m-tests"

MEASURED_BOOT_BUILD="/work/build/01_measured_boot"
SPE_BUILD="${MEASURED_BOOT_BUILD}/build_spe"
TEST_BUILD="${MEASURED_BOOT_BUILD}/build_test"

#Applied patch during build. For more info, check /work/experiments/01-measured-boot/README.md
DUMP_TOKEN_PATCH="/work/experiments/01-measured-boot/patches/enable_dump_token.patch"
NS_STRING_PATCH="/work/experiments/01-measured-boot/patches/ns_string_change.patch"
dump_token_applied=false
ns_string_applied=false

cleanup() {
    exit_status=$?

    if [[ "${ns_string_applied}" == true ]]; then
	    echo "Removing NS_STRING_PATCH..."
	if ! git -C "${TFM_TESTS}" apply -R "${NS_STRING_PATCH}"; then
		echo "WARNING: unable to remove NS_STRING_PATCH" >&2
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

echo "Checking DUMP_TOKEN patch..."

git -C "${TFM_TESTS}" apply \
    --check \
    "${DUMP_TOKEN_PATCH}"

echo "Applying DUMP_TOKEN patch..."

git -C "${TFM_TESTS}" apply \
    "${DUMP_TOKEN_PATCH}"

dump_token_applied=true

echo "Checking NS_STRING patch..."

git -C "${TFM_TESTS}" apply \
	--check \
	"${NS_STRING_PATCH}"

echo "Applying NS_STRING patch..."

git -C "${TFM_TESTS}" apply \
	"${NS_STRING_PATCH}"

ns_string_applied=true

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
