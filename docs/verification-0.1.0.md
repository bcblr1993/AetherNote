# v0.1.0 verification

Release acceptance covers core data invariants, real native UI operation, signed package validation, and public download verification. Native UI checks were performed on an Apple Silicon Mac running macOS 27.0.1. Older macOS native UI, physical multi-display layouts, login-item activation and IME composition need broader device testing; the marked-text guard is implemented but was not exercised by changing the tester's system input method.

## Automated checks

- `swift test`: **13 tests passed**. Multiline Unicode input; midnight append/edit/delete refusal; persisted clock rollback guard; future-date refusal; drag/tidy content invariance; calendar year/DST boundaries; atomic rejection of oversized input; save/backup/corruption protection; quiet reminder timing; date-ordered Markdown; same-day edit/delete; westward timezone travel; recent-activity deferral.
- `python3 scripts/check-localization.py`: all translation rows have Chinese, English and Japanese; literal lookups resolve.
- `bash scripts/build-app.sh`: release build, icon generation, Info.plist validation, .app packaging.
- GitHub Actions: macOS 26 and Xcode 27 runners.

## Native acceptance checklist

- [x] Append multiline Chinese, English, Japanese and emoji via actual native text input and Return.
- [x] Drag a note with the pointer and verify saved display order.
- [x] Tidy and navigate to a prior week with seven notes.
- [x] Open a historical note: no editor, edit menu or append action.
- [x] Inspect the redesigned weekly review in a native window.
- [x] Switch Chinese/English/Japanese and glass/warm-paper materials; inspect layout and fix warm-paper text contrast on a dark system.
- [x] Restart and verify four saved entries and an unsubmitted draft persist; edit today's text through its real native menu.
- [x] Verify the reminder preview does not open a window or change focus.
- [x] Mount the signed DMG, verify its volume name and Applications link, install to Applications, validate the app's staple and signature, and launch v0.1.0 with the preserved journal and draft.

Native UI checks use an isolated `--data-dir`; synthetic sample entries are never included in distributed app bundles.

## Signed candidate

- Apple app notarization: Accepted, submission `a768cd2c-acb9-4236-bbff-05a21c381ea5`.
- Apple DMG notarization: Accepted, submission `9a439681-34f7-426e-8c65-a9c4ed1bf915`.
- App and DMG stapler validation: passed.
- Installed app signature: valid; `syspolicy_check distribution`: passed all pre-distribution checks.
- Host `spctl` reported Notarized Developer ID with an existing security-disabled override. No host security setting was changed; the independent distribution check above passed. This does not claim a fresh Gatekeeper prompt was exercised on a default-configured second Mac.
- Release version 0.1.0, build 2026101201, arm64. The ZIP contains the same stapled app.

Public asset download and SHA-256 verification are the final publication gate, reported on the [release page](https://github.com/bcblr1993/AetherNote/releases/tag/v0.1.0).

## Release gates

1. Tests, localization checks and release build pass; CI is green on the release commit.
2. Developer ID signing with hardened runtime and timestamp.
3. Apple notarization Accepted; app and DMG tickets stapled and validated.
4. `codesign --verify --strict` and Gatekeeper `spctl --assess` pass.
5. Mount DMG: volume AetherNote, AetherNote.app and Applications link; correct version and architecture; installed launch works.
6. Publish versioned DMG, ZIP and SHA256SUMS; download and compare to local approved artifacts.
