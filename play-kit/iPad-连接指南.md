# iPad 连接指南 —— 以及一个你必须先知道的坏消息

## 0. 结论先行

| 东西 | 状态 |
| --- | --- |
| 私服本体（Flask） | ✅ 已在本机跑起来，`http://172.16.184.4:3003`，数据库自动建好 |
| 重定向层（mitmproxy） | ✅ 已跑起来，`172.16.184.4:8080`；实测 `https://arcapi-v3.lowiro.com/...` 被改写到本地私服（12~40ms 返回） |
| 面板 App（`.ipa`） | ✅ 已产出未签名 ipa，自签可装，打开就是私服管理面板 |
| **官方客户端直接连私服开玩** | ❌ **在未改包的 App Store 原版上做不到**，原因是证书固定（见第 4 节） |

本鱼能给你搭的都搭好了、也验证过了。但「自签个 ipa 装上去就能玩 Arcaea」这件事，卡在客户端那一侧，不在服务端。

---

## 1. 现在本机有什么在跑

| 组件 | 地址 | 进程/端口 |
| --- | --- | --- |
| Arcaea 私服 | `http://172.16.184.4:3003` · 面板 `/web/login` | python，3003（Link Play 用 10900/10901） |
| 重定向代理 | `172.16.184.4:8080` | mitmdump，只拦 `*.lowiro.com` |
| 管理后台账号 | 用户 `admin` / 密码 `KP86ZvGUNNaqEH` | 见 `config.py` 的 `PASSWORD` |

一键起/停：`启动.bat` / `停止.bat`（内部 `start-all.ps1`，会自动重新探测局域网 IP 并更新歌曲下载前缀）。
日志：`arcaea-server-runtime\logs\server.err.log`、`proxy.out.log`。

> 首次建议**右键「以管理员身份运行」`启动.bat`** 一次：它会自动给 3003 / 8080 加防火墙放行规则。
> 不加规则时 iPad 可能连不上，这是最常见的坑。

---

## 2. 装面板 App（这个真能装、真能用）

1. 自签 `dist\ArcaeaPanel-unsigned.ipa`（Sideloadly / ESign / AltStore 都行，免费 Apple ID 即可）
2. iPad「设置 → 通用 → VPN与设备管理」信任你的签名证书
3. 打开 App，地址栏填 `172.16.184.4:3003`（**只填 IP:端口 就行**，App 会自动落到 `/web/login`）
4. 用 `admin / KP86ZvGUNNaqEH` 登录，就是私服管理后台：查分、改用户、发物品、看排行榜

---

## 3. 官方客户端 → 私服：30 秒自测（建议你亲手跑一次）

理论上有证书固定挡路，但 7.x 版本没有公开复测记录，所以**值得花 30 秒实测**：

1. iPad：设置 → 无线局域网 → 当前 Wi-Fi → 配置代理 → **手动**
   - 服务器 `172.16.184.4`，端口 `8080`
2. iPad Safari 打开 `http://mitm.it` → 选 Apple/iOS → 允许下载
3. 设置 → 通用 → VPN与设备管理 → 安装该描述文件
4. 设置 → 通用 → 关于本机 → 证书信任设置 → 打开 **mitmproxy** 的开关
5. 打开 Arcaea，点到登录界面（随便输账号点登录也行）
6. 回电脑看 `arcaea-server-runtime\logs\server.err.log`

判读：

- 里面出现**不是** curl/浏览器的 POST 请求（来自 `127.0.0.1`，路径类似 `/user/login`、`/compose/...`）→ **没有 pinning，能通**，接着注册账号就能玩（还缺点歌曲文件，见第 6 节）
- 一条都没有 → **证书固定生效**，这条路在未改包客户端上就是死的

---

## 4. 为什么未改包客户端基本走不通（有证据，不是本鱼瞎猜）

