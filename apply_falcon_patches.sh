#!/bin/bash

cd u-boot-imx/
git apply 0001-falcon-mode-phytec-imx8mp-u-boot.patch
cd ..

# 7.3.2 - Apply the ATF patch
cd imx-atf/
git apply 0001-falcon-mode-phytec-imx8mp-atf.patch
cd ..

# 7.3.3 - Apply the mkimage patch
cd imx-mkimage/
git apply 0001-falcon-mode-phytec-imx8mp-mk-image.patch
cd ..
