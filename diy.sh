

# 卸载 luci/themes/luci-theme-argon 旧版本
#./scripts/feeds uninstall luci-theme-argon
# 卸载 luci/luci-app-netdata 旧版本
#./scripts/feeds uninstall luci-app-netdata
# 安装新版本
#./scripts/feeds install -a -f -p ing

# 修改默认管理地址
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
