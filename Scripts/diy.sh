#!/bin/bash
# ========================================================
# 2025.11.26 终极稳定版 diy.sh —— libnl-tiny 暴力修复 + 原功能完整保留
# ========================================================

set -e

echo "开始执行 diy.sh（2025.11.26 libnl-tiny 修复版）"

# ===================== 1. 拉取第三方包函数 =====================
UPDATE_PACKAGE() {
    local PKG_NAME="$1" PKG_REPO="$2" PKG_BRANCH="$3" PKG_SPECIAL="$4"
    read -ra NAMES <<< "$PKG_NAME"

    for NAME in "${NAMES[@]}"; do
        find feeds/luci/ feeds/packages/ package/ -maxdepth 3 -type d \
            \( -name "$NAME" -o -name "luci-*-$NAME" \) -exec rm -rf {} + 2>/dev/null || true
    done

    if [[ $PKG_REPO == http* ]]; then
        REPO_NAME=$(basename "$PKG_REPO" .git)
    else
        REPO_NAME=$(echo "$PKG_REPO" | cut -d '/' -f 2)
        PKG_REPO="https://github.com/$PKG_REPO.git"
    fi

    git clone --depth=1 --branch "$PKG_BRANCH" "$PKG_REPO" "package/$REPO_NAME" || exit 1

    case "$PKG_SPECIAL" in
        "pkg")
            for NAME in "${NAMES[@]}"; do
                find "package/$REPO_NAME" -maxdepth 3 -type d \
                    \( -name "$NAME" -o -name "luci-*-$NAME" \) -print0 |
                    xargs -0 -I {} cp -rf {} ./package/ 2>/dev/null || true
            done
            rm -rf "package/$REPO_NAME"
            ;;
        "name")
            rm -rf "package/$PKG_NAME"
            mv "package/$REPO_NAME" "package/$PKG_NAME"
            ;;
    esac
}

echo "正在拉取第三方包..."
UPDATE_PACKAGE "luci-app-poweroff"        "esirplayground/luci-app-poweroff" "main"
UPDATE_PACKAGE "luci-app-tailscale"       "asvow/luci-app-tailscale"        "main"
UPDATE_PACKAGE "openwrt-gecoosac"         "lwb1978/openwrt-gecoosac"        "main"
UPDATE_PACKAGE "luci-app-openlist2"       "sbwml/luci-app-openlist2"        "main"
UPDATE_PACKAGE "xray-core xray-plugin dns2tcp dns2socks haproxy hysteria naiveproxy v2ray-core v2ray-geodata v2ray-geoview v2ray-plugin tuic-client chinadns-ng ipt2socks tcping trojan-plus simple-obfs shadowsocksr-libev luci-app-passwall smartdns luci-app-smartdns v2dat mosdns luci-app-mosdns taskd luci-lib-xterm luci-lib-taskd luci-app-ssr-plus luci-app-passwall2 luci-app-store quickstart luci-app-quickstart luci-app-istorex luci-app-cloudflarespeedtest luci-theme-argon netdata luci-app-netdata lucky luci-app-lucky luci-app-openclash mihomo luci-app-dockerman docker-lan-bridge docker dockerd luci-app-nikki frp luci-app-ddns-go ddns-go" "kenzok8/small-package" "main" "pkg"
UPDATE_PACKAGE "luci-app-netspeedtest speedtest-cli" "https://github.com/sbwml/openwrt_pkgs.git" "main" "pkg"
UPDATE_PACKAGE "luci-app-adguardhome"     "https://github.com/ysuolmai/luci-app-adguardhome.git" "apk"
UPDATE_PACKAGE "openwrt-podman"           "https://github.com/breeze303/openwrt-podman" "main"
UPDATE_PACKAGE "luci-app-quickfile"       "https://github.com/sbwml/luci-app-quickfile" "main"

# quickfile 修复
sed -i 's|$(INSTALL_BIN) $(PKG_BUILD_DIR)/quickfile-$(ARCH_PACKAGES).*|$(INSTALL_BIN) $(PKG_BUILD_DIR)/quickfile-aarch64_generic $(1)/usr/bin/quickfile|' package/luci-app-quickfile/quickfile/Makefile 2>/dev/null || true


# ===================== 2. 关键修复 =====================
echo "执行关键修复..."

# libdeflate
sed -i 's/PKG_HASH:=.*/PKG_HASH:=fed5cd22f00f30cc4c2e5329f94e2b8a901df9fa45ee255cb70e2b0b42344477/g' tools/libdeflate/Makefile


