#!/bin/bash

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4

	# 清理旧的包
	read -ra PKG_NAMES <<< "$PKG_NAME"  # 将PKG_NAME按空格分割成数组
	for NAME in "${PKG_NAMES[@]}"; do
		rm -rf $(find feeds/luci/ feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" -prune)
	done

	# 克隆仓库
	if [[ $PKG_REPO == http* ]]; then
		local REPO_NAME=$(echo $PKG_REPO | awk -F '/' '{gsub(/\.git$/, "", $NF); print $NF}')
		git clone --depth=1 --single-branch --branch $PKG_BRANCH "$PKG_REPO" package/$REPO_NAME
	else
		local REPO_NAME=$(echo $PKG_REPO | cut -d '/' -f 2)
		git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git" package/$REPO_NAME
	fi

	# 根据 PKG_SPECIAL 处理包
	case "$PKG_SPECIAL" in
		"pkg")
			# 提取每个包
			for NAME in "${PKG_NAMES[@]}"; do
				cp -rf $(find ./package/$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$NAME*" -prune) ./package/
			done
			# 删除剩余的包
			rm -rf ./package/$REPO_NAME/
			;;
		"name")
			# 重命名包
			mv -f ./package/$REPO_NAME ./package/$PKG_NAME
			;;
	esac
}

UPDATE_PACKAGE "luci-app-adguardhome" "ysuolmai/luci-app-adguardhome" "apk"
UPDATE_PACKAGE "luci-app-poweroff" "esirplayground/luci-app-poweroff" "master"
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"
UPDATE_PACKAGE "openwrt-gecoosac" "lwb1978/openwrt-gecoosac" "main"
UPDATE_PACKAGE "luci-app-homeproxy" "immortalwrt/homeproxy" "master"
UPDATE_PACKAGE "luci-app-ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "luci-app-alist" "sbwml/luci-app-alist" "main"

#small-package
UPDATE_PACKAGE "xray-core xray-plugin dns2tcp dns2socks haproxy hysteria \
        naiveproxy shadowsocks-rust v2ray-core v2ray-geodata v2ray-geoview v2ray-plugin \
        tuic-client chinadns-ng ipt2socks tcping trojan-plus simple-obfs shadowsocksr-libev \
        luci-app-passwall smartdns luci-app-smartdns v2dat mosdns luci-app-mosdns \
        taskd luci-lib-xterm luci-lib-taskd vlmcsd luci-app-vlmcsd\
        luci-app-store quickstart luci-app-quickstart luci-app-istorex luci-app-cloudflarespeedtest \
        luci-theme-argon netdata luci-app-netdata lucky luci-app-lucky luci-app-openclash mihomo \
        luci-app-mihomo luci-app-amlogic" "kenzok8/small-package" "main" "pkg"

#speedtest
UPDATE_PACKAGE "luci-app-netspeedtest" "https://github.com/sbwml/openwrt_pkgs.git" "main" "pkg"
UPDATE_PACKAGE "speedtest-cli" "https://github.com/sbwml/openwrt_pkgs.git" "main" "pkg"



rm -rf $(find feeds/luci/ feeds/packages/ -maxdepth 3 -type d -iname luci-app-diskman -prune)
rm -rf $(find feeds/luci/ feeds/packages/ -maxdepth 3 -type d -iname parted -prune)
mkdir -p luci-app-diskman && \
wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/applications/luci-app-diskman/Makefile -O luci-app-diskman/Makefile
mkdir -p parted && \
wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/Parted.Makefile -O parted/Makefile




#######################################
#DIY Settings
#######################################
WRT_IP="192.168.1.1"
WRT_NAME="FWRT"
WRT_WIFI="FWRT"
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#修改默认WIFI名
sed -i "s/\.ssid=.*/\.ssid=$WRT_WIFI/g" $(find ./package/kernel/mac80211/ ./package/network/config/ -type f -name "mac80211.*")
CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE


