# OpenWrt Mesh Image Builder for Raspberry Pi 3B *(OpenWrt 23.05)*

This repository lets you **re‑build a fully‑configured OpenWrt image for Raspberry Pi 3 Model B**.  It already includes:

* 802.11s + batman‑adv mesh (WPA3‑SAE)
* Dynamic gateway switching hot‑plug script
* Avahi/mDNS preset (xxxx.local)
* Optional USB‑Wi‑Fi AP for client onboarding

---

## Quick start (local build)

```bash
sudo apt update && sudo apt install build-essential libncurses5-dev zlib1g-dev gawk git ccache gettext libssl-dev xsltproc wget python3 rsync unzip file

git clone https://github.com/<your‑account>/openwrt-mesh-config.git
cd openwrt-mesh-config
chmod +x build.sh            # ensure executable
./build.sh                   # downloads OpenWrt, applies .config + files/, compiles image
```

A successful build produces **`openwrt/bin/targets/bcm27xx/bcm2709/rpi‑3‑squashfs‑sysupgrade.img.gz`** (≈ 25 MB).

---

## Directory layout

```
openwrt-mesh-config/
├── README.md
├── build.sh            # one‑click build helper
├── feeds.conf          # optional – extra feeds (kept default here)
├── .config             # diffconfig for Pi 3B + packages
├── .github/
│   └── workflows/
│       └── build.yml   # GitHub Actions CI
└── files/              # rootfs overlay copied into final image
    └── etc/
        ├── config/
        │   ├── network
        │   ├── wireless
        │   └── system
        └── hotplug.d/
            └── iface/
                └── 50-gateway
```

---

## build.sh  (local helper)

```bash
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
```

---

## GitHub Actions CI (`.github/workflows/build.yml`)

```yaml
name: Build OpenWrt Mesh Image

on:
  workflow_dispatch:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-22.04
    steps:
    - name: Checkout repo
      uses: actions/checkout@v4

    - name: Prepare build environment
      run: |
        sudo apt-get update
        sudo apt-get install -y build-essential libncurses5-dev zlib1g-dev gawk \
          git ccache gettext libssl-dev xsltproc wget python3 rsync unzip file

    - name: Cache OpenWrt downloads
      uses: actions/cache@v4
      with:
        path: openwrt/dl
        key: openwrt-dl-${{ hashFiles('.config') }}
        restore-keys: |
          openwrt-dl-

    - name: Run build script
      run: |
        chmod +x build.sh
        ./build.sh

    - name: Upload image artifact
      uses: actions/upload-artifact@v4
      with:
        name: openwrt-mesh-image
        path: output/*rpi-3*-sysupgrade.img*
```

*The workflow caches downloads, runs your local `build.sh`, and publishes the resulting image as an artifact on every push or manual trigger.*  Expand with a **matrix strategy** if you want multiple node variants (e.g. `hostname`/`ipaddr` changes).

---

## .config (diffconfig)

> Adjust `CONFIG_KERNEL_PARTSIZE` / packages as needed, run `make defconfig`, commit updated output.

```config
CONFIG_TARGET_bcm27xx=y
CONFIG_TARGET_bcm27xx_bcm2709=y
CONFIG_TARGET_DEVICE_bcm27xx_bcm2709_DEVICE_rpi-3=y

# ---- Mesh / Wi‑Fi ----
CONFIG_PACKAGE_wpad-mesh-openssl=y
CONFIG_PACKAGE_kmod-batman-adv=y
CONFIG_PACKAGE_batctl=y
CONFIG_PACKAGE_luci-app-batman-adv=y
CONFIG_PACKAGE_luci-proto-batman-adv=y

# ---- mDNS ----
CONFIG_PACKAGE_avahi-daemon=y
CONFIG_PACKAGE_avahi-utils=y

# ---- USB Wi‑Fi AP ----
CONFIG_PACKAGE_usbutils=y

# ---- LuCI base ----
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-ssl-openssl=y

# ---- QoL ----
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_nano=y
CONFIG_PACKAGE_tcpdump=y
```

---

## Configuration overlay (`files/…`)

The following UCI snippets are pre‑loaded into the image.  Edit before each build if you need per‑node customisation.

### files/etc/config/network

```uci
# batman-adv
config interface 'bat0'
        option proto        'batadv'
        option routing_algo 'BATMAN_V'
        option gw_mode      'client'
        option multicast_mode '1'

# 802.11s hard‑if
config interface 'mesh_wifi'
        option ifname       'mesh0'
        option proto        'batadv_hardif'
        option master       'bat0'

# LAN
config interface 'lan'
        option device       'bat0'
        option proto        'static'
        option ipaddr       '10.10.10.10'   # change per‑node
        option netmask      '255.255.255.0'

# WAN (only on nodes with Ethernet uplink)
config interface 'wan'
        option device       'eth0'
        option proto        'dhcp'
```

### files/etc/config/wireless

```uci
config wifi-device 'radio0'
        option type     'mac80211'
        option channel  '6'
        option htmode   'HT20'

config wifi-iface 'mesh0'
        option device   'radio0'
        option mode     'mesh'
        option mesh_id  'OpenMesh'
        option encryption 'sae'
        option key      'MeshPass'
        option network  'mesh_wifi'

# Optional USB‑Wi‑Fi AP (radio1)
config wifi-device 'radio1'
        option type     'mac80211'
        option channel  '11'
        option htmode   'HT20'

config wifi-iface 'ap'
        option device   'radio1'
        option mode     'ap'
        option ssid     'MeshAP'
        option encryption 'psk2'
        option key      'ClientPass'
        option network  'lan'
```

### files/etc/config/system

```uci
config system
        option hostname 'meshpi'
        option zonename 'Asia/Taipei'
        option timezone 'CST-8'
```

### files/hotplug.d/iface/50-gateway

```sh
#!/bin/sh
[ "$INTERFACE" = "wan" ] || exit 0

if [ "$ACTION" = "ifup" ]; then
    batctl meshif bat0 gw_mode server 100MBit/20MBit
    /etc/init.d/dnsmasq restart
else
    batctl meshif bat0 gw_mode off
    /etc/init.d/dnsmasq stop
fi
```

---

### Build images for multiple nodes

Create **branches or tags** (`node-a`, `node-b`…) containing per‑node overlay tweaks, or adopt a **matrix** in GitHub Actions like:

```yaml
strategy:
  matrix:
    hostname: [meshpi-a, meshpi-b, meshpi-c]
```

Then patch the overlay on‑the‑fly before running `build.sh`.

---

## License

MIT — plus original OpenWrt packages under GPL‑2.0.  See [https://openwrt.org/](https://openwrt.org/) for full license details.

---

> 📝 Fork freely, tweak packages, kernel modules, or CI workflow, and enjoy your automated mesh image builds!
