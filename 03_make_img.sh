#!/bin/bash

#
# Produce system image
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

# Create partitions
"${L4T_TOOLS_DIR}/nvptparser.py" "${L4T_SIGNED_IMAGE_DIR}/flash.xml" sdcard | while IFS= read -r PROPERTIES; do
	eval "${PROPERTIES}"
	sgdisk -n "${part_num}:0:+$(( ${part_size} / 512 ))" \
		   -c "${part_num}:${part_name}" \
		   -t "${part_num}:8300" \
		   "${JETSON_IMAGE_PATH}"
done

#
# Write partitions
#

JETSON_IMAGE_LOOP_DEV="$(losetup --show -f -P "${JETSON_IMAGE_PATH}")"

# Flash partition images (except APP)
"${L4T_TOOLS_DIR}/nvptparser.py" "${L4T_SIGNED_IMAGE_DIR}/flash.xml" sdcard | while IFS= read -r PROPERTIES; do
	eval "${PROPERTIES}"
	if [ "${part_name}" = "APP" ]; then
		PARTITION_IMAGE_PATH="${L4T_BOOTLOADER_DIR}/${part_file}.raw"
	elif [ -f "${L4T_SIGNED_IMAGE_DIR}/${part_file}" ]; then
		PARTITION_IMAGE_PATH="${L4T_SIGNED_IMAGE_DIR}/${part_file}"
	elif [ -f "${L4T_BOOTLOADER_DIR}/${part_file}" ]; then
		PARTITION_IMAGE_PATH="${L4T_BOOTLOADER_DIR}/${part_file}"
	fi
	dd if="${PARTITION_IMAGE_PATH}" of="${JETSON_IMAGE_LOOP_DEV}p${part_num}"
done

# Unmount image
losetup -d "${JETSON_IMAGE_LOOP_DEV}"

# Compress image using zstd
zstd -f "${JETSON_IMAGE_PATH}"
