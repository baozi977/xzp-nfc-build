#!/usr/bin/env bash
set -euxo pipefail

DEFCONFIG="${1:-lineage_yoshino_defconfig}"

ROOT="$(pwd)"
OUTROOT="${ROOT}/out"

rm -rf "${OUTROOT}"
mkdir -p "${OUTROOT}"

export ARCH=arm64
export SUBARCH=arm64

cd kernel

echo "Using defconfig: ${DEFCONFIG}"
make O=out "${DEFCONFIG}"
make -j"$(nproc)" O=out Image.gz dtbs

cp -f out/arch/arm64/boot/Image.gz "${OUTROOT}/Image.gz"

mkdir -p "${OUTROOT}/dtb"
DTB_DIR="out/arch/arm64/boot/dts"
test -d "${DTB_DIR}"

find "${DTB_DIR}" -name "*.dtb" -maxdepth 6 -print -exec cp -f {} "${OUTROOT}/dtb/" \;

echo "Collected dtbs: $(ls -1 "${OUTROOT}/dtb" | wc -l)"
