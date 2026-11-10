# Arcaea 面板 · iPadOS 原生外壳（未签名 ipa 流水线）

> ⚠️ 先说清楚：**`Lost-MSth/Arcaea-server` 是纯 Python/Django 服务端，里面没有任何 iOS 客户端源码**（全量 168 个文件里没有 `.xcodeproj` / `.swift`）。Arcaea 的游戏本体是闭源商业 App，从那个仓库**编译不出游戏 ipa**。
>
> 本工程是另一件事：把你**自己搭建的私服网页端**（登录、查分、资料、排行榜、管理后台）包成一个真正的 iPadOS App，并产出**未签名 `.ipa`**，你自己签名装到 iPad Pro 上。

---

## 这个 App 干什么

| 项目 | 值 |
| --- | --- |
| 技术栈 | SwiftUI + WKWebView（原生，非网页打包壳的伪 App） |
| Bundle ID | `com.yuzi.arcaea.panel` |
| 显示名 | Arcaea 面板 |
| 版本 | 1.0.0 (1) |
| 最低系统 | iOS / iPadOS 16.0（iPadOS 26 / 27 正常跑） |
| 架构 | arm64（真机） |
| 设备 | iPhone + iPad 通吃，iPad 支持四方向旋转 |

功能：

- 首次启动弹引导页填私服地址（例如 `192.168.1.10:3003`），之后自动进面板
- 持久化 Cookie / localStorage，登录状态不丢
- 下拉刷新、前进后退手势、底部导航条（返回 / 前进 / 主页 / 刷新 / 设置）
- 网络失败时顶部横幅给出人话错误（连不上 / 超时 / 证书被拒），一键重试
- 正确处理 JS 的 `alert` / `confirm` / `prompt`（WKWebView 默认不弹窗，后台改配置会踩这个坑）
- `target="_blank"` 链接在当前页打开
- 可开关「信任自签名 HTTPS 证书」（本地 http 或自签 https 都能用）
- 设置页可做连通性测试、清 Cookie/缓存、重置地址

---

## 构建记录（已跑通）

