#!/usr/bin/env bash
set -euxo pipefail

KERNEL_REPO="${1:?need repo}"
KERNEL_BRANCH="${2:?need branch}"
DEFCONFIG_IN="${3:-}"

ROOT="$(pwd)"
OUTROOT="${ROOT}/out"

rm -rf "${OUTROOT}"
mkdir -p "${OUTROOT}"

# Optional token
if [ -n "${KERNEL_GITHUB_TOKEN:-}" ]; then
  AUTH_REPO="$(echo "${KERNEL_REPO}" | sed "s#https://github.com/#https://${KERNEL_GITHUB_TOKEN}@github.com/#")"
else
  AUTH_REPO="${KERNEL_REPO}"
fi

export GIT_TERMINAL_PROMPT=0
rm -rf kernel
git clone --depth=1 -b "${KERNEL_BRANCH}" "${AUTH_REPO}" kernel

export ARCH=arm64
export SUBARCH=arm64

cd kernel

# --- CONFIG STRATEGY ---
# If stock.config exists in the outer repo, use it (best for avoiding black screen)
if [ -f "${ROOT}/stock.config" ]; then
  echo "Using stock.config from repo root"
  mkdir -p out
  cp "${ROOT}/stock.config" out/.config
  # reconcile config with this kernel tree
  make O=out olddefconfig
else
  echo "No stock.config found, fallback to defconfig if provided/auto-picked"
  CONFIG_DIR="arch/arm64/configs"

  if [ -n "${DEFCONFIG_IN}" ] && [ -f "${CONFIG_DIR}/${DEFCONFIG_IN}" ]; then
    DEFCONFIG="${DEFCONFIG_IN}"
  else
    DEFCONFIG="$(ls -1 "${CONFIG_DIR}" | grep -iE 'defconfig$' | head -n 1)"
  fi

  echo "Using defconfig: ${DEFCONFIG}"
  make O=out "${DEFCONFIG}"
fi

# --- BUILD ---
make -j"$(nproc)" O=out \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabihf- \
  KCFLAGS="-Wno-error" \
  Image.gz

# export
cp -f out/arch/arm64/boot/Image.gz "${OUTROOT}/Image.gz"
ls -lah "${OUTROOT}/Image.gz"
