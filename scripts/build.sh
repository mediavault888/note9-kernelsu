#!/usr/bin/env bash
# Rebuild boot-los20-kernelsu.img for Samsung Galaxy Note 9 (SM-N960F, crownlte)
# on official LineageOS 20 (20241226 nightly), with KernelSU-Next (legacy) built in.
#
# Usage: scripts/build.sh [workdir]     (needs git, make, python3, ~10 GB, ~15 min on 8 cores)
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
W="${1:-$PWD/work}"
mkdir -p "$W" && cd "$W"

KERNEL_COMMIT=6a9461f9460ca51d1217e5069a5d5556fcc79e63   # = kernel inside the LOS20 20241226 build
KSU_COMMIT=e5f5ec998de88b9fc43c62cff8f7ae12d3f4800a      # KernelSU-Next legacy branch
ROM=lineage-20.0-20241226-nightly-crownlte-signed.zip
ROM_SHA256=87c0d45fd18ff78a143d158bba7a653872dbf4105883d8225fa61d43527ed83f

# 1. sources + toolchains (same clang LineageOS used: r416183b, with GNU binutils)
[ -d kernel ] || git clone --depth=1 -b lineage-20 https://github.com/LineageOS/android_kernel_samsung_exynos9810 kernel
git -C kernel checkout -q "$KERNEL_COMMIT"
[ -d KernelSU-Next ] || git clone -b legacy https://github.com/KernelSU-Next/KernelSU-Next   # full history: version = commit count
git -C KernelSU-Next checkout -q "$KSU_COMMIT"
[ -d tc/clang ] || git clone --depth=1 https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b tc/clang
[ -d tc/gcc ] || git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 tc/gcc

# 2. stock boot.img from the official ROM (archive: lineage-archive.timschumi.net)
if [ ! -f boot.img ]; then
  [ -f "$ROM" ] || curl -L -o "$ROM" "https://b4.timschumi.net/lineage-archive/$ROM"
  echo "$ROM_SHA256  $ROM" | sha256sum -c
  unzip -o -q "$ROM" boot.img
fi

# 3. patches
git -C KernelSU-Next apply --check "$REPO/patches/0002-kernelsu-next-legacy-4.9-fixes.patch" 2>/dev/null &&
  git -C KernelSU-Next apply "$REPO/patches/0002-kernelsu-next-legacy-4.9-fixes.patch"
git -C kernel apply --check "$REPO/patches/0001-los20-kernel-ksu-hooks-and-4.9-fixes.patch" 2>/dev/null &&
  git -C kernel apply "$REPO/patches/0001-los20-kernel-ksu-hooks-and-4.9-fixes.patch"
ln -sfn "$W/KernelSU-Next/kernel" kernel/drivers/kernelsu

# 4. config + build
export PATH="$W/tc/clang/bin:$W/tc/gcc/bin:$PATH"
M=(make -j"$(nproc)" -C kernel O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-android-)
"${M[@]}" exynos9810-crownlte_defconfig
kernel/scripts/kconfig/merge_config.sh -m -O kernel/out kernel/out/.config "$REPO/configs/kernelsu-containers.config"
"${M[@]}" olddefconfig
# KernelSU's Kbuild may patch fs/namespace.c mid-build; if the first link fails, the second run succeeds.
"${M[@]}" Image || "${M[@]}" Image

# 5. put the new kernel into the stock boot.img (everything else byte-identical)
python3 "$REPO/scripts/repack_boot.py" boot.img kernel/out/arch/arm64/boot/Image boot-los20-kernelsu.img
sha256sum boot-los20-kernelsu.img
