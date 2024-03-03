#!/usr/bin/env bash
#
# Copyright (C) 2022 Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

WORKSPACE=${GITHUB_WORKSPACE:-$(pwd)}
release="test"
script="diy.sh"
config="${1}"                 # config 命名规则: <repo>;<owner>;<name>.config
CONFIG=${config/.config/}     # 去掉 .config 后缀
CONFIG_ARRAY=(${config//;/ }) # ;号分割

if [ ${#CONFIG_ARRAY[@]} -ne 3 ]; then
  echo "${config} name error!"
  exit 1
fi

CONFIG_REPO="${CONFIG_ARRAY[0]}"
CONFIG_OWNER="${CONFIG_ARRAY[1]}"
CONFIG_NAME="${CONFIG_ARRAY[2]}"

if [ "${CONFIG_REPO}" == "openwrt" ]; then
  REPO_URL="https://github.com/openwrt/openwrt"
  REPO_BRANCH="master"
fi

if [ "${CONFIG_REPO}" == "lede" ]; then
  REPO_URL="https://github.com/coolsnowwolf/lede"
  REPO_BRANCH="master"
fi

if [ ! -d ${CONFIG_REPO} ]; then
  git clone --depth=1 -b ${REPO_BRANCH} ${REPO_URL} ${CONFIG_REPO}
  if [ -d "${CONFIG_REPO}/package/lean/r8125" ]; then
    rm -rf ${CONFIG_REPO}/package/lean/r8125
  fi
fi

# root.
export FORCE_UNSAFE_CONFIGURE=1

pushd ${CONFIG_REPO}
git pull

sed -i "/src-git ing /d; 1 i src-git ing https://github.com/wjz304/openwrt-packages;${CONFIG_REPO}" feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds uninstall $(grep Package ./feeds/ing.index | awk -F': ' '{print $2}')
./scripts/feeds install -p ing -a

cp -f "${WORKSPACE}/${config}" "./.config"
cp -f "${WORKSPACE}/${script}" "./diy.sh"

chmod +x "./diy.sh"
"./diy.sh" "${CONFIG_REPO}" "${CONFIG_OWNER}"

make defconfig

if [ "$GITHUB_ACTIONS" == "true" ]; then
  pushd ${WORKSPACE}
  git pull
  cp -f ${WORKSPACE}/${CONFIG_REPO}/.config "${WORKSPACE}/${config}"
  status=$(git status -s | grep "${config}" | awk '{printf $2}')
  if [ -n "${status}" ]; then
    git add "${status}"
    git commit -m "update $(date +%Y-%m-%d" "%H:%M:%S)"
    git push -f
  fi
  popd
fi

echo -e "download package"
make download -j8 V=s

# find dl -size -1024c -exec ls -l {} \;
# find dl -size -1024c -exec rm -f {} \;

echo -e "$(nproc) thread compile"
make -j$(nproc) V=s || make -j1 V=s

DEVICE_NAME=$(grep '^CONFIG_TARGET.*DEVICE.*=y' .config | sed -r 's/.*DEVICE_(.*)=y/\1/')

pushd bin/targets/*/*
ls -al

# sed -i '/buildinfo/d; /\.bin/d; /\.manifest/d' sha256sums
rm -rf packages *.buildinfo *.manifest *.bin sha256sums

filename=${CONFIG_REPO}-${CONFIG_NAME}-${release}.zip

gzip *.img 2>/dev/null || true
zip -q -r ${filename} *

if [ "$GITHUB_ACTIONS" == "true" ]; then
  echo "firmware=$(pwd)/${filename}" >>$GITHUB_ENV
else
  mv -f ${filename} ${WORKSPACE}
fi
popd # bin/targets/*/*
popd # ${CONFIG_REPO}
