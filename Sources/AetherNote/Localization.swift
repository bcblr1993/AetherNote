import Foundation

enum Language: String, Codable, CaseIterable, Identifiable {
    case system, zh, en, ja
    var id: String { rawValue }
    var title: String { switch self { case .system: return "System / 系统"; case .zh: return "简体中文"; case .en: return "English"; case .ja: return "日本語" } }
    var resolved: Language {
        guard self == .system else { return self }
        let language = Locale.preferredLanguages.first ?? "en"
        return language.hasPrefix("zh") ? .zh : language.hasPrefix("ja") ? .ja : .en
    }
    var locale: Locale { Locale(identifier: resolved == .zh ? "zh_CN" : resolved == .ja ? "ja_JP" : "en_US") }
}

enum Copy {
    // Every row has exactly three translations: Chinese, English, Japanese.
    static let values: [String: [String]] = [
        "editMenu": ["编辑", "Edit", "編集"], "undo": ["撤销", "Undo", "取り消す"],
        "cut": ["剪切", "Cut", "切り取り"], "copyMenu": ["复制", "Copy", "コピー"],
        "paste": ["粘贴", "Paste", "ペースト"], "selectAll": ["全选", "Select All", "すべてを選択"],
        "today": ["今天", "Today", "今日"], "sealed": ["已封存", "Sealed", "封存済み"],
        "future": ["尚未开始", "Not yet", "まだ先"], "empty": ["今天做了什么？", "What did you do today?", "今日は何をしましたか？"],
        "noEntries": ["这一天没有记录", "No entries for this day", "この日の記録はありません"],
        "add": ["记一行", "Add a line", "一行メモ"], "append": ["追加一行", "Add line", "一行追加"],
        "placeholder": ["再记一件做过的事…", "One more thing you did…", "もう一つ、書き留める…"],
        "inputHint": ["回车追加 · Shift + 回车换行", "Return to add · Shift + Return for a new line", "Return で追加 · Shift + Return で改行"],
        "edit": ["修改", "Edit", "編集"], "save": ["保存修改", "Save edit", "変更を保存"],
        "cancel": ["取消", "Cancel", "キャンセル"], "delete": ["删除这一行", "Delete entry", "この記録を削除"],
        "deleteConfirm": ["删除这条今天的记录？", "Delete this entry from today?", "今日のこの記録を削除しますか？"],
        "sealedHint": ["这一天已经结束，可以查看和复制，不能修改或追加。", "This day has ended. You can read and copy, but cannot edit or add entries.", "この日は終了しました。閲覧とコピーのみ可能です。編集や追記はできません。"],
        "futureHint": ["到这一天再留下记录。", "Come back on this day to write.", "当日になったら記録できます。"],
        "copy": ["复制内容", "Copy entries", "内容をコピー"], "copied": ["已复制", "Copied", "コピーしました"],
        "close": ["关闭", "Close", "閉じる"], "review": ["本周回顾", "Week in review", "一週間の振り返り"],
        "copyWeek": ["复制整周", "Copy week", "一週間をコピー"], "export": ["导出 Markdown", "Export Markdown", "Markdown 書き出し"],
        "tidy": ["一键整理", "Tidy the line", "きれいに並べる"],
        "tidyHint": ["按日期重新挂好，记录内容不会改变。", "Arrange by date without changing your entries.", "内容を変えず、日付順に並べ直します。"],
        "tidied": ["已按日期整理", "Arranged by date", "日付順に並べました"],
        "pin": ["固定展示", "Keep visible", "表示を固定"], "hide": ["收起晾衣绳", "Hide the line", "ひもを隠す"],
        "show": ["展开晾衣绳", "Show the line", "ひもを表示"], "weekend": ["显示周末", "Show weekends", "週末を表示"],
        "previous": ["上一周", "Previous week", "前の週"], "next": ["下一周", "Next week", "次の週"],
        "thisWeek": ["回到本周", "This week", "今週に戻る"], "settings": ["设置", "Settings", "設定"],
        "appearance": ["外观与语言", "Appearance & language", "表示と言語"], "language": ["界面语言", "Language", "言語"],
        "theme": ["便签风格", "Note material", "メモの素材"], "glass": ["Liquid Glass", "Liquid Glass", "Liquid Glass"],
        "paper": ["暖色纸张", "Warm paper", "あたたかい紙"], "white": ["极简白纸", "Clean paper", "白い紙"],
        "motion": ["丰富动画", "Playful motion", "豊かな動き"], "edge": ["鼠标靠近屏幕顶部时展开", "Reveal at the top screen edge", "画面上端で表示"],
        "reminders": ["轻提醒", "Gentle reminders", "そっとお知らせ"],
        "hourly": ["一小时未记录时轻提醒", "Nudge after an hour without a note", "一時間記録がないときにお知らせ"],
        "reminderInfo": ["只在菜单栏显示小标记。没有声音、不抢焦点、不自动弹窗。休眠后重新计时，正在输入时延后。", "Only a small menu bar mark. No sound, focus stealing, or automatic popups. Restarts after sleep and waits while you type.", "メニューバーの小さな印だけ。音や自動ポップアップはありません。スリープ後は再計時し、入力中は待ちます。"],
        "reminderPrompt": ["这一小时，有什么想记下的吗？", "Anything from the past hour worth noting?", "この一時間、書き留めたいことはありますか？"],
        "previewReminder": ["预览轻提醒", "Preview reminder", "お知らせを試す"],
        "dismiss": ["这次先不用", "Not now", "今は大丈夫"], "launch": ["登录时启动", "Launch at login", "ログイン時に起動"],
        "data": ["数据与隐私", "Data & privacy", "データとプライバシー"],
        "localInfo": ["记录仅保存在这台 Mac。无需账号，不联网，不收集使用数据。", "Your journal stays on this Mac. No account, network access, or analytics.", "記録はこの Mac 内だけ。アカウント、通信、利用状況の収集はありません。"],
        "openData": ["打开数据文件夹", "Open data folder", "データフォルダを開く"],
        "backup": ["导出完整备份", "Export full backup", "全データをバックアップ"],
        "shortcut": ["全局快捷键：⌃⌥N 记一行 · ⌃⌥L 展开/收起", "Global shortcuts: ⌃⌥N add a line · ⌃⌥L show/hide", "ショートカット：⌃⌥N 一行メモ · ⌃⌥L 表示切替"],
        "about": ["关于 AetherNote", "About AetherNote", "AetherNote について"], "quit": ["退出 AetherNote", "Quit AetherNote", "AetherNote を終了"],
        "error": ["未能完成操作", "Unable to complete the action", "操作を完了できません"], "ok": ["知道了", "OK", "OK"],
        "saveError": ["记录尚未保存，请检查磁盘空间或数据目录权限。", "Your changes were not saved. Check disk space and folder permissions.", "保存できませんでした。ディスク容量とフォルダの権限を確認してください。"],
        "emptyError": ["先写下一件事吧。", "Write something first.", "まず一つ書いてみましょう。"],
        "longError": ["每条记录最多 4,000 个字符。", "Each entry can contain up to 4,000 characters.", "一件につき 4,000 文字までです。"],
        "clockError": ["日期已经过去，或系统时间被调回；这条便签已只读。", "This date has passed or the clock moved backward. This note is read-only.", "日付が過ぎたか、時刻が戻されました。このメモは閲覧のみです。"],
        "draft": ["未提交的草稿已保留", "Unsubmitted draft preserved", "未送信の下書きを保存しました"],
        "draftToday": ["将草稿带到今天", "Bring draft to today", "下書きを今日へ"],
        "entries": ["条记录", "entries", "件の記録"], "days": ["天", "days", "日間"],
        "more": ["更多", "more", "ほか"], "dragHint": ["拖动可换位 · 松手回弹 · 双击绳子整理", "Drag to rearrange · Release to bounce · Double-click the line to tidy", "ドラッグで並べ替え · 離すと戻る · ひもをダブルクリックで整頓"],
        "readonlyReview": ["按日期排列 · 历史记录已封存", "In date order · Past entries are sealed", "日付順 · 過去の記録は封存済み"],
        "welcome": ["做过的小事，也值得记住。", "Little things, worth remembering.", "小さなことも、残しておこう。"],
        "moveLeft": ["向左移动", "Move left", "左へ移動"], "moveRight": ["向右移动", "Move right", "右へ移動"],
        "version": ["版本", "Version", "バージョン"], "restore": ["从备份恢复…", "Restore backup…", "バックアップを復元…"],
        "restoreWarning": ["备份恢复会替换当前记录。请先导出完整备份。", "Restoring replaces this journal. Export a full backup first.", "復元すると現在の記録が置き換わります。先にバックアップしてください。"]
    ]
    static func text(_ key: String, _ language: Language) -> String {
        guard let row = values[key] else { return key }
        return row[language.resolved == .zh ? 0 : language.resolved == .ja ? 2 : 1]
    }
}
