#!/usr/bin/env bash
set -euxo pipefail

KERNEL_REPO="${1:-https://github.com/whatawurst/android_kernel_sony_msm8998.git}"
KERNEL_BRANCH="${2:-lineage-21.0}"
# 允许传 defconfig；如果不存在则自动选
DEFCONFIG_IN="${3:-}"

ROOT="$(pwd)"
OUTROOT="${ROOT}/out"

rm -rf "${OUTROOT}"
mkdir -p "${OUTROOT}"

# -------- GitHub token support (OPTIONAL) --------
# If KERNEL_GITHUB_TOKEN is set, use it for clone (do NOT print token)
if [ -n "${KERNEL_GITHUB_TOKEN:-}" ]; then
  echo "Using GitHub token for kernel clone"
  # NOTE: token will be masked by GitHub Actions logs, but we still avoid echoing full URL
  AUTH_REPO="$(echo "${KERNEL_REPO}" | sed "s#https://github.com/#https://${KERNEL_GITHUB_TOKEN}@github.com/#")"
else
  AUTH_REPO="${KERNEL_REPO}"
fi

# Avoid interactive auth in CI
export GIT_TERMINAL_PROMPT=0
git config --global --unset-all http.https://github.com/.extraheader || true
git config --global --unset-all http.extraheader || true
git config --global --unset-all http.https://github.com/.header || true
git config --global --unset-all http.extraheader || true

rm -rf kernel
git clone --depth=1 -b "${KERNEL_BRANCH}" "${AUTH_REPO}" kernel

export ARCH=arm64
export SUBARCH=arm64

cd kernel

CONFIG_DIR="arch/arm64/configs"

pick_defconfig() {
  local c="$1"
  if [ -n "$c" ] && [ -f "${CONFIG_DIR}/${c}" ]; then
    echo "$c"
    return 0
  fi
  return 1
}

auto_defconfig() {
  local found=""

  # Priority: yoshino -> maple -> sony -> msm8998 -> lineage -> any defconfig
  found="$(ls -1 "${CONFIG_DIR}" | grep -iE 'yoshino.*defconfig$' | head -n 1 || true)"
  [ -n "$found" ] && { echo "$found"; return 0; }

  found="$(ls -1 "${CONFIG_DIR}" | grep -iE 'maple.*defconfig$' | head -n 1 || true)"
  [ -n "$found" ] && { echo "$found"; return 0; }

  found="$(ls -1 "${CONFIG_DIR}" | grep -iE 'sony.*defconfig$' | head -n 1 || true)"
  [ -n "$found" ] && { echo "$found"; return 0; }

  found="$(ls -1 "${CONFIG_DIR}" | grep -iE 'msm8998.*defconfig$' | head -n 1 || true)"
  [ -n "$found" ] && { echo "$found"; return 0; }

  found="$(ls -1 "${CONFIG_DIR}" | grep -iE 'lineage.*defconfig$' | head -n 1 || true)"
  [ -n "$found" ] && { echo "$found"; return 0; }

  found="$(ls -1 "${CONFIG_DIR}" | grep -iE 'defconfig$' | head -n 1 || true)"
  [ -n "$found" ] && { echo "$found"; return 0; }

  return 1
}

if pick_defconfig "${DEFCONFIG_IN}"; then
  DEFCONFIG="${DEFCONFIG_IN}"
  echo "Using provided defconfig: ${DEFCONFIG}"
else
  echo "Provided defconfig missing or empty: '${DEFCONFIG_IN}'"
  echo "Available configs (top 80):"
  ls -1 "${CONFIG_DIR}" | head -n 80 || true

  DEFCONFIG="$(auto_defconfig)"
  echo "Auto-selected defconfig: ${DEFCONFIG}"
fi

# ---- Configure ----
make O=out "${DEFCONFIG}"

# ---- Build ----
# Fix 1: provide both CROSS_COMPILE and CROSS_COMPILE_ARM32 (needed for compat vDSO)
# Fix 2: disable -Werror escalation (old kernel + new GCC emits new warnings)
make -j"$(nproc)" O=out \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabihf- \
  KCFLAGS="-Wno-error" \
  Image.gz dtbs

# ---- Export outputs for workflow ----
cp -f out/arch/arm64/boot/Image.gz "${OUTROOT}/Image.gz"

mkdir -p "${OUTROOT}/dtb"
DTB_DIR="out/arch/arm64/boot/dts"
if [ ! -d "${DTB_DIR}" ]; then
  echo "ERROR: DTB dir not found: ${DTB_DIR}"
  find out -maxdepth 5 -type d | head -n 200
  exit 1
fi

# Copy all dtb files (later you can restrict to maple-only for smaller kernel_dtb)
find "${DTB_DIR}" -name "*.dtb" -maxdepth 6 -print -exec cp -f {} "${OUTROOT}/dtb/" \;

echo "Collected dtbs: $(ls -1 "${OUTROOT}/dtb" | wc -l)"
echo "Done. Outputs:"
ls -lah "${OUTROOT}/Image.gz"
ls -lah "${OUTROOT}/dtb" | head -n 30
