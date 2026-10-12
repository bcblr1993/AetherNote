# AetherNote

**把做过的小事，挂在这一周的晾衣绳上。**

A small, native macOS journal. One note per day, up to seven on a playful clothesline. Write throughout the day; let yesterday stay yesterday.

[下载 / Download](https://github.com/bcblr1993/AetherNote/releases/latest) · [English guide](docs/guide-en.md) · [测试与发布](docs/verification.md)

## 首版功能

- **随手记一行**：回车追加，Shift + 回车换行；粘贴多行会分成多条记录。今天可以修改和删除。
- **过日即封存**：按本机日历日期封存，昨天只能阅读和复制。保存时再次检查日期，系统时间回拨也不会重新打开已经观察到的历史日期。
- **一周一条晾衣绳**：默认周一到周五，可显示周末；周末已有记录或当天为周末时自动显示，最多七张。旧周可以翻阅。
- **拖动与整理**：左右拖动换位，上下拉动回弹，拖绳子也有弹性；一键或双击绳子按日期整理。拖动不会改变日期或正文。
- **三种材质、三种语言**：Liquid Glass、暖色纸张、极简纸张；简体中文、English、日本語，默认跟随系统。
- **原生玻璃**：macOS 26+ 使用 `NSGlassEffectView`，macOS 27 使用交互玻璃效果；旧系统使用原生磨砂材质。尊重系统减少动态效果、降低透明度与增强对比度。
- **安静的每小时提醒**：一小时没有记录后，只改变菜单栏小标记。无声音、无自动窗口、不抢焦点；睡眠后重新计时，输入时延后，可关闭。
- **本周回顾**：日期与正文分栏，按真实日期排列，可复制整周或导出 Markdown。
- 本地保存、草稿自动保存、完整 JSON 备份、菜单栏入口、全局快捷键、可选登录启动。

## 安装与使用

发布的二进制适用于 **Apple Silicon（M 系列）Mac，macOS 14 或更新版本**。完整 macOS 27 玻璃效果需要 macOS 27。Intel 暂不提供预编译包。

1. 从 Releases 下载 DMG，将 AetherNote 拖到 Applications。
2. 打开应用，点击菜单栏便签图标；首次启动会展开晾衣绳。点今天，记下做过的事情。
3. `⌃⌥N` 打开今天的输入窗口；`⌃⌥L` 展开或收起。也可以将鼠标移到屏幕顶部中央。
4. 固定按钮让晾衣绳保持显示。未固定时鼠标离开后收起。
5. 右键卡片可向左/右移动；右键菜单栏图标可打开设置或退出。

> 封存是应用内的记录规则，不是防篡改审计或加密存储。系统日期被错误地调到未来，或跨时区导致日期回退时，应用会保守保持只读，直到日期追上已观察到的日期。备份文件可以被用户手工修改。

## 数据与隐私

应用运行时不联网、不上传内容、不收集使用数据，无账号、云同步或 AI 服务。

数据目录：`~/Library/Application Support/AetherNote/`

- `journal.json`：正文、日期封存标记、显示顺序。
- `journal.previous.json`：最近一次成功写入之前的版本（不是长期历史备份）。
- `drafts.json`：尚未提交的草稿，跨日后可以带到今天。
- `preferences.json`：外观和提醒偏好。

写入使用原子替换，目录/文件权限为 700/600，单写入进程锁避免重复实例覆盖。读取损坏的正文文件会报错并保留原文件，不会自动清空。建议定期通过设置导出完整备份。恢复方法见 [English guide](docs/guide-en.md#backup-and-recovery)。

## 构建

无第三方生产依赖，SwiftUI + AppKit + Swift Package Manager。推荐 Xcode 27；Xcode 26 使用其 SDK 可用的原生玻璃效果。

```sh
swift test
python3 scripts/check-localization.py
bash scripts/build-app.sh
open build/AetherNote.app
```

独立演示数据（不会写入正式日记目录）：

```sh
open build/AetherNote.app --args --data-dir "$PWD/work/demo" --demo --show
```

`--demo` 只在显式传入的数据目录为空时生成样例。`--editor`、`--review`、`--settings` 可用于打开对应界面。

## 设计来源与许可

晾衣绳的交互意象受到 [Tendedero](https://github.com/alejandrobujan/tendedero) 启发。AetherNote 是独立编写的日记产品，没有复制其源码或素材。

MIT License · AetherNative
