# Jetson Nano system image
This repository provides a collection of scripts and configuration files for building Jetso Nano SD card image from scratch.

## Dependencies

## Archlinux
Kernel build
```
yay -Sy base-devel bc inetutils vim
```

Bootstrapping
```
yay -Sy debootstrap qemu-user-static-bin
```

Flashing
```
# Simple
yay -Sy gdisk

# Simple + F2FS
yay -Sy gdisk f2fs-tools rsync
```
## Ubuntu
TODO

## Useful links:
- [Jetson Linux Archive](https://developer.nvidia.com/embedded/jetson-linux-archive)
  - [Jetson Linux R32.7.2](https://developer.nvidia.com/embedded/linux-tegra-r3272)

## Possible improvements
- Fix patching
- Do not install manual files and documentation (except LICENSE files)
- Rewise NVIDIA firmware packages and their usage
- Do not compile/include useless drivers
- Optional packages