1. **iOS 4.0.255 的逆向记录**：装好 Burp 的 CA 后「打開遊戲……沒有看到任何 API 相關的數據包……這是遇上 Cert Pinning 了」。字符串里确认使用 **TrustKit**，关键函数 `[TSKPinningValidator evaluateTrust:forHostname:]`。〔[看雪 Invert iOS 逆向](https://www.ctfiot.com/88925.html)〕
2. **官方还叠了客户端证书（mTLS）**：客户端内置 PKCS12（密码 `HelloWorld`），API 前缀是 48 字节密文（`.../join/21`）。〔同上〕
3. **TrustKit 是按域名配 pin 的**（`kTSKPinnedDomains`）。我们把 `arcapi-v3.lowiro.com` 原样劫持再做 MITM，用的还是原域名 → 必然命中 pin，客户端直接掐掉连接。〔[TrustKit](https://github.com/datatheorem/TrustKit)〕
4. **Surge 官方文档也警告**：开了 MITM 只会让这类 App 连接断掉。〔[Surge MITM](https://manual.nssurge.com/http/mitm.html)〕
5. **官方 FAQ 明说不碰客户端**：「本项目 Arcaea-Server 是……简易服务端代码仓库，**不涉及客户端破解或魔改**相关内容」，并提示「客户端在 3.6.0 版本发生过重大安全更新」。〔[FAQ](https://arcaea.lost-msth.cn/zh/Arcaea-Server/FAQ.html)〕
6. 社区因此**没有**现成的 Arcaea MITM/重写规则集（与 pinning 结论一致）；针对 7.1.0 的私服项目仍是走「改包」而不是 MITM。〔[akaine](https://github.com/quanq026/akaine)〕

当前 API 域名也已换了：主力是 `arcapi-v3.lowiro.com` 与 `auth.lowiro.com`（`arcapi.lowiro.com` 已 NXDOMAIN 退役）。本鱼的代理按 `lowiro.com` 后缀匹配，三个都能接住。

---

## 5. 真想在这台 iPad 上玩，剩哪些路（含本鱼不做的）

| 路线 | 可行性 | 本鱼 |
| --- | --- | --- |
| 改包：砸壳 ipa + 改加密 API 前缀 + 去 pinning + 重签 | 社区标准做法，7.1.0 有现成项目 | ❌ 不做：这是破解商业客户端，不帮 |
| 越狱 + frida 运行时 unpin | 需要越狱 | ❌ iPadOS 27 没有越狱 |
| TrollStore | 只支持 iOS 14.0b2–17.0 部分版本 | ❌ 你的 27 不支持 |
| 官方原版 + MITM | 被证书固定挡 | 已备好，随你实测 |
| 换台 Android 改包玩 | 可行（改 `libcocos2dcpp.so`） | ❌ 同样是改包 |
| 就用面板 App 查分/管理 | ✅ | 已交付 |

一句话：**服务端这半边本鱼全给你弄好了；客户端那半边绕不开「改包」，而改包本鱼不接。**

---

## 6. 就算客户端连上了，还差歌曲文件

服务端每首曲子需要 `database/songs/<song_id>/` 下至少 `0.aff`~`4.aff`（谱面）和 `base.ogg`（音频）。
现在这个目录基本是空的（只有个 `dement` 空壳），跑一下就知道：

```powershell
python arcaea-play-kit\check_songs.py
```

- 仓库从 v2.9 起**不再提供歌曲数据**（版权原因）。
- 没有文件时：登录、存档、查分、买曲、世界模式都正常，**但没有谱面/音频的曲子无法开始游玩**。
- 已在你客户端里缓存过的曲子，理论上可能直接可玩〔未证实〕；没缓存过的必须由服务端提供文件。
- 本鱼不会替你抓取或分发这些素材。

---

## 7. 排错

| 现象 | 处理 |
| --- | --- |
| iPad 打不开 `172.16.184.4:3003` | 用管理员身份重跑 `启动.bat` 放行防火墙；确认同一 Wi-Fi；确认不是 AP 隔离 |
| 开了代理 iPad 上不了网 | 说明代理挂了：跑 `启动.bat`；或先用「关闭代理」恢复上网 |
| 代理在跑但客户端没动静 | 先按第 3 节确认证书已「信任」；仍无 → 证书固定（第 4 节） |
| 电脑重启后 IP 变了 | 重跑 `启动.bat`，脚本会自动探测新 IP 并改 `config.py` 的下载前缀 |
| 想在外网玩 | 你机器上有 Tailscale（`100.104.17.24`）：iPad 装 Tailscale 后把代理服务器填这个 IP 即可 |
| 端口被占 | `netstat -ano | findstr :3003`，或直接跑 `停止.bat` |
