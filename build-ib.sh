#!/usr/bin/env bash
set -euo pipefail
set -x   # 讓 CI 詳列每一步

# --------- 可外部覆寫的參數 -----------------------------
OPENWRT_TAG="${OPENWRT_TAG:-23.05.5}"
TARGET_FAMILY="${TARGET_FAMILY:-bcm27xx}"
SUBTARGET="${SUBTARGET:-bcm2710}"           # 64-bit RPi3
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
DEFAULT_PKGS="-wpad-basic -wpad-basic-mbedtls -wpad-basic-wolfssl wpad-mesh-openssl \
  kmod-batman-adv batctl-default \
  -luci-ssl -luci-ssl-mbedtls -luci-ssl-wolfssl -libustream-mbedtls -libustream-wolfsslluci \
  luci-ssl-openssl  luci-proto-batman-adv \
  avahi-daemon avahi-utils"

#if ! make info | grep -q "Profile: ${PROFILE} "; then
#  echo "❌ Profile '${PROFILE}' not found for ${TARGET_FAMILY}/${SUBTARGET}"
#  echo "   👉 先執行 'make info' 查詢正確名稱"
#  exit 1
#fi

make image PROFILE="${PROFILE}" \
     PACKAGES="${PACKAGES:-$DEFAULT_PKGS}" \
     FILES="../files" \
     BIN_DIR="../${OUTDIR}" \
     -j"${JOBS}"

# --- build 完成後，把 sysupgrade 檔搬上來 ---
cd ..   # 回到專案根 (與 output 同層)
# 把 sysupgrade 映像複製到 output/（其實原本就已經在那裡，但保留 find 可同時支援多 profile）
find output -maxdepth 1 -name '*rpi-3*-sysupgrade.img*' -exec echo "✅ Found {}" \;
# find output/targets -name '*rpi-3*-sysupgrade.img*' -exec cp {} output/ \;
echo "✅ Firmware copied to output/ :"
ls -1 output

echo -e "\n🎉 Image(s) ready in ${OUTDIR}\n"
