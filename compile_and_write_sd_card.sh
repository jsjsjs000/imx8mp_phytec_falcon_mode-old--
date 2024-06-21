#!/bin/bash

# sdcard=/dev/sda      # PCO laptop external SD card reader
# sdcard=/dev/sdb      # jarsulk home PC
# sdcard=/dev/mmcblk0  # PCO laptop internal SD card reader

pd=23.1.0
firmware=firmware-imx-8.18.1
# pd=22.1.1
# firmware=firmware-imx-8.14
# firmware=firmware-imx-8.18.1

flash_evk=flash_evk         # normal boot
# flash_evk=flash_evk_falcon  # Falcon boot

build_kernel=yes
# build_kernel=no

default="\e[0m"
red="\e[31m"
yellow="\e[33m"

clear
echo -e "${yellow}USER = $USER"
echo -e "sdcard = $sdcard"
echo -e "pd = $pd"
echo -e "flash_evk = ${flash_evk}${default}"
echo
lsblk -e7
echo

if [ -z "${USER}" ]; then
	echo -e "${red}\nVariable 'USER' not defined in script.${default}\n"
	exit 1
fi

if [ -z "${sdcard}" ]; then
	echo -e "${red}\nVariable 'sdcard' not defined in script.${default}\n"
	exit 1
fi

if [ -z "${pd}" ]; then
	echo -e "${red}\nVariable 'pd' not defined in script.${default}\n"
	exit 1
fi

if [ -z "${flash_evk}" ]; then
	echo -e "${red}\nVariable 'flash_evk' not defined in script.${default}\n"
	exit 1
fi

sleep 1

# -------------------- ATF --------------------
cd imx-atf/
# Phytec SDK toolchain
source /opt/ampliphy-vendor-xwayland/BSP-Yocto-NXP-i.MX8MP-PD$pd/environment-setup-cortexa53-crypto-phytec-linux
set sysroot /opt/ampliphy-vendor-xwayland/BSP-Yocto-NXP-i.MX8MP-PD$pd/sysroots/cortexa53-crypto-phytec-linux

rm -rf build/
make distclean
make -j16 CROSS_COMPILE=aarch64-phytec-linux- PLAT=imx8mp LD=aarch64-phytec-linux-ld CC=aarch64-phytec-linux-gcc  IMX_BOOT_UART_BASE=0x30890000 IMX_BOOT_UART_BASE=0x30860000 LDFLAGS= bl31
cp build/imx8mp/release/bl31.bin ../imx-mkimage/iMX8M/  # 1
cd ..

if [ ! -f imx-atf/build/imx8mp/release/bl31.bin ]; then
	echo -e "${red}Error: File imx-atf/build/imx8mp/release/bl31.bin not exist${default}"
	exit 1
else
	echo -e "${yellow}"
	ls -al imx-atf/build/imx8mp/release/bl31.bin
	echo -e "${default}"
fi

# -------------------- U-boot --------------------
cd u-boot-imx/
make distclean  # 4
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make phycore-imx8mp_defconfig
cp ../$firmware/firmware/ddr/synopsys/lpddr4* .
CROSS_COMPILE=aarch64-linux-gnu- make -j $(nproc --all)
cp u-boot*.bin ../imx-mkimage/iMX8M/  # 5
cp spl/u-boot-spl*.bin ../imx-mkimage/iMX8M/
cp arch/arm/dts/imx8mp-phyboard-pollux-rdk.dtb ../imx-mkimage/iMX8M/  # 6
cp tools/mkimage ../imx-mkimage/iMX8M/mkimage_uboot  # 7
cd ..

# -------------------- mk-image --------------------
cd imx-mkimage/  # 8
cp ../$firmware/firmware/ddr/synopsys/lpddr4* ../imx-mkimage/iMX8M/  # 2
# cp ../$firmware/firmware/hdmi/cadence/signed_hdmi_imx8m.bin ../imx-mkimage/iMX8M/
make SOC=iMX8MP dtbs=imx8mp-phyboard-pollux-rdk.dtb $flash_evk
cd ..

if [ ! -f imx-mkimage/iMX8M/flash.bin ]; then
	echo -e "${red}Error: File imx-mkimage/iMX8M/flash.bin not exist${default}"
	exit 1
else
	echo -e "${yellow}"
	ls -al imx-mkimage/iMX8M/flash.bin
	echo -e "${default}"
fi

# -------------------- Linux Kernel --------------------
if [ $build_kernel == "yes" ]; then
	cd linux-imx/

	if [ ! -f .config ]; then
		ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make imx_v8_defconfig
	fi

	ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make -j $(nproc --all) all

	cd ..
fi

sudo dd if=imx-mkimage/iMX8M/flash.bin of=${sdcard} bs=1k seek=32 conv=fsync; sync
# sudo dd if=imx-atf/build/imx8mp/release/bl31.bin of=${sdcard} bs=512 seek=50131584 conv=fsync; sync

if [ $flash_evk == "flash_evk_falcon" ]; then
# -------------------- u-boot.itb to SD card --------------------
	cp imx-mkimage/iMX8M/u-boot.itb /media/$USER/boot

# -------------------- FIT image contains the ATF and the kernel Image --------------------
	cp linux-imx/arch/arm64/boot/Image imx-mkimage/iMX8M/

	cd imx-mkimage/iMX8M/
	chmod +x ../mkimage_fit_atf_kernel.sh
	# FIT image
	ATF_LOAD_ADDR=0x00970000 KERNEL_LOAD_ADDR=0x40200000 ../mkimage_fit_atf_kernel.sh > Image.its
	# FIT binary
	./mkimage_uboot -E -p 0x3000 -f Image.its Image.itb
	cp Image.itb /media/$USER/boot
	cd ../..

# -------------------- Flattened Device Tree --------------------
	cd linux-imx/arch/arm64/boot/
	mkimage -A arm -O linux -T kernel -C none -a 0x43FFFFC0 -e 0x44000000 -n "Linux kernel" -d Image uImage
	sudo mkdir -p /media/$USER/root/home/root/.falcon
	sudo cp uImage /media/$USER/root/home/root/.falcon
	cd ../../../..
fi

# -------------------- Unmount SD card --------------------
sync; umount /media/$USER/boot; umount /media/$USER/root
ls /media/$USER/

ls -al imx-mkimage/iMX8M/flash.bin
ls -al imx-atf/build/imx8mp/release/bl31.bin
ls -al imx-mkimage/iMX8M/u-boot.itb
ls -al imx-mkimage/iMX8M/Image.its
ls -al imx-mkimage/iMX8M/Image.itb
ls -al u-boot-imx/spl/u-boot-spl*.bin
