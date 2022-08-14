#!/bin/bash

set -e

WORK_DIR="$(pwd)/build"
L4T_DIR="${WORK_DIR}/l4t"

# Create work directory
mkdir -p "${WORK_DIR}"

# L4T package
L4T_URL=https://developer.nvidia.com/embedded/l4t/r32_release_v7.2/t210/jetson-210_linux_r32.7.2_aarch64.tbz2
wget -O - "${L4T_URL}" | tar -C "${WORK_DIR}" -xjf -

# Kernel source
KERNEL_SOURCE_URL=https://developer.nvidia.com/embedded/l4t/r32_release_v7.2/sources/t210/public_sources.tbz2
wget -O - "${KERNEL_SOURCE_URL}" | tar -C "${WORK_DIR}" -xjf -

mv "${WORK_DIR}/Linux_for_Tegra" "${L4T_DIR}"
tar -C "${L4T_DIR}/source/public" -xjf "${L4T_DIR}/source/public/kernel_src.tbz2"

# Toolchain
GCC_LINARO_URL=https://developer.nvidia.com/embedded/dlc/l4t-gcc-7-3-1-toolchain-64-bit
#GCC_LINARO_URL=http://releases.linaro.org/components/toolchain/binaries/7.3-2018.05/aarch64-linux-gnu/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz
wget -O - "${GCC_LINARO_URL}" | tar -C "${WORK_DIR}" -xJf -

chown -R "$(whoami):$(whoami)" "${WORK_DIR}"
