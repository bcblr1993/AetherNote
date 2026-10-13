# AetherNote

- Native macOS app: SwiftUI/AppKit and Swift Package Manager. Sparkle is the only production dependency, used for signed in-app updates.
- Run `swift test`, `swift build -c release`, and `scripts/build-app.sh` before release.
- Today and all past days support append, edit and delete. Future dates remain unavailable. Preserve v0.1.0 journal compatibility.
- Arrangement changes may affect historical cards, but must never alter entries or dates.
- Use an isolated `--data-dir` for QA. Do not populate a real user's journal with samples.
- All visible strings must have Chinese, English, and Japanese translations.
- Reminders must not activate the app, play sound, or open a window automatically.
- Honor Reduce Motion and Increase Contrast/Reduce Transparency.
- A release requires Developer ID signing, notarization, stapling, install checks, tests and remote asset verification. Never publish credentials, private notes, or QA state.

- Use Conventional Commits without emojis, with narrowly scoped changes.