# ===================== ★★★ libnl-tiny 官方版覆盖 + 正确 URL ★★★ =====================
echo "覆盖 package/libs/libnl-tiny/Makefile 为 OpenWrt 24.10 官方版本..."

cat > package/libs/libnl-tiny/Makefile << 'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=libnl-tiny
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://git.openwrt.org/project/libnl-tiny.git
PKG_SOURCE_DATE:=2025-03-19
PKG_SOURCE_VERSION:=c0df580adbd4d555ecc1962dbe88e91d75b67a4e
PKG_MIRROR_HASH:=1064a27824d99a93cbf8dbc808caf2cb277f1825b378ec6076d2ecfb8866a81f

PKG_MAINTAINER:=Felix Fietkau <nbd@nbd.name>
PKG_LICENSE:=LGPL-2.1
PKG_LICENSE_FILES:=COPYING

include $(BUILD_DIR)/package.mk

define Package/libnl-tiny
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=Small version of libnl
endef

define Package/libnl-tiny/description
This package contains a stripped down version of libnl
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CC="$(TARGET_CC)" \
		CPPFLAGS="$(TARGET_CPPFLAGS)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)"
endef

define Package/libnl-tiny/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_BUILD_DIR)/libnl-tiny.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libnl-tiny))
EOF

echo "libnl-tiny Makefile 已重置为官方版本（URL 已修正）"


# 全局版本号修复（你原有逻辑）
find . \( -name "*.mk" -o -name "Makefile" \) -type f -exec sed -i 's/~/./g' {} + 2>/dev/null


# kernel 修复
[ -f package/kernel/linux/Makefile ] && {
    sed -i '/PKG_VERSION:=/c\PKG_VERSION:=$(LINUX_VERSION)' package/kernel/linux/Makefile
    sed -i '/PKG_RELEASE:=/d' package/kernel/linux/Makefile
    echo "PKG_RELEASE:=1" >> package/kernel/linux/Makefile
}

find include/ -name "kernel*.mk" -type f -exec sed -i -E \
    's/([0-9]+\.[0-9]+\.[0-9]+)(\.[0-9]+)?(_[a-f0-9]+|-[a-f0-9]+)*/\1-r1/g' {} +


# rust 修复
find feeds/packages/lang/rust -name Makefile -exec sed -i 's/ci-llvm=true/ci-llvm=false/g' {} \;


# ===================== 3. 个性化设置 =====================
echo "写入个性化设置..."

sed -i "s/192\.168\.[0-9]*\.[0-9]*/192.168.1.1/g" \
    $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js") \
    package/base-files/files/bin/config_generate 2>/dev/null || true

sed -i "s/hostname='.*'/hostname='FWRT'/g" package/base-files/files/bin/config_generate

find ./ -name "cascade.css" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;
find ./ -name "dark.css"    -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;

cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-zerotier=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_luci-app-poweroff=y
CONFIG_PACKAGE_luci-app-cpufreq=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-app-homeproxy=y
CONFIG_PACKAGE_luci-app-ddns-go=y
CONFIG_PACKAGE_luci-app-netspeedtest=y
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_luci-app-gecoosac=y
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_luci-app-dockerman=y
CONFIG_PACKAGE_luci-app-openlist2=y
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-app-frpc=y
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_openssh-sftp-server=y
CONFIG_PACKAGE_luci-app-filetransfer=y
CONFIG_PACKAGE_nano=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_coremark=y
CONFIG_COREMARK_OPTIMIZE_O3=y
CONFIG_COREMARK_ENABLE_MULTITHREADING=y
CONFIG_COREMARK_NUMBER_OF_THREADS=6
EOF

install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_ttyd-nopass.sh"     \
    "package/base-files/files/etc/uci-defaults/99_ttyd-nopass" 2>/dev/null || true

install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_set_argon_primary" \
    "package/base-files/files/etc/uci-defaults/99_set_argon_primary" 2>/dev/null || true

install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_dropbear_setup.sh" \
    "package/base-files/files/etc/uci-defaults/99_dropbear_setup" 2>/dev/null || true

echo "diy.sh 执行完毕！你现在可以放心 make 了。"
#######################################
# Fix PPP / UPnP issues
#######################################
mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-custom-fixes
#!/bin/sh
sed -i '8c maxfail 1' /etc/ppp/options
sed -i '192c sleep 30' /lib/netifd/proto/ppp.sh
sed -i '10c option external_ip "59.111.160.244"' /etc/config/upnpd
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-custom-fixes
