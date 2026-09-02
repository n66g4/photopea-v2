# Photopea Offline

离线版 [Photopea](https://www.photopea.com/)（免费在线 PS 替代品），可在本地或 NAS 上自托管，无需访问 photopea.com。

上游来源：[gitflic.ru/project/photopea-v2/photopea-v-2](https://gitflic.ru/project/photopea-v2/photopea-v-2)

## 快速安装（NAS 套件）

在 [Releases](https://github.com/n66g4/photopea-v2/releases) 下载对应安装包：

| 平台 | 文件 | 安装方式 |
|------|------|----------|
| 群晖 DSM 7.1+ | `photopea-*-noarch.spk` | 套件中心 → 手动安装 |
| 飞牛 fnOS 0.9+ | `photopea-*.fpk` | 应用中心 → 本地安装 |

安装后访问：`http://<NAS-IP>:8887`

### 依赖

- **群晖**：需安装 Python 3 套件（系统自带或套件中心安装）
- **飞牛**：需安装 `python312` 套件（manifest 已声明依赖）

## 本地运行

```bash
git clone https://github.com/n66g4/photopea-v2.git
cd photopea-v2
python3 -m http.server --directory www.photopea.com 8887
```

浏览器打开 `http://localhost:8887` 即可使用。

### 更新静态资源

```bash
python3 Updater.py          # 从 photopea.com 拉取最新文件
python3 Updater.py --fonts  # 同时下载字体
```

## 自行打包 SPK / FPK

```bash
cd package
./build.sh
```

产物输出到 `package/dist/`：

- `photopea-<version>-noarch.spk` — 群晖
- `photopea-<version>.fpk` — 飞牛

打包需要 macOS/Linux 环境；飞牛 FPK 构建会自动下载官方 [fnpack](https://developer.fnnas.com/docs/cli/fnpack/) 工具。

## 目录结构

```
├── www.photopea.com/   # Photopea 静态资源（Web 根目录）
├── Updater.py          # 从官网同步资源的脚本
├── package/            # SPK / FPK 打包脚本与配置
│   ├── build.sh
│   ├── spk-src/        # 群晖套件源码
│   └── fpk-src/        # 飞牛应用源码
└── _vendor/            # Updater.py 依赖
```

## 说明

- Photopea 非开源软件，本项目为社区离线镜像，仅供个人/内网使用
- 部分功能（在线资源、AI 等）可能仍需要外网
- 桌面入口通过 HTTP 8887 端口打开编辑器页面

## 相关项目

- [tim0-12432/photopea](https://github.com/tim0-12432/photopea) — Electron 封装
- [NFXT/Photopea-Desktop-App](https://github.com/NFXT/Photopea-Desktop-App) — 另一 Electron 封装
