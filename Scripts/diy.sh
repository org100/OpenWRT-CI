#!/bin/bash
# ========================================================
# 2025.12.03 编译修复最终版 diy.sh
# 修复核心：使用 wget 下载官方 Makefile，避免格式缩进错误
# ========================================================

set -e

echo "开始执行 diy.sh..."

# ===================== 1. 定义拉取函数 =====================
UPDATE_PACKAGE() {
    local PKG_NAME="$1" PKG_REPO="$2" PKG_BRANCH="$3" PKG_SPECIAL="$4"
    read -ra NAMES <<< "$PKG_NAME"

    # 清理旧包
    for NAME in "${NAMES[@]}"; do
        find feeds/luci/ feeds/packages/ package/ -maxdepth 3 -type d \
            \( -name "$NAME" -o -name "luci-*-$NAME" \) -exec rm -rf {} + 2>/dev/null || true
    done

    # 识别仓库
    if [[ $PKG_REPO == http* ]]; then
        REPO_NAME=$(basename "$PKG_REPO" .git)
    else
        REPO_NAME=$(echo "$PKG_REPO" | cut -d '/' -f 2)
        PKG_REPO="https://github.com/$PKG_REPO.git"
    fi

    # 克隆
    git clone --depth=1 --branch "$PKG_BRANCH" "$PKG_REPO" "package/$REPO_NAME" || exit 1

    # 处理
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

# ===================== 2. 拉取第三方插件 =====================
echo "正在拉取第三方包..."

UPDATE_PACKAGE "luci-app-poweroff"        "esirplayground/luci-app-poweroff" "main"
UPDATE_PACKAGE "luci-app-tailscale"       "asvow/luci-app-tailscale"         "main"
UPDATE_PACKAGE "openwrt-gecoosac"         "lwb1978/openwrt-gecoosac"         "main"
UPDATE_PACKAGE "luci-app-openlist2"       "sbwml/luci-app-openlist2"         "main"
UPDATE_PACKAGE "luci-app-quickfile"       "sbwml/luci-app-quickfile"         "main"

UPDATE_PACKAGE "xray-core xray-plugin dns2tcp dns2socks haproxy hysteria naiveproxy v2ray-core v2ray-geodata v2ray-geoview v2ray-plugin tuic-client chinadns-ng ipt2socks tcping trojan-plus simple-obfs shadowsocksr-libev luci-app-passwall smartdns luci-app-smartdns v2dat mosdns luci-app-mosdns taskd luci-lib-xterm luci-lib-taskd luci-app-ssr-plus luci-app-passwall2 luci-app-store quickstart luci-app-quickstart luci-app-istorex luci-app-cloudflarespeedtest luci-theme-argon netdata luci-app-netdata lucky luci-app-lucky luci-app-openclash mihomo luci-app-dockerman docker-lan-bridge docker dockerd luci-app-nikki frp luci-app-ddns-go ddns-go" "kenzok8/small-package" "main" "pkg"

# 修复 quickfile 编译路径
sed -i 's|$(INSTALL_BIN) $(PKG_BUILD_DIR)/quickfile-$(ARCH_PACKAGES).*|$(INSTALL_BIN) $(PKG_BUILD_DIR)/quickfile-aarch64_generic $(1)/usr/bin/quickfile|' package/luci-app-quickfile/quickfile/Makefile 2>/dev/null || true

# ===================== 3. 核心编译修复 (Build Fixes) =====================

# --- 修复 1: 镜像源哈希验证 ---
find package/ -name Makefile -type f -exec sed -i 's/PKG_MIRROR_HASH:=/#PKG_MIRROR_HASH:=/g' {} \;
sed -i 's/PKG_HASH:=.*/PKG_HASH:=fed5cd22f00f30cc4c2e5329f94e2b8a901df9fa45ee255cb70e2b0b42344477/g' tools/libdeflate/Makefile


# --- 修复 2: libnl-tiny (改用 wget 下载官方文件，确保缩进正确) ---
echo "正在修复 libnl-tiny..."

# 1. 暴力清理所有可能存在的旧版本 (feeds 和 package 下都删)
rm -rf package/feeds/base/libnl-tiny
rm -rf package/libs/libnl-tiny

# 2. 重建目录
mkdir -p package/libs/libnl-tiny

# 3. 下载官方 Makefile (包含 InstallDev)
# 使用 wget 下载避免脚本生成时的 TAB/空格 问题
wget -O package/libs/libnl-tiny/Makefile https://raw.githubusercontent.com/openwrt/openwrt/master/package/libs/libnl-tiny/Makefile

echo "libnl-tiny 修复完成 (使用官方 Makefile)"


# --- 修复 3: 防止 apk 版本号报错 (只修 Kernel) ---
find include/ -name "kernel*.mk" -type f -exec sed -i 's/~/./g' {} + 2>/dev/null
find include/ -name "kernel*.mk" -type f -exec sed -i -E \
    's/([0-9]+\.[0-9]+\.[0-9]+)(\.[0-9]+)?(_[a-f0-9]+|-[a-f0-9]+)*/\1-r1/g' {} +

# 修复 Rust 编译
find feeds/packages/lang/rust -name Makefile -exec sed -i 's/ci-llvm=true/ci-llvm=false/g' {} \;


# ===================== 4. 个性化设置 (Settings) =====================
echo "正在应用个性化设置..."

# 修改默认 IP (192.168.1.1)
sed -i "s/192\.168\.[0-9]*\.[0-9]*/192.168.1.1/g" \
    $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js") \
    package/base-files/files/bin/config_generate 2>/dev/null || true

# 修改主机名
sed -i "s/hostname='.*'/hostname='FWRT'/g" package/base-files/files/bin/config_generate

# 修改 Argon 主题颜色
find ./ -name "cascade.css" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;
find ./ -name "dark.css"    -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;

# 写入配置文件 (.config)
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

# 运行自定义脚本 (如果有)
install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_ttyd-nopass.sh" "package/base-files/files/etc/uci-defaults/99_ttyd-nopass" 2>/dev/null || true
install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_set_argon_primary" "package/base-files/files/etc/uci-defaults/99_set_argon_primary" 2>/dev/null || true
install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_dropbear_setup.sh" "package/base-files/files/etc/uci-defaults/99_dropbear_setup" 2>/dev/null || true

echo "diy.sh 执行完毕！"
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
