# v0.1.0 verification

Release acceptance covers core data invariants, real native UI operation, signed package validation, and public download verification. This file is updated with actual results before publication.

## Automated checks

- `swift test`: multiline Unicode input; midnight append/edit/delete refusal; persisted clock rollback guard; future-date refusal; drag/tidy content invariance; calendar year/DST boundaries; atomic rejection of oversized input; save/backup/corruption protection; quiet reminder timing; date-ordered Markdown.
- `python3 scripts/check-localization.py`: all translation rows have Chinese, English and Japanese; literal lookups resolve.
- `bash scripts/build-app.sh`: release build, icon generation, Info.plist validation, .app packaging.
- GitHub Actions: macOS 26 and Xcode 27 runners.

## Native acceptance checklist

- [x] Append multiline Chinese, English, Japanese and emoji via actual native text input and Return.
- [x] Drag a note with the pointer and verify saved display order.
- [x] Tidy and navigate to a prior week with seven notes.
- [x] Open a historical note: no editor, edit menu or append action.
- [x] Inspect the redesigned weekly review in a native window.
- [ ] Switch language and material; inspect layout.
- [ ] Restart and verify content/draft persistence.
- [ ] Verify the reminder preview does not open a window or change focus.
- [ ] Install signed artifact, validate notarization, and launch it.
- [ ] Download published assets and compare SHA-256 checksums.

Native UI checks use an isolated `--data-dir`; synthetic sample entries are never included in distributed app bundles.

## Release gates

1. Tests, localization checks and release build pass; CI is green on the release commit.
2. Developer ID signing with hardened runtime and timestamp.
3. Apple notarization Accepted; app and DMG tickets stapled and validated.
4. `codesign --verify --strict` and Gatekeeper `spctl --assess` pass.
5. Mount DMG: volume AetherNote, AetherNote.app and Applications link; correct version and architecture; installed launch works.
6. Publish versioned DMG, ZIP and SHA256SUMS; download and compare to local approved artifacts.
