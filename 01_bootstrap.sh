#!/bin/bash

PWD="$(pwd)"
WORK_DIR="${PWD}/build"
L4T_DIR="${WORK_DIR}/l4t"
ROOTFS_DIR="${L4T_DIR}/rootfs"
FILES_DIR="${PWD}/files"

RELEASE=jammy
HOSTNAME=jetson
ROOT_PASSWORD=secret # TODO

#
# Base system
#

rm "${ROOTFS_DIR}/README.txt"

# Extract 'ubuntu-archive-keyring.gpg' from https://packages.debian.org/sid/ubuntu-archive-keyring
# and save it to '/usr/share/keyrings/ubuntu-archive-keyring.gpg'
debootstrap --arch=arm64 \
            --foreign \
            --variant=minbase \
            --include=systemd-sysv,systemd-timesyncd,udev,ca-certificates \
            --cache-dir="${PWD}/cache" \
            "${RELEASE}" \
            "${ROOTFS_DIR}"

cp "$(which qemu-aarch64-static)" "${ROOTFS_DIR}/usr/bin"

chroot "${ROOTFS_DIR}" /debootstrap/debootstrap --second-stage

#
# Repositories
#

# Install universe repository
APT_LIST_FILE="${ROOTFS_DIR}/etc/apt/sources.list"
APT_LIST_LINE="deb http://ports.ubuntu.com/ubuntu-ports ${RELEASE} universe"
grep -qxF "${APT_LIST_LINE}" "${APT_LIST_FILE}" || echo "${APT_LIST_LINE}" >> "${APT_LIST_FILE}"

# Install NVIDIA repository
wget -O "${ROOTFS_DIR}/etc/apt/trusted.gpg.d/nvidia_jetson.asc" 'https://repo.download.nvidia.com/jetson/jetson-ota-public.asc'
echo 'deb https://repo.download.nvidia.com/jetson/common r32.7 main' > "${ROOTFS_DIR}/etc/apt/sources.list.d/nvidia_jetson.list"
echo 'deb https://repo.download.nvidia.com/jetson/t210 r32.7 main' >> "${ROOTFS_DIR}/etc/apt/sources.list.d/nvidia_jetson.list"

# Update packages
chroot "${ROOTFS_DIR}" qemu-aarch64-static /usr/bin/apt update

#
# NVIDIA packages
#

L4T_TEGRA_DIR="${L4T_DIR}/nv_tegra"
L4T_KERNEL_DIR="${L4T_DIR}/kernel"
NVIDIA_PACKAGES_DIR="${ROOTFS_DIR}/opt/nvidia/l4t-packages"

# Enable chroot mode
mkdir -p "${NVIDIA_PACKAGES_DIR}"
touch "${NVIDIA_PACKAGES_DIR}/.nv-l4t-disable-boot-fw-update-in-preinstall"

# Core
chroot "${ROOTFS_DIR}" qemu-aarch64-static /usr/bin/apt install --no-install-recommends -y nvidia-l4t-core
ln -s /usr/lib/aarch64-linux-gnu/tegra "${ROOTFS_DIR}/usr/lib/tegra"
ln -s /usr/lib/aarch64-linux-gnu/tegra-egl "${ROOTFS_DIR}/usr/lib/tegra-egl"
echo "/usr/lib/tegra" > "${ROOTFS_DIR}/etc/ld.so.conf.d/nvidia-tegra.conf"
echo "/usr/lib/tegra-egl" > "${ROOTFS_DIR}/etc/ld.so.conf.d/nvidia-tegra-egl.conf"

# Kernel and bootloader
#chroot "${ROOTFS_DIR}" qemu-aarch64-static /usr/bin/apt install --no-install-recommends -y device-tree-compiler kmod python3
#chroot "${ROOTFS_DIR}" qemu-aarch64-static /usr/bin/apt install --no-install-recommends -y -o Dpkg::Options::="--force-overwrite" nvidia-l4t-init
#chroot "${ROOTFS_DIR}" qemu-aarch64-static /usr/bin/apt install --no-install-recommends -y nvidia-l4t-bootloader \
#                                                                                           nvidia-l4t-kernel \
#                                                                                           nvidia-l4t-kernel-dtbs \
#                                                                                           nvidia-l4t-initrd

