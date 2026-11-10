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
