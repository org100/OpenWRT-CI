#!/bin/bash

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	

	rm -rf $(find feeds/luci/ feeds/packages/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune)

	if [[ $PKG_REPO == http* ]]; then
	        git clone --depth=1 --single-branch --branch $PKG_BRANCH "$PKG_REPO" package/$PKG_NAME
	        local REPO_NAME=$(echo $PKG_REPO | awk -F '/' '{gsub(/\.git$/, "", $NF); print $NF}')
	else
	        git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git" package/$PKG_NAME
	        local REPO_NAME=$(echo $PKG_REPO | cut -d '/' -f 2)
	fi
 
	if [[ $PKG_SPECIAL == "pkg" ]]; then
		cp -rf $(find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune) ./
		rm -rf ./$REPO_NAME/
	elif [[ $PKG_SPECIAL == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

UPDATE_PACKAGE "luci-app-adguardhome" "ysuolmai/luci-app-adguardhome" "apk"
UPDATE_PACKAGE "luci-app-poweroff" "esirplayground/luci-app-poweroff" "master"
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"
UPDATE_PACKAGE "openwrt-gecoosac" "lwb1978/openwrt-gecoosac" "main"
UPDATE_PACKAGE "luci-app-lucky" "gdy666/luci-app-lucky" "main"
UPDATE_PACKAGE "luci-app-homeproxy" "immortalwrt/homeproxy" "master"
UPDATE_PACKAGE "luci-app-ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "luci-app-alist" "sbwml/luci-app-alist" "main"


rm -rf $(find feeds/luci/ feeds/packages/ -maxdepth 3 -type d -iname luci-app-diskman -prune)
rm -rf $(find feeds/luci/ feeds/packages/ -maxdepth 3 -type d -iname parted -prune)
mkdir -p luci-app-diskman && \
wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/applications/luci-app-diskman/Makefile -O luci-app-diskman/Makefile
mkdir -p parted && \
wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/Parted.Makefile -O parted/Makefile




#######################################
#DIY
#######################################
WRT_IP="192.168.1.1"
WRT_NAME="FWRT"
WRT_WIFI="FWRT"
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#修改默认WIFI名
sed -i "s/\.ssid=.*/\.ssid=$WRT_WIFI/g" $(find ./package/kernel/mac80211/ ./package/network/config/ -type f -name "mac80211.*")

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
sudo -E apt-get -y install $(curl -fsSL is.gd/depends_ubuntu_2204)

keywords_to_delete=(
        "abt_asr3000" "cmcc_a10" "xiaomi_ax1800" "glinet" "h3c_magic-nx30-pro" "jdcloud_re-cp-03" "konka_komi-a31" "netcore_n60" "zyxel_ex5700-telenor" "cmiot_ax18"
        "nokia_ea0326gmp" "qihoo_360t7" "xiaomi_ax1800" "ruijie_rg-x60-pro" "tplink" "xiaomi_mi-router-ax3000t" "xiaomi_mi-router-wr30u" "xiaomi_redmi-router-ax6000"
        "abt_asr3000" "qihoo_360v6" "redmi_ax5" "redmi_ax5-jdcloud" "zn_m2" "cmcc_rm2-6""redmi_ax6-stock" "redmi_ax6" "xiaomi_ax3600-stock" "xiaomi_ax3600" "xiaomi_ax9000"
        "cetron_ct3003" "imou_lc-hx3001" "jcg_q30-pro" "cmcc_rm2-6" "aliyun_ap8220" "linksys_mr7350" "cudy_tr3000-v1" "uugamebooster" "luci-app-wol" "luci-i18n-wol-zh-cn" 
        "CONFIG_TARGET_INITRAMFS" "ddns" "tailscale" "luci-app-advancedplus" "mihomo"
)

[[ $WRT_TARGET == *"WIFI-NO"* ]] && keywords_to_delete+=("wpad" "hostapd")
[[ $WRT_TARGET != *"EMMC"* ]] && keywords_to_delete+=()
[[ $WRT_TARGET == *"EMMC"* ]] && keywords_to_delete+=()

for keyword in "${keywords_to_delete[@]}"; do
    sed -i "/$keyword/d" ./.config
done

# Configuration lines to append to .config
provided_config_lines=(
    "CONFIG_PACKAGE_luci-app-cpufreq=y"
    "CONFIG_PACKAGE_luci-app-ttyd=y"
    "CONFIG_PACKAGE_luci-app-homeproxy=y"
    "CONFIG_PACKAGE_luci-app-alist=y"
    "CONFIG_PACKAGE_luci-app-mosdns=y"
    "CONFIG_PACKAGE_luci-app-lucky=y"
    "CONFIG_PACKAGE_luci-app-upnp=y"
    "CONFIG_PACKAGE_luci-app-aria2=y"
    "CONFIG_PACKAGE_luci-app-wolplus=y"
    "CONFIG_PACKAGE_luci-app-samba4=y"
    "CONFIG_PACKAGE_luci-app-hd-idle=y"
    "CONFIG_PACKAGE_kmod-fs-f2fs=y"
    "CONFIG_PACKAGE_kmod-fs-ntfs3=y"
    "CONFIG_PACKAGE_kmod-fs-vfat=y"
    "CONFIG_PACKAGE_kmod-fs-xfs=y"
    "CONFIG_PACKAGE_kmod-fs-exportfs=y"
    "CONFIG_PACKAGE_kmod-phy-aquantia=y"
    "CONFIG_PACKAGE_kmod-nf-nathelper=y"
    "CONFIG_PACKAGE_kmod-nf-nathelper-extra=y"
    "CONFIG_PACKAGE_kmod-nft-fib=y"
    "CONFIG_PACKAGE_kmod-nft-fullcone=y"
    "CONFIG_PACKAGE_kmod-nft-socket=y"
    "CONFIG_PACKAGE_kmod-nls-cp437=y"
    "CONFIG_PACKAGE_kmod-nls-iso8859-1=y"
    "CONFIG_PACKAGE_kmod-nls-utf8=y"
    "CONFIG_PACKAGE_kmod-scsi-core=y"
    "CONFIG_PACKAGE_kmod-crypto-crc32=y"
    "CONFIG_PACKAGE_kmod-crypto-acompress=y"
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
    "CONFIG_PACKAGE_luci-app-dockerman=y"
    "CONFIG_PACKAGE_fdisk=y"
    "CONFIG_PACKAGE_parted=y"
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

find ./ -name "getifaddr.c" -exec sed -i 's/return 1;/return 0;/g' {} \;
#find ./ -type d -name 'luci-app-ddns-go' -exec sh -c '[ -f "$1/Makefile" ] && sed -i "/config\/ddns-go/d" "$1/Makefile"' _ {} \;
#find ./ -type d -name "luci-app-ddns-go" -exec sh -c 'f="{}/Makefile"; [ -f "$f" ] && echo "\ndefine Package/\$(PKG_NAME)/install\n\trm -f \$(1)/etc/config/ddns-go\n\t\$(call InstallDev,\$(1))\nendef\n" >> "$f"' \;
#find ./ -type d -name "ddns-go" -exec sh -c 'f="{}/Makefile"; [ -f "$f" ] && sed -i "/\$(INSTALL_BIN).*\/ddns-go.init.*\/etc\/init.d\/ddns-go/d" "$f"' \;
rm -rf ./feeds/packages/net/ddns-go;

# 修复拨号问题
echo "sed -i '8c maxfail 1' /etc/ppp/options" >> package/base-files/files/lib/functions/uci-defaults.sh
echo "sed -i '192c sleep 30' /lib/netifd/proto/ppp.sh" >> package/base-files/files/lib/functions/uci-defaults.sh
# 修复upnp问题
echo "sed -i '10c option external_ip \"59.111.160.244\"' /etc/config/upnpd" >> package/base-files/files/lib/functions/uci-defaults.sh