if [[ $WRT_SOURCE == *"lede"* ]]; then
	echo "CONFIG_PACKAGE_luci-theme-design=y" >> ./.config
 	echo "CONFIG_PACKAGE_luci-app-design-config=y" >> ./.config
  	sed -i "/$WRT_THEME/d" ./.config
fi

#补齐依赖
sudo -E apt-get -y install $(curl -fsSL https://raw.githubusercontent.com/ophub/amlogic-s9xxx-armbian/main/compile-kernel/tools/script/ubuntu2204-make-openwrt-depends)

keywords_to_delete=(
    "abt_asr3000" "cmcc_a10" "xiaomi_ax1800" "glinet" "h3c_magic-nx30-pro" "jdcloud_re-cp-03" "konka_komi-a31" "netcore_n60" "zyxel_ex5700-telenor" "cmiot_ax18"
    "nokia_ea0326gmp" "qihoo_360t7" "xiaomi_ax1800" "ruijie_rg-x60-pro" "tplink" "xiaomi_mi-router-ax3000t" "xiaomi_mi-router-wr30u" "xiaomi_redmi-router-ax6000"
    "abt_asr3000" "qihoo_360v6" "redmi_ax5" "redmi_ax5-jdcloud" "zn_m2" "cmcc_rm2-6""redmi_ax6-stock" "redmi_ax6" "xiaomi_ax3600-stock" "xiaomi_ax3600" "xiaomi_ax9000"
    "cetron_ct3003" "imou_lc-hx3001" "jcg_q30-pro" "cmcc_rm2-6" "aliyun_ap8220" "linksys_mr7350" "cudy_tr3000-v1" "uugamebooster" "luci-app-wol" "luci-i18n-wol-zh-cn" 
    "CONFIG_TARGET_INITRAMFS" "ddns" "tailscale" "luci-app-advancedplus" "mihomo" "smartdns" "kucat" "bootstrap"
)

[[ $WRT_TARGET == *"WIFI-NO"* ]] && keywords_to_delete+=()
[[ $WRT_TARGET != *"EMMC"* ]] && keywords_to_delete+=()
[[ $WRT_TARGET == *"EMMC"* ]] && keywords_to_delete+=()

for keyword in "${keywords_to_delete[@]}"; do
    sed -i "/$keyword/d" ./.config
done

# Configuration lines to append to .config
provided_config_lines=(
    "CONFIG_PACKAGE_luci-app-poweroff=y"
    "CONFIG_PACKAGE_luci-i18n-poweroff-zh-cn=y"
    "CONFIG_PACKAGE_cpufreq=y"
    "CONFIG_PACKAGE_luci-app-cpufreq=y"
    "CONFIG_PACKAGE_luci-i18n-cpufreq-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-ttyd=y"
    "CONFIG_PACKAGE_luci-i18n-ttyd-zh-cn=y"
    "CONFIG_PACKAGE_ttyd=y"
    "CONFIG_PACKAGE_luci-app-homeproxy=y"
    "CONFIG_PACKAGE_luci-i18n-homeproxy-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-ddns-go=y"
    "CONFIG_PACKAGE_luci-i18n-ddns-go-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-lucky=y"
    "CONFIG_PACKAGE_luci-app-upnp=y"
    "CONFIG_PACKAGE_luci-app-aria2=y"
    "CONFIG_PACKAGE_luci-app-wolplus=y"
    "CONFIG_PACKAGE_luci-app-samba4=y"
    "CONFIG_PACKAGE_luci-app-hd-idle=y"
    "CONFIG_PACKAGE_luci-app-argon-config=y"
    "CONFIG_PACKAGE_nano=y"
    "CONFIG_BUSYBOX_CONFIG_LSUSB=n"
    "CONFIG_PACKAGE_luci-app-netspeedtest=y"
    "CONFIG_PACKAGE_=y"
    "CONFIG_COREMARK_OPTIMIZE_O3=y"
    "CONFIG_COREMARK_ENABLE_MULTITHREADING=y"
    "CONFIG_COREMARK_NUMBER_OF_THREADS=6"
    #"CONFIG_PACKAGE_luci-theme-design=y"
    "CONFIG_PACKAGE_luci-app-filetransfer=y"
    "CONFIG_PACKAGE_openssh-sftp-server=y"
    "CONFIG_PACKAGE_luci-app-frpc=m"
    "CONFIG_PACKAGE_luci-app-mosdns=y"
)

[[ $WRT_TARGET == *"WIFI-NO"* ]] && provided_config_lines+=("CONFIG_PACKAGE_hostapd-common=n" "CONFIG_PACKAGE_wpad-openssl=n")
if [[ $WRT_TAG == *"WIFI-NO"* ]]; then
    provided_config_lines+=(
        "CONFIG_PACKAGE_hostapd-common=n"
        "CONFIG_PACKAGE_wpad-openssl=n"
    )
#else
    #provided_config_lines+=(
    #    "CONFIG_PACKAGE_kmod-usb-net=y"
    #    "CONFIG_PACKAGE_kmod-usb-net-rndis=y"
    #    "CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y"
    #    "CONFIG_PACKAGE_usbutils=y"
    #)
fi


[[ $WRT_TARGET == *"EMMC"* ]] && provided_config_lines+=(
    "CONFIG_PACKAGE_luci-app-diskman=y"
    "CONFIG_PACKAGE_luci-i18n-diskman-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-docker=y"
    "CONFIG_PACKAGE_luci-i18n-docker-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-dockerman=y"
    "CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-alist=y"
    "CONFIG_PACKAGE_luci-i18n-alist-zh-cn=y"
    "CONFIG_PACKAGE_fdisk=y"
    "CONFIG_PACKAGE_parted=y"
    "CONFIG_PACKAGE_iptables-mod-extra=y"
    "CONFIG_PACKAGE_ip6tables-nft=y"
    "CONFIG_PACKAGE_ip6tables-mod-fullconenat=y"
    "CONFIG_PACKAGE_iptables-mod-fullconenat=y"
    "CONFIG_PACKAGE_libip4tc=y"
    "CONFIG_PACKAGE_libip6tc=y"
    "CONFIG_PACKAGE_htop=y"
    "CONFIG_PACKAGE_fuse-utils=y"
    "CONFIG_PACKAGE_tcpdump=y"
    "CONFIG_PACKAGE_sgdisk=y"
    "CONFIG_PACKAGE_openssl-util=y"
    "CONFIG_PACKAGE_resize2fs=y"
    "CONFIG_PACKAGE_qrencode=y"
    "CONFIG_PACKAGE_smartmontools-drivedb=y"
    "CONFIG_PACKAGE_usbutils=y"
    "CONFIG_PACKAGE_default-settings=y"
    "CONFIG_PACKAGE_default-settings-chn=y"
    "CONFIG_PACKAGE_iptables-mod-conntrack-extra=y"
    "CONFIG_PACKAGE_kmod-br-netfilter=y"
    "CONFIG_PACKAGE_kmod-ip6tables=y"
    "CONFIG_PACKAGE_kmod-ipt-conntrack=y"
    "CONFIG_PACKAGE_kmod-ipt-extra=y"
    "CONFIG_PACKAGE_kmod-ipt-nat=y"
    "CONFIG_PACKAGE_kmod-ipt-nat6=y"
    "CONFIG_PACKAGE_kmod-ipt-physdev=y"
    "CONFIG_PACKAGE_kmod-nf-ipt6=y"
    "CONFIG_PACKAGE_kmod-nf-ipvs=y"
    "CONFIG_PACKAGE_kmod-nf-nat6=y"
    "CONFIG_PACKAGE_kmod-dummy=y"
    "CONFIG_PACKAGE_kmod-veth=y"
    "CONFIG_PACKAGE_automount=y"
)

# Append configuration lines to .config
for line in "${provided_config_lines[@]}"; do
    echo "$line" >> .config
done


#./scripts/feeds update -a
#./scripts/feeds install -a

#find ./ -name "cascade.css" -exec sed -i 's/#5e72e4/#6fa49a/g; s/#483d8b/#6fa49a/g' {} \;
#find ./ -name "dark.css" -exec sed -i 's/#5e72e4/#6fa49a/g; s/#483d8b/#6fa49a/g' {} \;
install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_set_argon_primary" "package/base-files/files/etc/uci-defaults/99_set_argon_primary"


find ./ -name "cascade.css" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;
find ./ -name "dark.css" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;
find ./ -name "cascade.less" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;
find ./ -name "dark.less" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;

#修改ttyd为免密
install -Dm755 "${GITHUB_WORKSPACE}/Scripts/99_ttyd-nopass.sh" "package/base-files/files/etc/uci-defaults/99_ttyd-nopass"

find ./ -name "getifaddr.c" -exec sed -i 's/return 1;/return 0;/g' {} \;
#find ./ -type d -name 'luci-app-ddns-go' -exec sh -c '[ -f "$1/Makefile" ] && sed -i "/config\/ddns-go/d" "$1/Makefile"' _ {} \;
#find ./ -type d -name "luci-app-ddns-go" -exec sh -c 'f="{}/Makefile"; [ -f "$f" ] && echo "\ndefine Package/\$(PKG_NAME)/install\n\trm -f \$(1)/etc/config/ddns-go\n\t\$(call InstallDev,\$(1))\nendef\n" >> "$f"' \;
#find ./ -type d -name "ddns-go" -exec sh -c 'f="{}/Makefile"; [ -f "$f" ] && sed -i "/\$(INSTALL_BIN).*\/ddns-go.init.*\/etc\/init.d\/ddns-go/d" "$f"' \;
rm -rf ./feeds/packages/net/ddns-go;

#fix makefile for apk
if [ -f ./package/v2ray-geodata/Makefile ]; then
    sed -i 's/VER)-\$(PKG_RELEASE)/VER)-r\$(PKG_RELEASE)/g' ./package/v2ray-geodata/Makefile
fi
if [ -f ./package/luci-lib-taskd/Makefile ]; then
    sed -i 's/>=1\.0\.3-1/>=1\.0\.3-r1/g' ./package/luci-lib-taskd/Makefile
fi
if [ -f ./package/luci-app-openclash/Makefile ]; then
    sed -i 's/PKG_RELEASE:=beta/PKG_RELEASE:=1/g' ./package/luci-app-openclash/Makefile
fi
if [ -f ./package/luci-app-quickstart/Makefile ]; then
    sed -i 's/PKG_VERSION:=0\.8\.16-1/PKG_VERSION:=0\.8\.16/g' ./package/luci-app-quickstart/Makefile
    sed -i 's/PKG_RELEASE:=$/PKG_RELEASE:=1/g' ./package/luci-app-quickstart/Makefile
fi
if [ -f ./package/luci-app-store/Makefile ]; then
    sed -i 's/PKG_VERSION:=0\.1\.27-1/PKG_VERSION:=0\.1\.27/g' ./package/luci-app-store/Makefile
    sed -i 's/PKG_RELEASE:=$/PKG_RELEASE:=1/g' ./package/luci-app-store/Makefile
fi

if [ -d "package/vlmcsd" ]; then
    mkdir -p "package/vlmcsd/patches"
    cp -f "${GITHUB_WORKSPACE}/Scripts/001-fix_compile_with_ccache.patch" "package/vlmcsd/patches"
fi

# 修复拨号问题
echo "sed -i '8c maxfail 1' /etc/ppp/options" >> package/base-files/files/lib/functions/uci-defaults.sh
echo "sed -i '192c sleep 30' /lib/netifd/proto/ppp.sh" >> package/base-files/files/lib/functions/uci-defaults.sh
# 修复upnp问题
echo "sed -i '10c option external_ip \"59.111.160.244\"' /etc/config/upnpd" >> package/base-files/files/lib/functions/uci-defaults.sh
