#!/usr/bin/env bash
#
# Copyright (C) 2022 Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

set -euo pipefail
shopt -s nullglob

log() {
  echo "[build] $*"
}

die() {
  echo "[build] $*" >&2
  exit 1
}

ensure_git_identity() {
  local git_name git_email

  git_name="$(git config --get user.name || true)"
  git_email="$(git config --get user.email || true)"

  if [ -z "${git_name}" ]; then
    git config user.name "${GITHUB_ACTOR:-github-actions[bot]}"
  fi

  if [ -z "${git_email}" ]; then
    git config user.email "${GITHUB_ACTOR:-github-actions[bot]}@users.noreply.github.com"
  fi
}

usage() {
  echo "Usage: $0 <config file> [github_actions]"
}

if [ $# -lt 1 ] || [ ! -f "${1}" ]; then
  usage
  exit 1
fi

WORK_PATH="$(pwd)"

CONFIG_FILE="$(realpath "${1}")"
CONFIG_PATH="$(dirname "${CONFIG_FILE}")"
CONFIG_NAME="$(basename "${CONFIG_FILE}" .config)"
IFS=';' read -r -a CONFIG_ARRAY <<< "${CONFIG_NAME}"

SCRIPT_FILE="${CONFIG_PATH}/diy.sh"
PATCHES_PATH="${CONFIG_PATH}/patches"
GITHUB_ACTIONS="${2:-false}"

if [ ! -f "${SCRIPT_FILE}" ]; then
  die "Missing diy script: ${SCRIPT_FILE}"
fi

if [ "${#CONFIG_ARRAY[@]}" -ne 3 ]; then
  die "${CONFIG_FILE} name error! Expected: <repo>;<owner>;<name>.config"
fi

CONFIG_REPO="${CONFIG_ARRAY[0]}"
CONFIG_OWNER="${CONFIG_ARRAY[1]}"
CONFIG_ARCH="${CONFIG_ARRAY[2]}"

case "${CONFIG_REPO}" in
  openwrt)
    REPO_URL="https://github.com/openwrt/openwrt"
    REPO_BRANCH="master"
    ;;
  lede)
    REPO_URL="https://github.com/coolsnowwolf/lede"
    REPO_BRANCH="master"
    ;;
  *)
    die "${CONFIG_FILE} name error! Unsupported repo: ${CONFIG_REPO}"
    ;;
esac

prepare_repo() {
  local repo_path="${WORK_PATH}/${CONFIG_REPO}"

  if [ ! -d "${repo_path}/.git" ]; then
    log "Cloning ${CONFIG_REPO} (${REPO_BRANCH})"
    git clone --depth=1 -b "${REPO_BRANCH}" "${REPO_URL}" "${repo_path}"
    return
  fi

  log "Updating ${CONFIG_REPO}"
  git -C "${repo_path}" checkout -- . 2>/dev/null || true
  git -C "${repo_path}" pull --ff-only
}

configure_feeds() {
  log "Configuring feeds"
  sed -i "/src-git ing /d; 1 i src-git ing https://github.com/wjz304/openwrt-packages;${CONFIG_REPO}" feeds.conf.default

  ./scripts/feeds update -a
  ./scripts/feeds install -a

  if [ -f ./feeds/ing.index ]; then
    local ing_packages=()
    mapfile -t ing_packages < <(awk -F': ' '/^Package: / {print $2}' ./feeds/ing.index)
    if [ "${#ing_packages[@]}" -gt 0 ]; then
      ./scripts/feeds uninstall "${ing_packages[@]}"
    fi
  fi

  ./scripts/feeds install -p ing -a
}

stage_local_files() {
  log "Staging config and local scripts"
  cp -f "${CONFIG_FILE}" ./.config
  cp -f "${SCRIPT_FILE}" ./diy.sh

  rm -rf ./local-patches
  if [ -d "${PATCHES_PATH}" ]; then
    cp -rf "${PATCHES_PATH}" ./local-patches
  fi

  chmod +x ./diy.sh
}