| 项目 | 值 |
| --- | --- |
| run | [`#42789784021`](https://github.com/Yuzi1204/arcaea-panel-ios/actions/runs/42789784021) ✅ success |
| runner | `macos-15`（Xcode 16.x，iOS 18 SDK） |
| 产物 | `dist/ArcaeaPanel-unsigned.ipa` · 430 KB |
| SHA256 | `21359e5f79a29307be4c4399b86c18ae7ce77d44523afe08ed7c76c5b9310e89` |
| 校验 | Mach-O 64 / arm64 / MH_EXECUTE · `MinimumOSVersion 16.0` · `UIDeviceFamily [1,2]` · 无 `_CodeSignature` · 无 `embedded.mobileprovision` · 含 `Assets.car` 与 iPad 图标 `AppIcon76x76@2x~ipad.png` |

仓库 `dist/` 里已经放了一份成品，不想跑 Actions 可以直接下（**Raw** 按钮），签名后装即可。

---

## 能玩到什么程度（重要，2026-11-10 实测与查证）

本仓库交付的是**面板 App + 服务端搭建套件**，**不是**能让官方客户端直接开玩的破解包。区别如下：

| 能力 | 状态 |
| --- | --- |
| 自建私服跑起来（登录/存档/查分/买曲/世界模式/联机接口） | ✅ 已在本机验证 |
| 把 `*.lowiro.com` 的 HTTPS 流量改写到私服（mitmproxy） | ✅ 已端到端验证（12~40ms 命中本地） |
| 自签 ipa 装到 iPad，打开管理面板 | ✅ 见 `dist/` |
| **官方 App Store 客户端原样连私服开玩** | ❌ 被客户端证书固定（TrustKit）+ mTLS 挡住 |

**证书固定的证据**（不是猜测）：

- iOS 4.0.255 逆向：装好 Burp CA 后抓不到任何 API 包，字符串确认 **TrustKit** + `TSKPinningValidator evaluateTrust:forHostname:`，官方还叠加客户端证书 mTLS（p12 密码 `HelloWorld`）→ [看雪逆向记录](https://www.ctfiot.com/88925.html)
- TrustKit 按域名配置 pin（`kTSKPinnedDomains`），而 MITM 用的仍是原域名，必然命中 → [TrustKit](https://github.com/datatheorem/TrustKit)
- Surge 文档明确警告：对这类 App 开 MITM 只会「break their connections」→ [Surge MITM](https://manual.nssurge.com/http/mitm.html)
- 官方 FAQ 原文：「**不涉及客户端破解或魔改**」，并提示「客户端在 3.6.0 发生过重大安全更新」→ [FAQ](https://arcaea.lost-msth.cn/zh/Arcaea-Server/FAQ.html)

所以社区能跑通的路只有「**改包**（砸壳 + 替换加密 API 前缀 + 去 pinning + 重签）」，例如 7.1.0 的 [akaine](https://github.com/quanq026/akaine)。本仓库**不提供**该流程——那属于破解商业客户端。

另：服务端 `database/songs/` 需要你自己的歌曲文件（`0.aff`~`4.aff` + `base.ogg`），仓库自 v2.9 起不附带（版权）。缺文件时登录/存档/查分正常，但没谱面的曲子无法游玩。

详细操作与排错见 `play-kit/iPad-连接指南.md`。

---

## 怎么拿到 ipa

流水线：`.github/workflows/ios-unsigned-ipa.yml`，跑在 GitHub 的 **macos-15** 虚拟机上（Xcode 16.x）。

1. 仓库 **Actions** → `build-ios-unsigned-ipa` → **Run workflow**
2. 等 ~3-5 分钟（首次装 XcodeGen 稍慢）
3. 跑完后在该 run 页面底部 **Artifacts** 下载 `arcaea-panel-unsigned-ipa`，解压得 `ArcaeaPanel-unsigned.ipa`

本地要复现也可以（任意 macOS + Xcode 16+）：

```bash
brew install xcodegen
xcodegen generate --spec project.yml
xcodebuild -project ArcaeaPanel.xcodeproj -scheme ArcaeaPanel \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
mkdir -p Payload && cp -R build/Build/Products/Release-iphoneos/ArcaeaPanel.app Payload/
zip -qry ArcaeaPanel-unsigned.ipa Payload
```

---

## 怎么签名装到 iPad Pro

ipa 是**未签名**的，Payload 里没有 `_CodeSignature`，用你惯用的工具签：

- **Sideloadly**（Windows/macOS，最省事，可用免费 Apple ID）
- **ESign / Feather / TrollStore 类工具**（iPad 上直接签）
- **AltStore / SideStore**（自签 + 7 天自动续签）
- **Xcode**：`ios-deploy` / Devices 窗口装 .app

> 免费证书签名有效期 7 天，过期重签即可；同一个免费 ID 最多 3 个 App。
> iPadOS 26 / 27 上首次打开需在「设置 → 通用 → VPN与设备管理」里信任你的证书。

---

## 服务端那边

```bash
git clone --depth 1 https://github.com/Lost-MSth/Arcaea-server.git
cd Arcaea-server
# 按官方 README 装依赖、复制 config 示例、建库，然后：
python launch.py            # 默认 http://0.0.0.0:3003
```

要点：

- App 里填**电脑的局域网 IP**（`ipconfig` 看），不是 `127.0.0.1`
- iPad 与电脑同一 Wi-Fi，电脑防火墙放行 3003（Windows 首次会弹询问）
- 想公网访问：路由器端口映射或 nginx 反代 + HTTPS，再把域名填进 App
- 自签 HTTPS 证书时，到 App「设置」里打开「信任自签名证书」

---

## 如果你真正想要的是「在 iPad 上玩私服」

那不需要任何 ipa —— 用 **App Store 正版客户端** + 把它的 API 域名重定向到你的私服（mitmproxy / Surge / Loon 的重写规则 + 安装信任证书）。这条路是官方客户端连自建服务的标准做法，不涉及重打包。

---

## 目录结构

```
project.yml                     XcodeGen 工程定义（单一事实来源）
Support/Info.plist              由 xcodegen 生成，含 ATS / 旋转 / 启动屏配置
Sources/
  ArcaeaPanelApp.swift          入口
  RootView.swift                主面板 + 底部导航 + 错误横幅
  WebPanelView.swift            WKWebView 封装与全部代理实现
  ServerStore.swift             地址/偏好持久化 + WebState 导航状态
  WKWebViewBox.swift            WKWebView 引用包装
  OnboardingView.swift          首次启动引导
  SettingsSheet.swift           设置页
.github/workflows/ios-unsigned-ipa.yml
```
