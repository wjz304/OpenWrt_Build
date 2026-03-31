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

prepare_repo

export FORCE_UNSAFE_CONFIGURE=1

pushd "${WORK_PATH}/${CONFIG_REPO}" >/dev/null

configure_feeds
stage_local_files

./diy.sh "${CONFIG_REPO}" "${CONFIG_OWNER}" "${CONFIG_ARCH}"
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
