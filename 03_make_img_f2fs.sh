#!/bin/bash

#
# Produce system image with root on F2FS filesystem
#

PWD="$(pwd)"
WORK_DIR="${PWD}/build"
L4T_DIR="${WORK_DIR}/l4t"
ROOTFS_DIR="${L4T_DIR}/rootfs"

L4T_BOOTLOADER_DIR="${L4T_DIR}/bootloader"
L4T_SIGNED_IMAGE_DIR="${L4T_BOOTLOADER_DIR}/signed"
L4T_TOOLS_DIR="${L4T_DIR}/tools"

JETSON_IMAGE_FILENAME=jetson.img
JETSON_IMAGE_PATH="${WORK_DIR}/${JETSON_IMAGE_FILENAME}"

#
# Create FS images
#

ROOTFS_DIR_SIZE="$(du -bms "${ROOTFS_DIR}" | awk '{print $1}')"
ROOTFS_DIR_SIZE="$(("${ROOTFS_DIR_SIZE}" * 3 / 2))"

echo "RootFS size: ${ROOTFS_DIR_SIZE} MB"

pushd "${L4T_DIR}"
BOARDID=3448 FAB=200 BUILD_SD_IMAGE=1 bash "${L4T_DIR}/flash.sh" --no-root-check --no-flash --sign -S "${ROOTFS_DIR_SIZE}MiB" jetson-nano-qspi-sd mmcblk0p1
popd

#
# Allocate image
#

JETSON_IMAGE_SIZE=$("${L4T_TOOLS_DIR}/nvptparser.py" "${L4T_SIGNED_IMAGE_DIR}/flash.xml" sdcard | awk -F'[=;]' '{sum += (int($6 / (2048 * 512)) + 1)} END {printf "%d\n", sum + 2}')

# Allocate SD card image filled with NULL bytes
dd if=/dev/zero of="${JETSON_IMAGE_PATH}" bs=1048576 count="${JETSON_IMAGE_SIZE}"
chmod +r "${JETSON_IMAGE_PATH}"

#
# Create partitions
#

# Create GPT table
sgdisk -og "${JETSON_IMAGE_PATH}"

# Create partitions (except APP)
"${L4T_TOOLS_DIR}/nvptparser.py" "${L4T_SIGNED_IMAGE_DIR}/flash.xml" sdcard | grep -v 'part_name=APP' | while IFS= read -r PROPERTIES; do
	eval "${PROPERTIES}"
	sgdisk -n "${part_num}:0:+$(( ${part_size} / 512 ))" \
		   -c "${part_num}:${part_name}" \
		   -t "${part_num}:8300" \
		   "${JETSON_IMAGE_PATH}"
done

# Get APP partition properties
eval $("${L4T_TOOLS_DIR}/nvptparser.py" "${L4T_SIGNED_IMAGE_DIR}/flash.xml" sdcard | grep 'part_name=APP')

# Define BOOT (APP) partition size
BOOT_PART_SIZE=$(( 64 * 1024 * 1024 )) # 64 MB

# Create APP partition
sgdisk -n "1:0:+$(( ${BOOT_PART_SIZE} / 512 ))" \
	   -c "1:APP" \
	   -t "1:8300" \
       "${JETSON_IMAGE_PATH}"

# Create ROOT partition
sgdisk -n "15:0:+$(( ( ${part_size} - ${BOOT_PART_SIZE} ) / 512 ))" \
	   -c "15:ROOT" \
	   -t "15:8300" \
       "${JETSON_IMAGE_PATH}"

#
# Write partitions
#

JETSON_IMAGE_LOOP_DEV="$(losetup --show -f -P "${JETSON_IMAGE_PATH}")"

# Flash partition images (except APP)
"${L4T_TOOLS_DIR}/nvptparser.py" "${L4T_SIGNED_IMAGE_DIR}/flash.xml" sdcard | grep -v 'part_name=APP' | while IFS= read -r PROPERTIES; do
	eval "${PROPERTIES}"
	if [ -f "${L4T_SIGNED_IMAGE_DIR}/${part_file}" ]; then
		PARTITION_IMAGE_PATH="${L4T_SIGNED_IMAGE_DIR}/${part_file}"
	elif [ -f "${L4T_BOOTLOADER_DIR}/${part_file}" ]; then
		PARTITION_IMAGE_PATH="${L4T_BOOTLOADER_DIR}/${part_file}"
	fi
	dd if="${PARTITION_IMAGE_PATH}" of="${JETSON_IMAGE_LOOP_DEV}p${part_num}"
done


# Mount temporary system partition
MOUNT_DIR="${WORK_DIR}/mount"
mkdir -p "${MOUNT_DIR}"/{app,root,tmp}
mount "${L4T_BOOTLOADER_DIR}/system.img.raw" "${MOUNT_DIR}/tmp"

# Flash BOOT (APP) partition
mkfs.ext4 -f "${JETSON_IMAGE_LOOP_DEV}p1"
mount "${JETSON_IMAGE_LOOP_DEV}p1" "${MOUNT_DIR}/app"
rsync -aAHx --info=progress2 --delete "${MOUNT_DIR}/tmp/boot" "${MOUNT_DIR}/app"

# Fix boot arguments
nano "${MOUNT_DIR}/app/boot/extlinux/extlinux.conf"
# APPEND ${cbootargs} quiet root=/dev/mmcblk0p15 rw rootwait rootfstype=f2fs console=ttyS0,115200n8 console=tty0 fbcon=map:0 net.ifnames=0
umount "${MOUNT_DIR}/app"

# Flash ROOT partition
mkfs.f2fs -f "${JETSON_IMAGE_LOOP_DEV}p15"
mount "${JETSON_IMAGE_LOOP_DEV}p15" "${MOUNT_DIR}/root"
rsync -aAHx --info=progress2 --delete --exclude boot "${MOUNT_DIR}/tmp/" "${MOUNT_DIR}/root/"
echo '/dev/root / f2fs defaults,noatime 0 1' > "${MOUNT_DIR}/root/etc/fstab"
umount "${MOUNT_DIR}/root"

umount "${MOUNT_DIR}/tmp"
rm -rf "${MOUNT_DIR}"

# Unmount image
losetup -d "${JETSON_IMAGE_LOOP_DEV}"

# Compress image using zstd
zstd -f "${JETSON_IMAGE_PATH}"
