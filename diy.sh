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
#sed -i 's/OpenWrt/OpenWrting/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh


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


# create /opt
sed -i "/\/usr\/bin\/ip/a mkdir \/opt" package/lean/default-settings/files/zzz-default-settings


# Modify app list
sed -i 's/"vpn"/"services"/g; s/VPN/Services/g' package/feeds/luci/luci-app-ipsec-server/luasrc/controller/ipsec-server.lua    # `grep "IPSec VPN Server" -rl ./`
sed -i 's/"vpn"/"services"/g; s/VPN/Services/g' package/feeds/ing/luci-app-zerotier/luasrc/controller/zerotier.lua    # `grep "ZeroTier" -rl ./`


# Modify app name
sed -i 's/"挂载 SMB 网络共享"/"挂载 SMB"/g' package/feeds/luci/luci-app-cifs-mount/po/zh-cn/cifs.po    # `grep "挂载 SMB 网络共享" -rl ./`
sed -i 's/"Turbo ACC 网络加速"/"Turbo ACC"/g' package/feeds/luci/luci-app-turboacc/po/zh-cn/turboacc.po    # `grep "Turbo ACC 网络加速" -rl ./`
sed -i 's/\"Argon 主题设置\"/\"主题设置\"/g' package/feeds/ing/luci-app-argon-config/po/zh-cn/argon-config.po    # `grep "Argon 主题设置" -rl ./`


# build po2lmo
if [ -d "feeds/ing/luci-app-openclash/tools/po2lmo" ]; then
    pushd feeds/ing/luci-app-openclash/tools/po2lmo
    make && sudo make install
    popd
fi