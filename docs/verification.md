# v0.2.0 发布检查

本版打通单日便签返回一周与跨日导航、修复最小化锁死与重开晾衣绳恢复问题，保留 `Shift + 回车` 单条换行并增加按行拆分、周回顾全局搜索与日历跳转、跨年周标签年份展示、设置页 JSON 备份校验恢复及暗色对比度优化。

- 自动测试覆盖：`python3 scripts/check-localization.py`（126 组中英日三语条目校验通过）、`swift test` 共 38 项测试通过（`AetherNoteCoreTests` 23 项 + `AetherNoteAppTests` 15 项，涵盖单条多行写入、空天键清理、全文与日期搜索、`ClotheslineFocus` 最小化与重新启用恢复、草稿带到今天、跨年周标题、备份恢复替换及多语言/多材质视图离屏布局）。
- 视觉与布局检查：在隔离临时数据目录下生成 `NSHostingView` 离屏布局快照，检查中/英/日三语下的工具栏、导航栏、多行输入与设置按钮适配及暗色状态标签对比度；README 同步采用真实 macOS 27 截图（晾衣绳与设置 0.1.4、回顾 0.1.3、编辑器 0.1.5）。
- 打包与签名门禁：`swift build -c release`、`scripts/build-app.sh`、`scripts/check-updater.py`、Developer ID 签名、Apple 公证、stapling、`spctl` / `syspolicy_check` 与 Sparkle Ed25519 签名验证均通过后发布至 GitHub 与官网。
- 范围说明：构建环境无 macOS 屏幕录制与辅助功能授权，未使用 `screencapture` 对窗口服务器重新截图或通过 UI 脚本驱动 Sparkle 弹窗点击；在线更新源签名与 `v0.1.5 -> v0.2.0` 隔离数据目录兼容性在公网发布后以独立校验验证，全程使用隔离 `--data-dir`，不修改宿主正式日记。
