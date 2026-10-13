# AetherNote guide

A native, local-only activity journal for macOS. Write what you did, one line at a time. Each day hangs from a clothesline; every past day remains editable.

## Everyday use

- Click the menu bar note icon to show or hide the line. Click today to write.
- Return appends an entry. Shift + Return inserts a newline; submitting a multiline draft creates one entry per nonempty line. The editor respects marked text during IME composition.
- Today and all past days support adding, editing and deleting entries. Editing can continue in the same note across midnight. Future dates remain unavailable until that day arrives.
- Drag cards horizontally to reorder; vertical movement springs back. Pull the rope, double-click it to tidy, or click the sparkle button. Rearranging never changes journal dates or contents.
- Weekdays appear by default. Enable weekends in Settings; days with weekend entries and today's weekend card always remain visible. At most seven cards appear, and previous weeks remain available.
- Week in review shows entries in date order. Copy the week or export Markdown.
- Control + Option + N opens today's editor; Control + Option + L toggles the line. A conflicting system/app shortcut may prevent registration; menu bar actions are always available.
- The central 360 points of the top screen edge reveal the line. Disable this behavior in Settings or pin the line to keep it visible.

## Appearance and accessibility

Chinese, English, Japanese, or system language. Liquid Glass, warm paper, or clean paper. System dark/light appearance is respected; warm paper stays warm.

The release targets Apple Silicon and macOS 14+. macOS 26 uses native `NSGlassEffectView`; macOS 27 enables its interactive effect. Earlier systems use `NSVisualEffectView`. Reduced motion disables playful animations. Reduced transparency uses an opaque surface, and increased contrast strengthens outlines. Cards expose accessible open and move actions.

## Quiet reminders

After an hour without a new or edited entry, a small mark appears in the menu bar. No sound, notification permission, focus changes, or automatic reminder window. Clicking the mark opens today's editor. Right-click and choose Not now to dismiss it. Disable reminders or preview the mark from Settings.

The policy checks every 15 seconds, postpones during typing or while the editor is active, and resets after waking or returning to an active session. It does not query Focus mode or screen sharing: by using only a menu bar mark, it avoids intrusive interruptions in every mode.

## Backup and recovery

All data lives in `~/Library/Application Support/AetherNote/`. Settings can open that directory or export a full JSON journal backup. Markdown is for reading, not restoration. Drafts and preferences are separate from the full journal export; copy the whole data directory to preserve those too.

To restore manually:

1. Quit AetherNote.
2. Copy the entire existing data directory somewhere safe.
3. Copy the desired exported JSON backup to `journal.json` in the data directory.
4. Reopen AetherNote. Invalid data is rejected without being overwritten.

`journal.previous.json` contains the state before the last successful write, including arrangement writes. Export regular backups; this single rolling copy is not a historical archive.

Starting with v0.1.1, historical notes are editable. Existing v0.1.0 journals load without conversion and their old high-water metadata no longer locks past dates. Editing preserves the entry's ID, creation time and calendar date; the modification time updates. Dates follow the Mac's local Gregorian calendar.

No network connections, account, analytics, cloud sync, or background AI. The files are not encrypted by this app; macOS account permissions and FileVault remain relevant.

## Build and release

Use Xcode 27 for the complete macOS 27 implementation, or Xcode 26 for the macOS 26 API. No third-party runtime dependencies.

```sh
swift test
python3 scripts/check-localization.py
bash scripts/build-app.sh
```

Maintainers can sign and notarize a tested app using `scripts/release.sh`, with `SIGNING_IDENTITY` and `NOTARY_PROFILE` environment variables. Do not put credentials in the repository. If notarization remains In Progress after interruption, use the submission ID to wait for it instead of submitting the same archive again. A release must pass the checks in [verification.md](verification.md).
