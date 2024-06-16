#!/bin/bash

clear

cd imx-atf/
#pd23.1.0  # Phytec SDK toolchain
source /opt/ampliphy-vendor-xwayland/BSP-Yocto-NXP-i.MX8MP-PD23.1.0/environment-setup-cortexa53-crypto-phytec-linux;set sysroot /opt/ampliphy-vendor-xwayland/BSP-Yocto-NXP-i.MX8MP-PD23.1.0/sysroots/cortexa53-crypto-phytec-linux

rm -rf build/
make -j16 CROSS_COMPILE=aarch64-phytec-linux- PLAT=imx8mp LD=aarch64-phytec-linux-ld CC=aarch64-phytec-linux-gcc  IMX_BOOT_UART_BASE=0x30890000 IMX_BOOT_UART_BASE=0x30860000 LDFLAGS= bl31
cp build/imx8mp/release/bl31.bin ../imx-mkimage/iMX8M/  # 1
cd ..

cd u-boot-imx/
make distclean  # 4
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make phycore-imx8mp_defconfig
CROSS_COMPILE=aarch64-linux-gnu- make -j $(nproc --all)
cp u-boot*.bin ../imx-mkimage/iMX8M/  # 5
cp spl/u-boot-spl*.bin ../imx-mkimage/iMX8M/
cp arch/arm/dts/imx8mp-phyboard-pollux-rdk.dtb ../imx-mkimage/iMX8M/  # 6
cp tools/mkimage ../imx-mkimage/iMX8M/mkimage_uboot  # 7
cd ..

cd imx-mkimage/  # 8
cp ../firmware-imx-8.18.1/firmware/ddr/synopsys/lpddr4* ../imx-mkimage/iMX8M/  # 2
# $$$$ cp ../firmware-imx-8.18.1/firmware/hdmi/cadence/signed_hdmi_imx8m.bin ../imx-mkimage/iMX8M/
make SOC=iMX8MP dtbs=imx8mp-phyboard-pollux-rdk.dtb flash_evk_falcon
cd ..

sudo dd if=imx-mkimage/iMX8M/flash.bin of=/dev/sdb bs=1k seek=32 conv=fsync; sync
sudo dd if=imx-atf/build/imx8mp/release/bl31.bin of=/dev/sdb bs=512 seek=50131584 conv=fsync; sync

cd linux-imx/arch/arm64/boot/
mkimage -A arm -O linux -T kernel -C none -a 0x57FFFFC0 -e 0x58000000 -n "Linux kernel" -d Image uImage

# $$$$ sudo mkdir -p /media/$USER/root/home/root/.falcon
# $$$$ sudo cp uImage /media/$USER/root/home/root/.falcon
sync; umount /media/$USER/boot; umount /media/$USER/root
ls /media/$USER/

ls -alh imx-atf/build/imx8mp/release/bl31.bin

cd ../../../..

