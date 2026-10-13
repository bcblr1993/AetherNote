# v0.1.1 verification

Validated on 2026-10-13 using an Apple Silicon Mac running macOS 27.0.1 and Xcode 27. The [v0.1.0 report](verification-0.1.0.md) is retained as a historical record; its sealed-day policy was replaced in v0.1.1.

## Feature and build checks

- `swift test`: 13 tests passed. Coverage includes past-day append/edit/delete after midnight, legacy file compatibility, preservation of entry identity and creation time, future-date refusal, date-ordered exports, arrangement invariance, persistence/corruption handling, calendar boundaries and quiet reminder timing.
- `python3 scripts/check-localization.py`: all 80 translation rows include Chinese, English and Japanese; literal lookups resolve.
- `bash scripts/build-app.sh`: release build, icon generation and app packaging passed.
- The GitHub Actions workflow runs tests, release packaging and localization checks on macOS 26 and Xcode 27 runners. Publication requires a green run for the release commit.

## Native UI acceptance

- Opened yesterday's note and appended a line through native text input and Return.
- Edited an existing historical entry using its menu and Save button.
- Verified historical cards now say Editable, and weekly review no longer says read-only or shows historical lock icons.
- Captured actual glass editor and warm-paper clothesline/review windows with isolated sample data.
- Mounted the final DMG: volume `AetherNote`, containing `AetherNote.app` and an `Applications` symlink.
- Copied the app from the mounted DMG into an isolated installation directory, verified its signature and staple, and launched it against the same QA journal.
- Confirmed the historical addition and edited text survived the restart and remained editable.

QA used an explicit `--data-dir`. The user's normal data directory was not seeded or modified. Distributed app bundles contain no sample journal. Older macOS UI, physical multi-display arrangements, login-item activation and IME composition require broader device testing; the input-method setting was not changed for this release.

## Signed candidate

- Version **0.1.1**, build **2026101301**, **arm64**, minimum macOS 14.
- Developer ID signing with hardened runtime and secure timestamp.
- App notarization Accepted: `bb93eec8-b785-40a3-955b-6fa7d235452c`.
- DMG notarization Accepted: `a3396584-ea46-404a-b912-99f323fb4ee8`.
- App and DMG staple validation passed; installed app signature validation and `syspolicy_check distribution` passed.
- Host `spctl` reported Notarized Developer ID with an existing security-disabled override. No host security setting was changed. This does not claim a default-configured second Mac's first-launch Gatekeeper prompt was exercised.
- DMG SHA-256: `2de446c4162476e9ba0c6397d467be87e5ee19bcee124440cb4d48c954a49d04`.
- ZIP SHA-256: `4f0f5a97b6d42b5bce1610633304ca426db279b6b6ec13f4b550b10ee50b131a`.

## Publication gates

1. Tests, localization, build, native feature checks and release-commit CI pass.
2. Sign, notarize, staple, mount and launch the packaged app.
3. Publish DMG, ZIP and SHA256SUMS under the versioned GitHub release.
4. Download public assets without GitHub authentication and compare SHA-256 values with the approved local files.
5. Update the website and verify its deployed product page, version metadata and download link.

Final publication results are recorded on the [v0.1.1 release page](https://github.com/bcblr1993/AetherNote/releases/tag/v0.1.1).
