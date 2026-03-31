#!/usr/bin/env bash
#
# Copyright (C) 2022 Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/wjz304/OpenWrt_Build
# File name: diy.sh
# Description: OpenWrt DIY script
#

set -euo pipefail
shopt -s nullglob

repo="${1:-openwrt}"
owner="${2:-Ing}"
arch="${3:-}"

log() {
  echo "[diy] $*"
}

require_file() {
  local file="$1"
  [ -f "${file}" ] || {
    echo "[diy] Missing file: ${file}" >&2
    exit 1
  }
}

copy_patch_dir() {
  local src_dir="$1"
  local dst_dir="$2"
  local patch_files=("${src_dir}"/*.patch)

  [ "${#patch_files[@]}" -gt 0 ] || return 0

  mkdir -p "${dst_dir}"
  cp -f "${patch_files[@]}" "${dst_dir}/"
}

apply_sed() {
  local expr="$1"
  shift

  local pattern file
  for pattern in "$@"; do
    for file in ${pattern}; do
      [ -e "${file}" ] || continue
      sed -i "${expr}" "${file}"
    done
  done
}

set_config_value() {
  local key="$1"
  local value="$2"

  if grep -q "^${key}=" .config 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${value}|" .config
  else
    echo "${key}=${value}" >> .config
  fi
}

write_banner() {
  local banner_file="package/base-files/files/etc/banner"

  mkdir -p "$(dirname "${banner_file}")"

  if [ "${owner}" = "Ing" ] && [ "${repo}" = "openwrt" ]; then
    cat >"${banner_file}" <<EOF
  _______                     ________        __
 |       |.-----.-----.-----.|  |  |  |.----.|  |_
 |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
 |_______||   __|_____|__|__||________||__|  |____|
          |__|                   OpenWrt By ${owner}
 -----------------------------------------------------
 %D %V, %C
 -----------------------------------------------------

EOF
    return
  fi

  if [ "${owner}" = "Ing" ] && [ "${repo}" = "lede" ]; then
    cat >"${banner_file}" <<EOF
     _________
    /        /\\      _    ___ ___  ___
   /  LE    /  \\    | |  | __|   \\| __|
  /    DE  /    \\   | |__| _|| |) | _|
 /________/  LE  \\  |____|___|___/|___|        LEDE By ${owner}
 \\        \\   DE /
  \\    LE  \\    /  -------------------------------------------
   \\  DE    \\  /    %D %V, %C
    \\________\\/    -------------------------------------------

EOF
    return
  fi

  cat >"${banner_file}" <<EOF
  ___                  _       _   ____            ${owner}
 / _ \ _ __   ___ _ __| |_    | | | __ ) _   _    ${repo}
| | | | '_ \ / _ \ '__| __|   | | |  _ \| | | |
| |_| | |_) |  __/ |  | |_    | | | |_) | |_| |
 \___/| .__/ \___|_|   \__|   |_| |____/ \__, |
      |_|                                 |___/
 -----------------------------------------------------
 %D %V, %C
 -----------------------------------------------------

EOF
}

write_nat_loopback_defaults() {
  local defaults_dir="package/base-files/files/etc/uci-defaults"
  mkdir -p "${defaults_dir}"

  cat >"${defaults_dir}/99-nat-loopback" <<'EOF'
#!/bin/sh

changed=0
need_reload=0

for opt in flow_offloading flow_offloading_hw fullcone fullcone6; do
  if [ "$(uci -q get firewall.@defaults[0].${opt})" = "1" ]; then
    uci -q set firewall.@defaults[0].${opt}='0'
    changed=1
  fi
done

for section in $(uci -q show firewall | sed -n 's/^\(firewall\.@redirect\[[0-9]\+\]\)\..*/\1/p' | sort -u); do
  [ "$(uci -q get ${section}.enabled)" = "0" ] && continue
  [ "$(uci -q get ${section}.target)" = "SNAT" ] && continue

  if [ "$(uci -q get ${section}.reflection)" != "1" ]; then
    uci -q set ${section}.reflection='1'
    changed=1
  fi

  if [ -z "$(uci -q get ${section}.reflection_src)" ]; then
    uci -q set ${section}.reflection_src='internal'
    changed=1
  fi

  if [ -z "$(uci -q get ${section}.reflection_zone)" ]; then
    dest_zone="$(uci -q get ${section}.dest)"
    if [ -n "${dest_zone}" ]; then
      uci -q set ${section}.reflection_zone="${dest_zone}"
      changed=1
    fi
  fi
done

if [ "${changed}" = "1" ]; then
  uci -q commit firewall
  need_reload=1
fi

if [ "${need_reload}" = "1" ] && [ -x /etc/init.d/firewall ]; then
  /etc/init.d/firewall reload >/dev/null 2>&1 || /etc/init.d/firewall restart >/dev/null 2>&1
fi

exit 0
EOF

  chmod +x "${defaults_dir}/99-nat-loopback"
}

resolve_defaultsettings() {
  if [ "${repo}" = "openwrt" ]; then
    echo "feeds/ing/default-settings"
  else
    echo "package/lean/default-settings"
  fi
}

log "OpenWrt DIY script"
log "repo: ${repo}; owner: ${owner}; arch: ${arch:-unknown}"

require_file "package/base-files/files/bin/config_generate"
require_file ".config"

defaultsettings="$(resolve_defaultsettings)"
if [ ! -d "${defaultsettings}" ]; then
  echo "[diy] default-settings not found: ${defaultsettings}" >&2
  exit 1
fi

default_settings_file="${defaultsettings}/files/zzz-default-settings"
sysctl_file="package/base-files/files/etc/sysctl.conf"

require_file "${default_settings_file}"
require_file "${sysctl_file}"

# Modify default IP
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

# Banner
write_banner

# Modify version string
sed -i "s/OpenWrt /${owner} build $(TZ=UTC-8 date '+%Y.%m.%d') @ OpenWrt /g" "${default_settings_file}"
sed -i "s/LEDE /${owner} build $(TZ=UTC-8 date '+%Y.%m.%d') @ LEDE /g" "${default_settings_file}"

# Remove openwrt_ing feed entry from runtime distfeeds config
if ! grep -q 'openwrt_ing\\/d' "${default_settings_file}"; then
  sed -i '/sed -i "s\/# \/\/g" \/etc\/opkg\/distfeeds.conf/a\sed -i "\/openwrt_ing\/d" \/etc\/opkg\/distfeeds.conf' "${default_settings_file}"
fi

# Increase maximum tracked connections
if ! grep -q '^net.netfilter.nf_conntrack_max=165535$' "${sysctl_file}"; then
  sed -i '/customized in this file/a net.netfilter.nf_conntrack_max=165535' "${sysctl_file}"
fi

# Keep NAT loopback stable on LEDE firewall defaults
write_nat_loopback_defaults

# Modify default theme
deftheme="argon"
case "${owner}" in
  Leeson) deftheme="bootstrap" ;;
  Lyc) deftheme="pink" ;;
esac
log "deftheme: ${deftheme}"
apply_sed "s/bootstrap/${deftheme}/g" \
  "feeds/luci/collections/luci/Makefile" \
  "feeds/luci/modules/luci-base/root/etc/config/luci"

# Add kernel build metadata
set_config_value "CONFIG_KERNEL_BUILD_USER" "\"${owner}\""
set_config_value "CONFIG_KERNEL_BUILD_DOMAIN" "\"GitHub Actions\""

# Adjust app menu text when those packages are present
apply_sed 's|admin/vpn/|admin/services/|g' \
  "package/feeds/luci/luci-app-ipsec-vpnd/root/usr/share/luci/menu.d/luci-app-ipsec-vpnd.json"
apply_sed 's|"admin", "vpn"|"admin", "services"|g' \
  "package/feeds/ing/luci-app-easytier/luasrc/controller/easytier.lua"
apply_sed 's/"vpn"/"services"/g; s/"VPN"/"Services"/g' \
  "package/feeds/ing/luci-app-zerotier/luasrc/controller/zerotier.lua"
apply_sed 's/"Argon 主题设置"/"主题设置"/g' \
  "package/feeds/ing/luci-app-argon-config/po/*/argon-config.po"

log "DIY customization complete"
