#!/usr/bin/env bash
set -euxo pipefail

KERNEL_REPO="${1:-https://github.com/LineageOS/android_kernel_sony_msm8998.git}"
KERNEL_BRANCH="${2:-lineage-22.0}"
DEFCONFIG="${3:-lineage_yoshino_defconfig}"

ROOT="$(pwd)"
OUTROOT="${ROOT}/out"

rm -rf "${OUTROOT}"
mkdir -p "${OUTROOT}"

rm -rf kernel
git clone --depth=1 -b "${KERNEL_BRANCH}" "${KERNEL_REPO}" kernel

export ARCH=arm64
export SUBARCH=arm64

cd kernel

echo "Using defconfig: ${DEFCONFIG}"
make O=out "${DEFCONFIG}"
make -j"$(nproc)" O=out Image.gz dtbs

cp -f out/arch/arm64/boot/Image.gz "${OUTROOT}/Image.gz"

mkdir -p "${OUTROOT}/dtb"
DTB_DIR="out/arch/arm64/boot/dts"
if [ ! -d "${DTB_DIR}" ]; then
  echo "ERROR: DTB dir not found: ${DTB_DIR}"
  find out -maxdepth 4 -type d | head -n 200
  exit 1
fi

find "${DTB_DIR}" -name "*.dtb" -maxdepth 6 -print -exec cp -f {} "${OUTROOT}/dtb/" \;

echo "Collected dtbs: $(ls -1 "${OUTROOT}/dtb" | wc -l)"
