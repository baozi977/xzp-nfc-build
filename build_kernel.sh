#!/usr/bin/env bash
set -euxo pipefail

# 这里假设你的内核源码在 ./kernel
KERNEL_DIR="$(pwd)/kernel"
OUTDIR="$(pwd)/out"
mkdir -p "$OUTDIR"

# 你需要自己确认 defconfig 名字（例如 lineage_yoshino_defconfig / maple_defconfig 等）
DEFCONFIG="lineage_yoshino_defconfig"

export ARCH=arm64
export SUBARCH=arm64

# 工具链：你可以用 kernel 自带 clang 或者你 repo 里准备好的 clang
# 这里给一个通用写法：使用系统 clang（如果你的内核要求特定 clang，请替换）
export CC=clang || true

cd "$KERNEL_DIR"

make O=out "$DEFCONFIG"
make -j"$(nproc)" O=out Image.gz dtbs

# 拷贝输出给后续步骤用
cp -f out/arch/arm64/boot/Image.gz "$OUTDIR/Image.gz"

# dtb 输出目录因内核树而异，常见是 out/arch/arm64/boot/dts/qcom/
DTB_SRC="out/arch/arm64/boot/dts"
mkdir -p "$OUTDIR/dtb"
find "$DTB_SRC" -name "*.dtb" -maxdepth 5 -print -exec cp -f {} "$OUTDIR/dtb/" \;

# 可选：你也可以只拷 maple 相关 dtb（更干净）
# find "$DTB_SRC" -name "*maple*.dtb" -exec cp -f {} "$OUTDIR/dtb/" \;
