#
#!/bin/bash
# © 2022 GitHub, Inc.
#====================================================================
# Copyright (c) 2022 Ing
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/wjz304/OpenWrt_Build
# File name: diy.sh
# Description: OpenWrt DIY script
#====================================================================



# uninstall duplicate packages
#./scripts/feeds uninstall luci-theme-argon
#./scripts/feeds uninstall luci-app-netdata
#./scripts/feeds uninstall luci-app-smartdns
#./scripts/feeds uninstall luci-app-pushbot

# install the new version in the ing source
#./scripts/feeds install -a -f -p ing


# Modify default IP
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate


# Modify password to Null
#sed -i '/CYXluq4wUazHjmCDBCqXF/d' package/lean/default-settings/files/zzz-default-settings


# Modify hostname
#sed -i 's/OpenWrt/OpenWrting/g' package/base-files/files/bin/config_generate


# Modify ssid
#sed -i 's/OpenWrt/OpenWrting/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
# Enable wifi
#sed -i 's/.disabled=1/.disabled=0/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
# Enable MU-MIMO
#sed -i 's/mu_beamformer=0/mu_beamformer=1/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh


# Modify the version number
sed -i "s/OpenWrt /Ing build $(TZ=UTC-8 date "+%Y.%m.%d") @ OpenWrt /g" package/lean/default-settings/files/zzz-default-settings


# Modify network setting
#sed -i '$i uci set network.lan.ifname="eth1 eth2 eth3"' package/lean/default-settings/files/zzz-default-settings
#sed -i '$i uci set network.wan.ifname="eth0"' package/lean/default-settings/files/zzz-default-settings
#sed -i '$i uci set network.wan.proto=pppoe' package/lean/default-settings/files/zzz-default-settings
#sed -i '$i uci set network.wan6.ifname="eth0"' package/lean/default-settings/files/zzz-default-settings
#sed -i '$i uci commit network' package/lean/default-settings/files/zzz-default-settings


# Modify default theme
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
sed -i 's/bootstrap/argon/g' feeds/luci/modules/luci-base/root/etc/config/luci


# Modify maximum connections
sed -i '/customized in this file/a net.netfilter.nf_conntrack_max=165535' package/base-files/files/etc/sysctl.conf


# Set default language
#sed -i "s/en/zh_cn/g" package/lean/default-settings/files/zzz-default-settings
#sed -i "s/en/zh_cn/g" luci/modules/luci-base/root/etc/uci-defaults/luci-base
#sed -i "s/+@LUCI_LANG_en/+@LUCI_LANG_zh-cn/g" package/lean/default-settings/Makefile


# Add kernel build user
[ -z $(grep "CONFIG_KERNEL_BUILD_USER=" .config) ] &&
    echo 'CONFIG_KERNEL_BUILD_USER="Ing"' >>.config ||
    sed -i 's@\(CONFIG_KERNEL_BUILD_USER=\).*@\1$"Ing"@' .config

# Add kernel build domain
[ -z $(grep "CONFIG_KERNEL_BUILD_DOMAIN=" .config) ] &&
    echo 'CONFIG_KERNEL_BUILD_DOMAIN="GitHub Actions"' >>.config ||
    sed -i 's@\(CONFIG_KERNEL_BUILD_DOMAIN=\).*@\1$"GitHub Actions"@' .config


# Modify kernel and rootfs size
sed -i 's/CONFIG_TARGET_KERNEL_PARTSIZE=.*$/CONFIG_TARGET_KERNEL_PARTSIZE=64/' .config
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*$/CONFIG_TARGET_ROOTFS_PARTSIZE=2048/' .config

# Modify Default PPPOE Setting
#sed -i '$i uci set network.wan.username=PPPOE_USERNAME' openwrt/package/*/*/my-default-settings/files/etc/uci-defaults/95-default-settings
#sed -i '$i uci set network.wan.password=PPPOE_PASSWD' openwrt/package/*/*/my-default-settings/files/etc/uci-defaults/95-default-settings
#sed -i '$i uci commit network' openwrt/package/*/*/my-default-settings/files/etc/uci-defaults/95-default-settings

# Modify app list
sed -i 's/"vpn"/"services"/g; s/"VPN"/"Services"/g' package/feeds/luci/luci-app-ipsec-server/luasrc/controller/ipsec-server.lua    # `grep "IPSec VPN Server" -rl ./`
sed -i 's/"vpn"/"services"/g; s/"VPN"/"Services"/g' package/feeds/luci/luci-app-ipsec-vpnd/luasrc/controller/ipsec-server.lua    # `grep "IPSec VPN Server" -rl ./`
sed -i 's/"vpn"/"services"/g; s/"VPN"/"Services"/g' package/feeds/ing/luci-app-zerotier/luasrc/controller/zerotier.lua    # `grep "ZeroTier" -rl ./`


# Modify app name
sed -i 's/"IPSec VPN 服务器"/"IPSec VPN"/g' package/feeds/luci/luci-app-ipsec-server/po/zh-cn/ipsec-server.po    # `grep "IPSec VPN 服务器" -rl ./`
sed -i 's/"IPSec VPN 服务器"/"IPSec VPN"/g' package/feeds/luci/luci-app-ipsec-vpnd/po/zh-cn/ipsec.po    # `grep "IPSec VPN 服务器" -rl ./`
sed -i 's/"挂载 SMB 网络共享"/"挂载 SMB"/g' package/feeds/luci/luci-app-cifs-mount/po/zh-cn/cifs.po    # `grep "挂载 SMB 网络共享" -rl ./`
sed -i 's/"Turbo ACC 网络加速"/"Turbo ACC"/g' package/feeds/luci/luci-app-turboacc/po/zh-cn/turboacc.po    # `grep "Turbo ACC 网络加速" -rl ./`
sed -i 's/"实时流量监测"/"监测"/g' package/feeds/luci/luci-app-wrtbwmon/po/zh-cn/wrtbwmon.po    # `grep "实时流量监测" -rl ./`
sed -i 's/"Argon 主题设置"/"主题设置"/g' package/feeds/ing/luci-app-argon-config/po/zh-cn/argon-config.po    # `grep "Argon 主题设置" -rl ./`


# build po2lmo
if [ -d "feeds/ing/luci-app-openclash/tools/po2lmo" ]; then
    pushd feeds/ing/luci-app-openclash/tools/po2lmo
    make && sudo make install
    popd
fi

# Info
# luci-app-netdata 1.33.1汉化版 导致 web升级后 报错: /usr/lib/lua/luci/dispatcher.lua:220: /etc/config/luci seems to be corrupt, unable to find section 'main'

# CONFIG_PACKAGE_luci-app-bypass_INCLUDE_Trojan-Go 
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Trojan_GO
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Trojan
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_IPT2Socks
# CONFIG_PACKAGE_trojan-go  导致 web升级后 报错: /usr/lib/lua/luci/dispatcher.lua:220: /etc/config/luci seems to be corrupt, unable to find section 'main'

# luci-app-beardropper 导致 web升级后 /etc/config/network 信息丢失