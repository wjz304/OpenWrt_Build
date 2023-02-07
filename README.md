# OpenWrt_Build

## 介绍  
[OpenWrt_Build](https://github.com/wjz304/OpenWrt_Build)

<!-- version -->
<a href="https://github.com/wjz304/OpenWrt_Build/releases">
<img src="https://img.shields.io/github/release-pre/wjz304/OpenWrt_Build.svg?style=flat" alt="latest version"/>
</a>
<!-- license -->
<a href="https://github.com/wjz304/OpenWrt_Build">
<img src="https://img.shields.io/github/license/mashape/apistatus.svg?style=flat" alt="license"/>
</a>

## Note

>源码仓库：[Lean's LEDE](https://github.com/coolsnowwolf/lede)  

>默认后台：default IP is 192.168.2.1 and default password is "password".  


## Preview
![Image text](https://user-images.githubusercontent.com/5615843/217126692-7ff43adf-df84-4b3c-96f3-8bbfbf8656df.jpeg)  


<pre>
报错：
Collected errors:
 * opkg_download: Failed to download https://mirrors.cloud.tencent.com/lede/snapshots/packages/x86_64/ing/Packages.gz, wget returned 8.

解决：
sed -i 's|^src/gz openwrt_ing|#src/gz openwrt_ing|' /etc/opkg/distfeeds.conf 
</pre>


## Credits
- [OpenWrt](https://github.com/openwrt/openwrt)
- [Lean's LEDE](https://github.com/coolsnowwolf/lede)
- [P3TERX's Actions](https://github.com/P3TERX/Actions-OpenWrt)
- [SuLingGG's Actions](https://github.com/SuLingGG/OpenWrt-Rpi)
