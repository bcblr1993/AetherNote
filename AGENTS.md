# AetherNote

- Native macOS app: SwiftUI/AppKit, Swift Package Manager, no production dependencies.
- Run `swift test`, `swift build -c release`, and `scripts/build-app.sh` before release.
- Never mutate a past day's entries. Enforce this in the core transaction, not just the UI.
- Arrangement changes may affect historical cards, but must never alter entries or dates.
- Use an isolated `--data-dir` for QA. Do not populate a real user's journal with samples.
- All visible strings must have Chinese, English, and Japanese translations.
- Reminders must not activate the app, play sound, or open a window automatically.
- Honor Reduce Motion and Increase Contrast/Reduce Transparency.
- A release requires Developer ID signing, notarization, stapling, install checks, tests and remote asset verification. Never publish credentials, private notes, or QA state.
