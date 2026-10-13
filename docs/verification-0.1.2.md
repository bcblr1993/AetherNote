# v0.1.2 verification

Validated on 2026-10-13 on Apple silicon, macOS 27.0.1 and Xcode 27. Previous reports: [v0.1.1](verification-0.1.1.md), [v0.1.0](verification-0.1.0.md).

## Automated checks

- `swift test`: 15 tests pass, including journal compatibility, editing past days, future-date refusal, arrangement invariance, calendar boundaries, persistence and quiet reminder timing.
- Update relaunch tests verify matching installation paths, single-use consumption and expiration of an explicit QA data directory.
- `python3 scripts/check-localization.py`: 89 complete Chinese/English/Japanese rows and all literal lookup sites validated.
- Release build and `scripts/check-updater.py` pass: framework/helper embedding, runtime path, public key, HTTPS feed configuration, verification before extraction and manual-only update policy.

## Native interface acceptance

- Redesigned clothesline toolbar/cards, day editor, weekly review and grouped settings using native glass, unified controls and accessible opaque fallbacks.
- Appended multiple lines through native input and Return; edited and saved a record; appended to yesterday's journal from the review page.
- Closing a window with a dirty inline edit shows a guard alert and retains the text. Save returns to the record list. Command-W closes a saved editor.
- Weekly day navigation scrolls to the selected date; copy shows confirmation; opening a past day from review presents an editable journal.
- Dragged a card to another position, verified changed order, then used Tidy to restore chronological order.
- Settings language selection changes immediately between Chinese, English and Japanese. Inspected translated layouts, material selection, reminder preview and backup save dialog. No login-item setting was changed on the host.
- Screenshots under `docs/images` use isolated demonstration data. No production journal was seeded or modified.

## In-app update acceptance

Sparkle 2.10.0 manages signed archive verification, installation and relaunch. Manual checks are available from Settings and the application/status menus. Update windows use the system language. Daily notes and drafts are not sent with update requests; system profiling and automatic checks/downloads are disabled.

Before the UI redesign, an isolated, lower-build updater-enabled QA installation completed discovery, download, Ed25519 verification, installation and automatic relaunch into build 2026101302. The installed executable matched the packaged executable, and journal, previous-journal and draft SHA-256 values were unchanged. A missing-feed request also showed a recoverable native error.

**Bootstrap limitation:** public v0.1.0 and v0.1.1 contain no updater. They require one manual installation of v0.1.2. The QA baseline is not represented as a public v0.1.1 installation.

## Scope and limitations

This is native host-Mac acceptance, not a claim of physical multi-display, Intel, older macOS or input-method-composition acceptance. Reduce Motion, Reduce Transparency and Increase Contrast have code paths; host accessibility preferences were not changed for this round. Host Gatekeeper has an existing security-disabled override; `syspolicy_check distribution` is checked independently and no security setting is changed.

Signed package metadata and final publication results are recorded on the [release page](https://github.com/bcblr1993/AetherNote/releases/tag/v0.1.2).
