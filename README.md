# Jetson Nano system image
This repository provides a collection of scripts and configuration files for building Jetso Nano SD card image from scratch.

##
How to:
1. Install dependencies
2. Run `sudo ./00_sources.sh` to download toolchain, driver package and source files
3. Run `sudo ./01_bootstrap.sh` to bootstrap root filesystem
4. Run `sudo ./02_kernel.sh` to configure, build and install kernel
5. Run one of the following commands to create `.img` file(s)
   - `sudo ./03_make_img.sh`: Single `.img` file
   - `sudo ./03_make_img_f2fs.sh`: Single `.img` file with root on F2FS filesystem

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
