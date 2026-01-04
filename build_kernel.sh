#!/usr/bin/env bash
set -euxo pipefail

# 你要的内核仓库/分支（先用 lineage-22.0；如果不存在再改 21.0）
KERNEL_REPO="https://github.com/LineageOS/android_kernel_sony_msm8998.git"
KERNEL_BRANCH="lineage-22.0"

# 输出目录
mkdir -p out

# 拉内核源码
rm -rf kernel
git clone --depth=1 -b "${KERNEL_BRANCH}" "${KERNEL_REPO}" kernel

# 编译
export ARCH=arm64
export SUBARCH=arm64

cd kernel

# 这里 defconfig 先用常见的 yoshino（之后我们再按你树里实际名字改）
DEFCONFIG="lineage_yoshino_defconfig"

make O=out "${DEFCONFIG}"
make -j"$(nproc)" O=out Image.gz dtbs

# 拷贝产物
cp -f out/arch/arm64/boot/Image.gz ../out/Image.gz

# 收集 dtb（目录可能因内核树略有差异；先用通用抓法）
mkdir -p ../out/dtb
find out/arch/arm64/boot/dts -name "*.dtb" -maxdepth 6 -print -exec cp -f {} ../out/dtb/ \;
