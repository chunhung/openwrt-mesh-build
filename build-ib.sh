#!/usr/bin/env bash
set -e
OPENWRT_TAG="23.05.3"
TARGET="bcm27xx/bcm2709"
PROFILE="rpi-3"
IB_FILE="openwrt-imagebuilder-${OPENWRT_TAG}-${TARGET}.Linux-x86_64.tar.xz"
IB_URL="https://downloads.openwrt.org/releases/${OPENWRT_TAG}/targets/${TARGET}/${IB_FILE}"
JOBS=$(nproc)
OUTDIR="output"

# Fetch Image Builder
[ -f "$IB_FILE" ] || wget -q --show-progress "$IB_URL"
[ -d imagebuilder ] || { tar xf "$IB_FILE" && mv openwrt-imagebuilder-* imagebuilder; }

cd imagebuilder
# Assemble image with packages & overlay
make image PROFILE="$PROFILE" \
     PACKAGES="wpad-mesh-openssl kmod-batman-adv batctl avahi-daemon avahi-utils usbutils luci luci-ssl-openssl luci-app-batman-adv luci-proto-batman-adv htop nano tcpdump" \
     FILES="../files" \
     BIN_DIR="${OUTDIR}" \
     -j$JOBS

echo -e "\n🎉 Image(s) ready in ${OUTDIR}\n"
