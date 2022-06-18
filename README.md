# OpenWrt_Build



[![LICENSE](https://img.shields.io/github/license/mashape/apistatus.svg?style=flat-square&label=LICENSE)](LICENSE)

## Note

A actions for building OpenWrt with GitHub Actions  

Web admin panel default IP is 192.168.2.1 and default password is "password".  

## Usage

- Click the [Use this template](https://github.com/P3TERX/Actions-OpenWrt/generate) button to create a new repository.
- Generate `.config` files using [Lean's OpenWrt](https://github.com/coolsnowwolf/lede) source code. ( You can change it through environment variables in the workflow file. )
- Push `.config` file to the GitHub repository.
- Select `Build OpenWrt` on the Actions page.
- Click the `Run workflow` button.
- When the build is complete, click the `Artifacts` button in the upper right corner of the Actions page to download the binaries.


## Credits
- [OpenWrt](https://github.com/openwrt/openwrt)
- [Lean's OpenWrt](https://github.com/coolsnowwolf/lede)
- [P3TERX's Actions](https://github.com/P3TERX/Actions-OpenWrt)
- [SuLingGG's Actions](https://github.com/SuLingGG/OpenWrt-Rpi)
