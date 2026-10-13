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
        "unsavedEdit": ["请先保存或取消当前修改，再离开这一天。", "Save or cancel your current edit before leaving this day.", "この日を閉じる前に、変更を保存またはキャンセルしてください。"],
        "recordedDays": ["已记录", "Days captured", "記録した日"],
        "weekOverview": ["一周的小事，都在这里。", "Your week, one little thing at a time.", "一週間の小さなできごとを、ここに。"],
        "settingsHint": ["让记录更贴合你的习惯。", "A little space, made yours.", "自分に合った、記録の場所に。"],
        "appUpdates": ["应用更新", "App updates", "アプリの更新"],
        "savedLocally": ["保存在这台 Mac", "Saved on this Mac", "この Mac に保存"],
        "editMenu": ["编辑", "Edit", "編集"], "undo": ["撤销", "Undo", "取り消す"],
        "cut": ["剪切", "Cut", "切り取り"], "copyMenu": ["复制", "Copy", "コピー"],
        "paste": ["粘贴", "Paste", "ペースト"], "selectAll": ["全选", "Select All", "すべてを選択"],
        "today": ["今天", "Today", "今日"], "editable": ["可编辑", "Editable", "編集可能"],
        "future": ["尚未开始", "Not yet", "まだ先"], "empty": ["今天做了什么？", "What did you do today?", "今日は何をしましたか？"],
        "noEntries": ["这一天没有记录", "No entries for this day", "この日の記録はありません"],
        "add": ["记一行", "Add a line", "一行メモ"], "append": ["追加一行", "Add line", "一行追加"],
        "placeholder": ["再记一件做过的事…", "One more thing you did…", "もう一つ、書き留める…"],
        "inputHint": ["回车追加 · Shift + 回车换行", "Return to add · Shift + Return for a new line", "Return で追加 · Shift + Return で改行"],
        "edit": ["修改", "Edit", "編集"], "save": ["保存修改", "Save edit", "変更を保存"],
        "cancel": ["取消", "Cancel", "キャンセル"], "delete": ["删除这一行", "Delete entry", "この記録を削除"],
        "deleteConfirm": ["删除这条记录？", "Delete this entry?", "この記録を削除しますか？"],
        "historyHint": ["随时补充或修改这一天的记录。", "Add to or edit this day whenever you like.", "この日の記録はいつでも追加・編集できます。"],
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
        "localInfo": ["记录仅保存在这台 Mac。无需账号，不收集使用数据；检查更新时联网，不发送日记内容。", "Your journal stays on this Mac. No account or analytics. Update checks use the network without sending your notes.", "記録はこの Mac 内だけ。アカウントや利用状況の収集はありません。更新確認時のみ通信し、メモは送信しません。"],
        "checkUpdates": ["检查更新…", "Check for Updates…", "アップデートを確認…"],
        "updateInfo": ["手动检查，下载后安装并重新启动。不会自动下载或重启。更新窗口跟随系统语言。", "Check manually, then download, install and relaunch. No automatic downloads or restarts. Update windows follow the system language.", "手動で確認し、ダウンロード後にインストールして再起動します。自動ダウンロードや再起動はしません。更新画面はシステムの言語に従います。"],
        "unsavedUpdateEdit": ["请先保存或取消当前修改，再退出或安装更新。", "Save or cancel the current edit before quitting or installing the update.", "終了または更新する前に、編集中の変更を保存またはキャンセルしてください。"],
        "openData": ["打开数据文件夹", "Open data folder", "データフォルダを開く"],
        "backup": ["导出完整备份", "Export full backup", "全データをバックアップ"],
        "shortcut": ["全局快捷键：⌃⌥N 记一行 · ⌃⌥L 展开/收起", "Global shortcuts: ⌃⌥N add a line · ⌃⌥L show/hide", "ショートカット：⌃⌥N 一行メモ · ⌃⌥L 表示切替"],
        "about": ["关于 AetherNote", "About AetherNote", "AetherNote について"], "quit": ["退出 AetherNote", "Quit AetherNote", "AetherNote を終了"],
        "error": ["未能完成操作", "Unable to complete the action", "操作を完了できません"], "ok": ["知道了", "OK", "OK"],
        "saveError": ["记录尚未保存，请检查磁盘空间或数据目录权限。", "Your changes were not saved. Check disk space and folder permissions.", "保存できませんでした。ディスク容量とフォルダの権限を確認してください。"],
        "emptyError": ["先写下一件事吧。", "Write something first.", "まず一つ書いてみましょう。"],
        "longError": ["每条记录最多 4,000 个字符。", "Each entry can contain up to 4,000 characters.", "一件につき 4,000 文字までです。"],
        "futureError": ["这一天还没到，暂时不能记录。", "This date is in the future. Come back on that day.", "未来の日付にはまだ記録できません。"],
        "draft": ["未提交的草稿已保留", "Unsubmitted draft preserved", "未送信の下書きを保存しました"],
        "draftToday": ["将草稿带到今天", "Bring draft to today", "下書きを今日へ"],
        "entry": ["条记录", "entry", "件の記録"],
        "entries": ["条记录", "entries", "件の記録"], "days": ["天", "days", "日間"],
        "more": ["更多", "more", "ほか"], "dragHint": ["拖动可换位 · 松手回弹 · 双击绳子整理", "Drag to rearrange · Release to bounce · Double-click the line to tidy", "ドラッグで並べ替え · 離すと戻る · ひもをダブルクリックで整頓"],
        "reviewHint": ["按日期排列 · 可随时回到便签继续编辑", "In date order · Return to any note to keep editing", "日付順 · メモに戻っていつでも編集できます"],
        "welcome": ["做过的小事，也值得记住。", "Little things, worth remembering.", "小さなことも、残しておこう。"],
        "moveLeft": ["向左移动", "Move left", "左へ移動"], "moveRight": ["向右移动", "Move right", "右へ移動"],
        "version": ["版本", "Version", "バージョン"], "restore": ["从备份恢复…", "Restore backup…", "バックアップを復元…"],
        "colorHex": ["十六进制颜色", "Hex color", "16進数カラー"],
        "colorHexHint": ["请输入六位颜色值，例如 #709DB9。", "Enter six hex digits, such as #709DB9.", "#709DB9 のように6桁の値を入力してください。"],
        "colorPending": ["预览中 · 待应用", "Preview · not applied", "プレビュー・未適用"],
        "dayColor": ["便签颜色", "Note color", "メモの色"],
        "colorPersonal": ["自选颜色", "Personal", "自分の色"],
        "colorAutomatic": ["自动配色", "Automatic", "おまかせ"],
        "colorPreview": ["效果预览", "PREVIEW", "プレビュー"],
        "customColor": ["自定义颜色", "Custom color", "カスタムカラー"],
        "applyColor": ["应用", "Apply", "適用"],
        "randomColor": ["换个随机颜色", "Surprise me", "ランダムに変える"],
        "colorSaved": ["自动保存", "Saved automatically", "自動保存"],
        "colorHint": ["颜色只属于这一天。换周、拖动和重新打开都会保留。", "A color for this day. It stays with the date when you rearrange, switch weeks or reopen the app.", "この日だけの色です。並べ替え、週の切り替え、再起動後も変わりません。"],
        "colorSea": ["雾蓝", "Mist", "ミスト"],
        "colorSage": ["鼠尾草", "Sage", "セージ"],
        "colorIris": ["鸢尾", "Iris", "アイリス"],
        "colorRose": ["玫瑰", "Rose", "ローズ"],
        "colorHoney": ["蜜糖", "Honey", "ハニー"],
        "colorPeach": ["杏桃", "Apricot", "アプリコット"],
        "colorLagoon": ["浅湾", "Lagoon", "ラグーン"],
        "colorSlate": ["岩灰", "Slate", "スレート"],
        "restoreWarning": ["备份恢复会替换当前记录。请先导出完整备份。", "Restoring replaces this journal. Export a full backup first.", "復元すると現在の記録が置き換わります。先にバックアップしてください。"]
    ]
    static func text(_ key: String, _ language: Language) -> String {
        guard let row = values[key] else { return key }
        return row[language.resolved == .zh ? 0 : language.resolved == .ja ? 2 : 1]
    }
}
