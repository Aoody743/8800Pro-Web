# 8800Pro Web 写频工具

8800Pro Web 是一款面向森海克斯 8800Pro 的浏览器写频工具，使用 React、Vite 和 TypeScript 构建。它把常用信道、区域、VFO、功能菜单、DTMF、FM 收音机、卫星预设、备份导入导出等操作放到一个网页里，尽量减少传统写频软件的安装和平台限制。

## 在线使用

- GitHub Pages：适合公开访问和日常快速使用。
- 自建服务器：适合国内访问场景，服务器版本会显示 ICP 与公安备案号。

浏览器建议使用 Chrome、Edge、Arc 等 Chromium 系浏览器。Web Bluetooth 和 Web Serial 都要求安全上下文：线上站点需要 HTTPS，本地调试可以使用 `http://localhost`。

## 主要功能

- 通过 USB 写频线读取和写入 8800Pro。
- 通过蓝牙 BLE 读取频率数据；蓝牙写频已临时锁定，避免已知的 FFE1 帧头污染风险。
- 编辑 8 个区域、512 个信道、VFO A/B、功能设置、DTMF 与 FM 收音机。
- 支持中继库、卫星模式、Excel/CSV/JSON 导入导出和本地备份。
- 支持 USB 写入 128 x 128 RGB565 开机图。
- 蓝牙写开机图和蓝牙写频暂未开放，当前请使用 USB 写频线完成写入。

## 写频建议

1. 先读频，再修改，再写频。
2. 写频前保存一份 JSON 备份，方便回滚。
3. 当前版本请使用 USB 写频线写回；蓝牙可用于读频和协议排查。
4. 如果浏览器提示蓝牙不可用，确认页面是 HTTPS 或 `localhost`，并使用 Chromium 系浏览器。
5. 如果设备中途断开，重新连接后先读频确认机器内数据，再决定是否继续写入。

## 蓝牙写频状态

8800Pro 的 FFE0/FFE1 蓝牙链路已经可以完成握手和读频，但实机验证发现，直接向 FFE1 写入 `57 addr 40 + 64 bytes` 会收到 ACK，却会把 `57 addr 40` 帧头落进信道数据区。机器端随后会显示 `404.00657`、`412.00757` 这类乱码频率。

因此当前网页会阻止蓝牙写回，避免继续污染设备；读到已污染的空信道时，编码器会按空信道处理，通过 USB 写回时会恢复为全 `FF` 空槽。后续需要结合官方 APK 抓包或更完整的 BLE 写块协议再重新开放蓝牙写频。

## 本地开发

```bash
pnpm install
pnpm dev
```

默认开发地址：

```text
http://localhost:5173/
```

常用命令：

```bash
pnpm test
pnpm build
pnpm build:server
```

`pnpm build` 用于 GitHub Pages 等普通静态部署；`pnpm build:server` 用于自建服务器版本，会保留页面里的备案号显示。

## 部署说明

### GitHub Pages

仓库内置 GitHub Actions 工作流：

```text
.github/workflows/deploy-pages.yml
```

推送到 `main` 或手动触发 workflow 后，会执行 `pnpm build` 并部署到 GitHub Pages。这个版本默认不显示备案号，避免和自建服务器的合规信息混用。

### 自建服务器

自建服务器部署请使用：

```bash
pnpm build:server
```

构建产物位于 `dist/`。服务器版本会显示：

- 粤ICP备2023143201号
- 粤公网安备44011302005027号

## 技术栈

- React 19
- TypeScript
- Vite
- Web Serial API
- Web Bluetooth API
- IndexedDB 本地备份
- xlsx 导入导出

## 致谢

本项目在协议理解和功能实现过程中参考了社区项目与资料，尤其感谢 `SydneyOwl/senhaix-freq-writer-enhanced` 对森海克斯写频生态的探索。

## 免责声明

写频会直接修改设备内存数据。请确认频率、亚音、功率、带宽等参数符合当地无线电管理规定，并在写入前做好备份。因错误配置、连接中断或不当使用造成的数据丢失、设备异常或合规风险，需要由使用者自行承担。
