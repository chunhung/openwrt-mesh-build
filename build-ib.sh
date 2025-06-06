#!/usr/bin/env bash
set -euo pipefail
set -x   # 讓 CI 詳列每一步

# --------- 可外部覆寫的參數 -----------------------------
OPENWRT_TAG="${OPENWRT_TAG:-23.05.5}"
TARGET_FAMILY="${TARGET_FAMILY:-bcm27xx}"   # 64-bit RPi3
SUBTARGET="${SUBTARGET:-bcm2710}"           # rpi-3；64 bit 可改 bcm2710
PROFILE="${PROFILE:-rpi-3}"
# -------------------------------------------------------

DIR="${TARGET_FAMILY}/${SUBTARGET}"          # 目錄用斜線
IB_FILE="openwrt-imagebuilder-${OPENWRT_TAG}-${TARGET_FAMILY}-${SUBTARGET}.Linux-x86_64.tar.xz"
IB_URL="https://downloads.openwrt.org/releases/${OPENWRT_TAG}/targets/${DIR}/${IB_FILE}"
MIRROR_URL="https://mirrors.hit.edu.cn/openwrt/releases/${OPENWRT_TAG}/targets/${DIR}/${IB_FILE}"

JOBS="$(nproc)"
OUTDIR="output"

# 下載 Image Builder（主站失敗自動換鏡像）
if [ ! -f "$IB_FILE" ]; then
  wget -q --show-progress "$IB_URL" || wget -q --show-progress "$MIRROR_URL"
fi

# 解壓並安全改名
if [ ! -d imagebuilder ]; then
  tar xf "$IB_FILE"

  DIR_UNPACKED="${IB_FILE%.tar.xz}"   # ← 去掉尾碼，精準對到目錄
  mv "$DIR_UNPACKED" imagebuilder     # 只會有 1 個來源 + 1 目標
fi

cd imagebuilder
DEFAULT_PKGS="wpad-mesh-openssl kmod-batman-adv batctl avahi-daemon avahi-utils \
              luci luci-ssl luci-app-batman-adv luci-proto-batman-adv"

if ! make info | grep -q "Profile: ${PROFILE} "; then
  echo "❌ Profile '${PROFILE}' not found for ${TARGET_FAMILY}/${SUBTARGET}"
  echo "   👉 先執行 'make info' 查詢正確名稱"
  exit 1
fi


make image PROFILE="${PROFILE}" \
     PACKAGES="${PACKAGES:-$DEFAULT_PKGS}" \
     FILES="../files" \
     BIN_DIR="../${OUTDIR}" \
     -j"${JOBS}"

echo -e "\n🎉 Image(s) ready in ${OUTDIR}\n"