sync_config_back() {
  if [ "${GITHUB_ACTIONS}" != "true" ]; then
    return
  fi

  local config_rel
  local attempt
  local max_attempts=6
  config_rel="$(basename "${CONFIG_FILE}")"

  log "Uploading ${config_rel}"
  (
    cd "${CONFIG_PATH}"
    git pull --rebase origin main
    cp -vf "${WORK_PATH}/${CONFIG_REPO}/.config" "./${config_rel}"

    if ! git diff --quiet -- "./${config_rel}"; then
      ensure_git_identity
      git add -- "./${config_rel}"
      git commit -m "update $(date '+%Y-%m-%d %H:%M:%S')"

      for attempt in $(seq 1 "${max_attempts}"); do
        if git push origin HEAD:main; then
          return
        fi

        log "Push rejected for ${config_rel}; retry ${attempt}/${max_attempts}"
        git pull --rebase origin main
        sleep $((attempt * 2))
      done

      die "Failed to push ${config_rel} after ${max_attempts} attempts"
    fi
  )
}

collect_firmware() {
  pushd bin/targets/*/* >/dev/null

  local img_files=( *.img )
  if [ "${#img_files[@]}" -eq 0 ]; then
    popd >/dev/null
    die "No .img firmware files found"
  fi

  ls -al

  rm -rf packages *.buildinfo *.manifest *.bin sha256sums
  rm -f -- *.img.gz
  gzip -f -- "${img_files[@]}"
  mv -f -- *.img.gz "${WORK_PATH}/"

  popd >/dev/null
}

# Temporary workarounds for upstream package build failures.
# Remove the relevant block once the upstream fix is available.
apply_workarounds() {
  # gettext-full 0.22.5: gnulib 2026-07-04's exitfail.h has C++ guards and
  # no DLL_VARIABLE, but gettext 0.22.5's version uses DLL_VARIABLE without
  # guards. gnulib-tool.py fails to patch exitfail.h. Sync all 4 copies to
  # the gnulib version so gnulib-tool finds nothing to change.
  local gettext_patch_dir="package/libs/gettext-full/patches"
  if [ -d "package/libs/gettext-full" ] \
    && [ ! -f "${gettext_patch_dir}/300-sync-exitfail-h.patch" ]; then
    mkdir -p "${gettext_patch_dir}"
    cat >"${gettext_patch_dir}/300-sync-exitfail-h.patch" <<'PATCH_EOF'
--- a/gettext-runtime/gnulib-lib/exitfail.h
+++ b/gettext-runtime/gnulib-lib/exitfail.h
@@ -1,4 +1,4 @@
 /* Failure exit status
 
-   Copyright (C) 2002, 2009-2024 Free Software Foundation, Inc.
+   Copyright (C) 2002, 2009-2025 Free Software Foundation, Inc.
 
    This file is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as
@@ -16,3 +16,11 @@
    along with this program.  If not, see <https://www.gnu.org/licenses/>.  */
 
-extern DLL_VARIABLE int volatile exit_failure;
+#ifdef __cplusplus
+extern "C" {
+#endif
+
+
+extern int volatile exit_failure;
+
+
+#ifdef __cplusplus
+}
+#endif
--- a/gettext-tools/gnulib-lib/exitfail.h
+++ b/gettext-tools/gnulib-lib/exitfail.h
@@ -1,4 +1,4 @@
 /* Failure exit status
 
-   Copyright (C) 2002, 2009-2024 Free Software Foundation, Inc.
+   Copyright (C) 2002, 2009-2025 Free Software Foundation, Inc.
 
    This file is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as
@@ -16,3 +16,11 @@
    along with this program.  If not, see <https://www.gnu.org/licenses/>.  */
 
-extern DLL_VARIABLE int volatile exit_failure;
+#ifdef __cplusplus
+extern "C" {
+#endif
+
+
+extern int volatile exit_failure;
+
+
+#ifdef __cplusplus
+}
+#endif
--- a/gettext-tools/libgettextpo/exitfail.h
+++ b/gettext-tools/libgettextpo/exitfail.h
@@ -1,4 +1,4 @@
 /* Failure exit status
 
-   Copyright (C) 2002, 2009-2024 Free Software Foundation, Inc.
+   Copyright (C) 2002, 2009-2025 Free Software Foundation, Inc.
 
    This file is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as
@@ -16,3 +16,11 @@
    along with this program.  If not, see <https://www.gnu.org/licenses/>.  */
 
-extern DLL_VARIABLE int volatile exit_failure;
+#ifdef __cplusplus
+extern "C" {
+#endif
+
+
+extern int volatile exit_failure;
+
+
+#ifdef __cplusplus
+}
+#endif
--- a/libtextstyle/lib/exitfail.h
+++ b/libtextstyle/lib/exitfail.h
@@ -1,4 +1,4 @@
 /* Failure exit status
 
-   Copyright (C) 2002, 2009-2024 Free Software Foundation, Inc.
+   Copyright (C) 2002, 2009-2025 Free Software Foundation, Inc.
 
    This file is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as
@@ -16,3 +16,11 @@
    along with this program.  If not, see <https://www.gnu.org/licenses/>.  */
 
-extern DLL_VARIABLE int volatile exit_failure;
+#ifdef __cplusplus
+extern "C" {
+#endif
+
+
+extern int volatile exit_failure;
+
+
+#ifdef __cplusplus
+}
+#endif
PATCH_EOF
    log "Added exitfail.h sync patch to gettext-full"
  fi

  # b43-tools: assembler/util.h has 'typedef _Bool bool;' which is illegal
  # in C23 (bool is a keyword). Use stdbool.h instead.
  local b43_patch_dir="tools/b43-tools/patches"
  if [ -d "tools/b43-tools" ] \
    && [ ! -f "${b43_patch_dir}/100-fix-bool-typedef.patch" ]; then
    mkdir -p "${b43_patch_dir}"
    cat >"${b43_patch_dir}/100-fix-bool-typedef.patch" <<'PATCH_EOF'
--- a/assembler/util.h
+++ b/assembler/util.h
@@ -22,7 +22,7 @@
 void * xmalloc(size_t size);
 char * xstrdup(const char *str);
 
-typedef _Bool bool;
+#include <stdbool.h>
 
 typedef uint16_t be16_t;
 typedef uint32_t be32_t;
PATCH_EOF
    log "Added bool typedef fix patch to b43-tools"
  fi

  # dockerd 29.6.1: copy_binaries in hack/make/binary-daemon tries to cp
  # nested executables (containerd, runc, ...) that are not in PATH during
  # OpenWrt build, causing 'cp: cannot stat' failure. Skip missing files.
  local dockerd_pkg_dir="feeds/packages/utils/dockerd"
  local dockerd_patch_dir="${dockerd_pkg_dir}/patches"
  if [ -d "${dockerd_pkg_dir}" ] \
    && [ ! -f "${dockerd_patch_dir}/100-fix-copy-binaries.patch" ]; then
    mkdir -p "${dockerd_patch_dir}"
    cat >"${dockerd_patch_dir}/100-fix-copy-binaries.patch" <<'PATCH_EOF'
--- a/hack/make/binary-daemon
+++ b/hack/make/binary-daemon
@@ -15,6 +15,8 @@
 	fi
 	echo "Copying nested executables into $dir"
 	for file in containerd containerd-shim-runc-v2 ctr runc docker-init rootlesskit dockerd-rootless.sh dockerd-rootless-setuptool.sh; do
-		cp -f "$(command -v "$file")" "$dir/"
+		if command -v "$file" > /dev/null 2>&1; then
+			cp -f "$(command -v "$file")" "$dir/"
+		fi
 	done
 }
