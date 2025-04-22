#!/usr/bin/env bash
#
# Copyright (C) 2022 Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ -z "${1}" ] || [ ! -f "${1}" ]; then
  echo "Usage: $0 <config file>"
  exit 1
fi

WORK_PATH="$(pwd)"

SCRIPT_FILE="${WORK_PATH}/diy.sh"
CONFIG_FILE=$(realpath "${1}")                        # 传入的配置文件
CONFIG_PATH=$(dirname "${CONFIG_FILE}")               # 配置文件路径
CONFIG_NAME=$(basename "${CONFIG_FILE}" .config)      # 配置文件名
IFS=';' read -r -a CONFIG_ARRAY <<< "${CONFIG_NAME}"  # 分割配置文件名

GITHUB_ACTIONS="${2:-false}"

if [ ${#CONFIG_ARRAY[@]} -ne 3 ]; then
  echo "${CONFIG_FILE} name error!" # config 命名规则: <repo>;<owner>;<name>.config
  exit 1
fi

CONFIG_REPO="${CONFIG_ARRAY[0]}"
CONFIG_OWNER="${CONFIG_ARRAY[1]}"
CONFIG_ARCH="${CONFIG_ARRAY[2]}"

if [ "${CONFIG_REPO}" = "openwrt" ]; then
  REPO_URL="https://github.com/openwrt/openwrt"
  REPO_BRANCH="master"
elif [ "${CONFIG_REPO}" = "lede" ]; then
  REPO_URL="https://github.com/coolsnowwolf/lede"
  REPO_BRANCH="master"
else
  echo "${CONFIG_FILE} name error!"
  exit 1
fi

if [ ! -d "${WORK_PATH}/${CONFIG_REPO}" ]; then
  git clone --depth=1 -b "${REPO_BRANCH}" "${REPO_URL}" "${WORK_PATH}/${CONFIG_REPO}"
  # if [ -d "${CONFIG_REPO}/package/kernel/r8125" ]; then
  #   rm -rf ${CONFIG_REPO}/package/kernel/r8125
  # fi
  # if [ -d "${CONFIG_REPO}/package/lean/r8152" ]; then
  #   rm -rf ${CONFIG_REPO}/package/lean/r8152
  # fi
fi

# root.
export FORCE_UNSAFE_CONFIGURE=1

pushd "${WORK_PATH}/${CONFIG_REPO}" || exit

git pull

sed -i "/src-git ing /d; 1 i src-git ing https://github.com/wjz304/openwrt-packages;${CONFIG_REPO}" feeds.conf.default

./scripts/feeds update -a
# if [ -d ./feeds/packages/lang/golang ]; then
#   rm -rf ./feeds/packages/lang/golang
#   git clone --depth=1 -b 22.x https://github.com/sbwml/packages_lang_golang ./feeds/packages/lang/golang
# fi
./scripts/feeds install -a
./scripts/feeds uninstall "$(grep Package ./feeds/ing.index 2>/dev/null | awk -F': ' '{print $2}')"
./scripts/feeds install -p ing -a

cp -f "${CONFIG_FILE}" "./.config"
cp -f "${SCRIPT_FILE}" "./diy.sh"

chmod +x "./diy.sh"
"./diy.sh" "${WORK_PATH}/${CONFIG_REPO}" "${CONFIG_OWNER}" "${CONFIG_ARCH}"

make defconfig

if [ "${GITHUB_ACTIONS}" = "true" ]; then
  echo "upload ${CONFIG_FILE}"
  pushd "${CONFIG_PATH}" || exit
  git pull
  cp -vf "${WORK_PATH}/${CONFIG_REPO}/.config" "${CONFIG_FILE}"
  status=$(git status -s | grep "${CONFIG_NAME}" | awk '{printf $2}')
  if [ -n "${status}" ]; then
    git add "${status}"
    git commit -m "update $(date +%Y-%m-%d" "%H:%M:%S)"
    git push -f
  fi
  popd || exit # "${CONFIG_PATH}"
fi

echo "download package"
make download -j8 V=s

# find dl -size -1024c -exec ls -l {} \; -exec rm -f {} \;

echo "$(nproc) thread compile"
make -j"$(nproc)" V=s || make -j1 V=s
if [ $? -ne 0 ]; then
  echo "Build failed!"
  popd || exit # "${WORK_PATH}/${CONFIG_REPO}"
  exit 1
fi

pushd bin/targets/*/* || exit

ls -al

# sed -i '/buildinfo/d; /\.bin/d; /\.manifest/d' sha256sums
rm -rf packages *.buildinfo *.manifest *.bin sha256sums

rm -f *.img.gz
gzip -f *.img

mv -f *.img.gz "${WORK_PATH}"

popd || exit # bin/targets/*/*

popd || exit # "${WORK_PATH}/${CONFIG_REPO}"

du -chd1 "${WORK_PATH}/${CONFIG_REPO}"

echo "Done"
