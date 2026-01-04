#!/usr/bin/env bash
set -euxo pipefail

KERNEL_REPO="${1:-https://github.com/whatawurst/android_kernel_sony_msm8998.git}"
KERNEL_BRANCH="${2:-lineage-21.0}"
# 第三个参数仍然允许你传 defconfig；如果传的不存在，就自动探测
DEFCONFIG_IN="${3:-}"

ROOT="$(pwd)"
OUTROOT="${ROOT}/out"

rm -rf "${OUTROOT}"
mkdir -p "${OUTROOT}"

# Optional token for GitHub clone
if [ -n "${KERNEL_GITHUB_TOKEN:-}" ]; then
  echo "Using GitHub token for kernel clone"
  AUTH_REPO="$(echo "${KERNEL_REPO}" | sed "s#https://github.com/#https://${KERNEL_GITHUB_TOKEN}@github.com/#")"
else
  AUTH_REPO="${KERNEL_REPO}"
fi

export GIT_TERMINAL_PROMPT=0
git config --global --unset-all http.https://github.com/.extraheader || true
git config --global --unset-all http.extraheader || true

rm -rf kernel
git clone --depth=1 -b "${KERNEL_BRANCH}" "${AUTH_REPO}" kernel

export ARCH=arm64
export SUBARCH=arm64

cd kernel

CONFIG_DIR="arch/arm64/configs"

pick_defconfig() {
  # $1: candidate name
  local c="$1"
  if [ -n "$c" ] && [ -f "${CONFIG_DIR}/${c}" ]; then
    echo "$c"
    return 0
  fi
  return 1
}

auto_defconfig() {
  # 优先顺序：yoshino / maple / sony / msm8998 / lineage / defconfig
  local found=""
  found="$(ls -1 "${CONFIG_DIR}" | grep -iE 'yoshino.*defconfig' | head -n 1 || true)"
  [ -n "$found" ] && { echo "$found"; return 0; }

  found="$(ls -1 "${CONFIG_DIR}" | grep -iE 'maple.*defconfig' | head -n 1 || true)"
  [ -n "$found" ] && { echo "$found"; return 0; }

  found="$(ls -1 "${CONFIG_DIR}" | grep -iE 'sony.*defconfig' | head -n 1 || true)"
  [ -n "$found" ] && { echo "$found"; return 0; }

  found="$(ls -1 "${CONFIG_DIR}" | grep -iE 'msm8998.*defconfig' | head -n 1 || true)"
  [ -n "$found" ] && { echo "$found"; return 0; }

  found="$(ls -1 "${CONFIG_DIR}" | grep -iE 'lineage.*defconfig' | head -n 1 || true)"
  [ -n "$found" ] && { echo "$found"; return 0; }

  # 兜底：任何 defconfig
  found="$(ls -1 "${CONFIG_DIR}" | grep -iE 'defconfig$' | head -n 1 || true)"
  [ -n "$found" ] && { echo "$found"; return 0; }

  return 1
}

if pick_defconfig "${DEFCONFIG_IN}"; then
  DEFCONFIG="${DEFCONFIG_IN}"
  echo "Using provided defconfig: ${DEFCONFIG}"
else
  echo "Provided defconfig missing or empty: '${DEFCONFIG_IN}'"
  echo "Available configs (top 60):"
  ls -1 "${CONFIG_DIR}" | head -n 60 || true

  DEFCONFIG="$(auto_defconfig)"
  echo "Auto-selected defconfig: ${DEFCONFIG}"
fi

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
