#!/bin/bash

WORK_DIR="$(pwd)/build"
L4T_DIR="${WORK_DIR}/l4t"
KERNEL_DIR="${L4T_DIR}/kernel"
ROOTFS_DIR="${L4T_DIR}/rootfs"

export CROSS_COMPILE="${WORK_DIR}/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-"
export LOCALVERSION=-tegra

# Configure kernel
KERNEL_SOURCE_DIR="${L4T_DIR}/source/public/kernel/kernel-4.9"
KERNEL_OUT="${L4T_DIR}/source/public/build/kernel"
KERNEL_BOOT_OUT="${L4T_DIR}/source/public/build/kernel/arch/arm64/boot"
KERNEL_MODULES_OUT="${KERNEL_OUT}/modules"
mkdir -p "${KERNEL_OUT}" "${KERNEL_MODULES_OUT}"

# Generate default config
if [ ! -f "${KERNEL_OUT}/.config" ]; then
    make -C "${KERNEL_SOURCE_DIR}" ARCH=arm64 O="${KERNEL_OUT}" -j2 tegra_defconfig
fi

# Configure kernel
make -C "${KERNEL_SOURCE_DIR}" ARCH=arm64 O="${KERNEL_OUT}" -j2 menuconfig
# - Global setup / Support for paging of anonymous memory (swap): Disable
# - Kernel features / Maximum number of CPUs: 4
# - File systems / ext3: Disable
# -              / Btrfs: Disable
# -              / F2FS: Enable
# -              / Quota: Disable
# -              / FUSE: Disable
# -              / Overlay: Disable
# -              / DOS/FAT/NT / *: Disable
# -              / Miscellaneous: Disable
# -              / Network: Disable
# - Disable other unwanted features
# - Enable other wanted features

# Apply patch to fix the build script
# Forum post: https://forums.developer.nvidia.com/t/failed-to-make-l4t-kernel-dts/116399/9
patch -p0 < patch/fix_KBuild.patch

# Build kernel modules and dtbs
make -C "${KERNEL_SOURCE_DIR}" ARCH=arm64 O="${KERNEL_OUT}" -j$(nproc)

# Install kernel image
install -o 0 -g 0 --mode=644 -CDv "${KERNEL_BOOT_OUT}/Image" "${KERNEL_DIR}"
install -o 0 -g 0 --mode=644 -CDv "${KERNEL_BOOT_OUT}/Image.gz" "${KERNEL_DIR}"
install -o 0 -g 0 --mode=644 -CDv "${KERNEL_BOOT_OUT}/zImage" "${KERNEL_DIR}"

# Install kernel device tree files
install -o 0 -g 0 --mode=644 -CDv "${KERNEL_BOOT_OUT}/dts"/* "${KERNEL_DIR}/dtb"

# Install kernel modules
make -C "${KERNEL_SOURCE_DIR}" ARCH=arm64 O="${KERNEL_OUT}" INSTALL_MOD_PATH="${ROOTFS_DIR}" modules_install

# Configure bootloader
mkdir -p "${ROOTFS_DIR}/boot/extlinux"
install -o 0 -g 0 --mode=0644 -D "${L4T_DIR}/bootloader/extlinux.conf" "${ROOTFS_DIR}/boot/extlinux"
