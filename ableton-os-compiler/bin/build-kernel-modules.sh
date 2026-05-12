#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="${SRC_DIR:-/src}"
OUT_DIR="${OUT_DIR:-/out}"
BUILD_DIR="${BUILD_DIR:-/tmp/module}"
KDIR="${KDIR:-/kernel}"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" "${OUT_DIR}"
cp -a "${SRC_DIR}/." "${BUILD_DIR}/"

make -C "${BUILD_DIR}" KDIR="${KDIR}"

find "${BUILD_DIR}" -maxdepth 1 -type f -name "*.ko" \
    -exec cp {} "${OUT_DIR}/" \;
find "${BUILD_DIR}" -maxdepth 1 -type f -name "Module.symvers" \
    -exec cp {} "${OUT_DIR}/" \;
find "${BUILD_DIR}" -maxdepth 1 -type f -name "modules.order" \
    -exec cp {} "${OUT_DIR}/" \;

find "${OUT_DIR}" -maxdepth 1 -type f -name "*.ko" -exec modinfo {} \;
