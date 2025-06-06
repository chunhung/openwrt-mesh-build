#!/usr/bin/env bash
set -e
OPENWRT_TAG="v23.05.3"
JOBS=$(nproc)
OUTDIR="../output"

[ -d openwrt ] || git clone --depth=1 --branch "$OPENWRT_TAG" https://github.com/openwrt/openwrt.git
cd openwrt

# Copy diffconfig & overlay
cp ../.config .
mkdir -p files
rsync -a ../files/ files/

./scripts/feeds update -a
./scripts/feeds install -a
make defconfig
make download -j$JOBS
make -j$JOBS

mkdir -p "$OUTDIR"
cp bin/targets/bcm27xx/bcm2709/*rpi-3*-sysupgrade.img* "$OUTDIR"/

echo "\n🎉 Image(s) ready in $OUTDIR\n"