# Firmware
#chroot "${ROOTFS_DIR}" qemu-aarch64-static /usr/bin/apt install --no-install-recommends -y nvidia-l4t-firmware \
#                                                                                           nvidia-l4t-xusb-firmware

#
# Networking
#

# Install netplan
chroot "${ROOTFS_DIR}" qemu-aarch64-static /usr/bin/apt install --no-install-recommends -y netplan.io

# Configure netplan
install -o 0 -g 0 --mode=0644 "${FILES_DIR}/etc/netplan/config.yaml" "${ROOTFS_DIR}/etc/netplan"

#
# SSH
#

# Install and configure SSH server
chroot "${ROOTFS_DIR}" qemu-aarch64-static /usr/bin/apt install --no-install-recommends -y openssh-server
install -o 0 -g 0 --mode=0644 "${FILES_DIR}/etc/ssh/sshd_config" "${ROOTFS_DIR}/etc/ssh"

# Regenerate host keys
rm "${ROOTFS_DIR}/etc/ssh/ssh_host_"*
chroot "${ROOTFS_DIR}" qemu-aarch64-static /usr/bin/ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -C jetson -N ''
chroot "${ROOTFS_DIR}" qemu-aarch64-static /usr/bin/ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -C jetson -N ''

# Remove small moduli
awk '$5 >= 3071' "${ROOTFS_DIR}/etc/ssh/moduli" > "${ROOTFS_DIR}/etc/ssh/moduli.safe"
mv "${ROOTFS_DIR}/etc/ssh/moduli.safe" "${ROOTFS_DIR}/etc/ssh/moduli"

# Generate key pair
if [ ! -f "${WORK_DIR}/id_ed25519.pub" ]; then
    ssh-keygen -t ed25519 -f "${WORK_DIR}/id_ed25519" -C root@jetson -N ''
fi
mkdir -p "${ROOTFS_DIR}/root/.ssh"
cp "${WORK_DIR}/id_ed25519.pub" "${ROOTFS_DIR}/root/.ssh/authorized_keys"
chmod 0600 "${ROOTFS_DIR}/root/.ssh/authorized_keys"

#
# Install and configure htop
#
chroot "${ROOTFS_DIR}" qemu-aarch64-static /usr/bin/apt install --no-install-recommends -y htop
install -o 0 -g 0 --mode=0644 {"${FILES_DIR}","${ROOTFS_DIR}"}/root/.config/htop/htoprc

#
# Install optional packages
#
chroot "${ROOTFS_DIR}" qemu-aarch64-static /usr/bin/apt install --no-install-recommends -y fdisk f2fs-tools net-tools nano

#
# System config
#

# Hostname
echo "${HOSTNAME}" > "${ROOTFS_DIR}/etc/hostname"

# Root password
PASSWD_SEQUENCE="${ROOT_PASSWORD}\n${ROOT_PASSWORD}"
printf "${PASSWD_SEQUENCE}" | chroot "${ROOTFS_DIR}" qemu-aarch64-static /usr/bin/passwd root

#
# Cleanup
#

# L4T packages
rm -rf "${NVIDIA_PACKAGES_DIR}"

# Remove message of the day
rm -f "${ROOTFS_DIR}/etc/update-motd.d"/*

# Packages
chroot "${ROOTFS_DIR}" qemu-aarch64-static /usr/bin/apt clean
rm -rf "${ROOTFS_DIR}/var/lib/apt/lists"/*

# Remove logs
rm "${ROOTFS_DIR}/var/log/apt/eipp.log.xz"
find "${ROOTFS_DIR}/var/log" -type f -exec truncate -s 0 {} \;

# Emulation binary
rm "${ROOTFS_DIR}/usr/bin/qemu-aarch64-static"