PATCH_EOF
    log "Added copy_binaries fix patch to dockerd"
  fi

  # hostapd Makefile: wpa-supplicant EXTRA_DEPENDS uses "r$(PKG_RELEASE)"
  # while hostapd/wpad use "$(PKG_RELEASE)", causing version mismatch:
  # wpa-supplicant wants hostapd-common (=...-r1) but actual is (...-1)
  local hostapd_makefile="package/network/services/hostapd/Makefile"
  if [ -f "${hostapd_makefile}" ] \
    && grep -q 'hostapd-common (=$(PKG_VERSION)-r$(PKG_RELEASE))' "${hostapd_makefile}"; then
    sed -i 's/hostapd-common (=$(PKG_VERSION)-r$(PKG_RELEASE))/hostapd-common (=$(PKG_VERSION)-$(PKG_RELEASE))/' "${hostapd_makefile}"
    log "Fixed wpa-supplicant EXTRA_DEPENDS version mismatch in hostapd Makefile"
  fi

  # wifi-scripts conflicts with base-files (/sbin/wifi) and hostapd-common
  # (/etc/rc.button/wps, /lib/netifd/hostapd.sh). kmod-cfg80211 depends on
  # wifi-scripts so we can't disable it; instead remove the conflicting files
  # from wifi-scripts and let the canonical owners provide them.
  local wifi_scripts_files="package/network/config/wifi-scripts/files"
  if [ -d "${wifi_scripts_files}" ]; then
    rm -f "${wifi_scripts_files}/sbin/wifi"
    rm -f "${wifi_scripts_files}/etc/rc.button/wps"
    rm -f "${wifi_scripts_files}/lib/netifd/hostapd.sh"
    log "Removed conflicting files from wifi-scripts"
  fi

  # perl 5.28.1 [host]: ext/SDBM_File/sdbm.c declares malloc/free with
  # Malloc_t=char* / Free_t=int (from config.h), which conflicts with
  # modern <stdlib.h> declarations (void*/void). Guard these externs with
  # MYMALLOC so they only apply when perl uses its own allocator.
  local perl_patch_dir="feeds/packages/lang/perl/patches"
  if [ -d "feeds/packages/lang/perl" ] \
    && [ ! -f "${perl_patch_dir}/931-sdbm-guard-malloc-decls.patch" ]; then
    mkdir -p "${perl_patch_dir}"
    cat >"${perl_patch_dir}/931-sdbm-guard-malloc-decls.patch" <<'PATCH_EOF'
--- a/ext/SDBM_File/sdbm.c
+++ b/ext/SDBM_File/sdbm.c
@@ -35,8 +35,10 @@
 extern "C" {
 #endif
 
+#if defined(MYMALLOC) && !defined(PERL_POLLUTE_MALLOC)
 extern Malloc_t malloc(MEM_SIZE);
 extern Free_t free(Malloc_t);
+#endif
 
 #ifdef __cplusplus
 }
 #endif
PATCH_EOF
    log "Added sdbm.c malloc/free guard patch to perl"
  fi
}

prepare_repo

export FORCE_UNSAFE_CONFIGURE=1

pushd "${WORK_PATH}/${CONFIG_REPO}" >/dev/null

configure_feeds
stage_local_files

./diy.sh "${CONFIG_REPO}" "${CONFIG_OWNER}" "${CONFIG_ARCH}"
apply_workarounds
make defconfig

sync_config_back

log "Downloading packages"
make download -j"$(nproc)" V=s

log "$(nproc) thread compile"
if ! make -j"$(nproc)" V=s; then
  make -j1 V=s
fi

collect_firmware

popd >/dev/null

du -chd1 "${WORK_PATH}/${CONFIG_REPO}"

log "Done"
