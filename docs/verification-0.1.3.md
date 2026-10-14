# v0.1.3 verification

Prepared on 2026-10-13 on Apple silicon, macOS 27.0.1 and Xcode 27. Previous report: [v0.1.2](verification-0.1.2.md).

## Automated checks

- `swift test`: 21 tests pass, including legacy journal decoding, stable weekly colors, unique automatic colors, custom color persistence and backup, malformed color rejection, unchanged entries/exports during appearance changes, and future-day write protection.
- `python3 scripts/check-localization.py`: 110 complete Chinese/English/Japanese rows and literal lookup sites validated.
- Release build and `scripts/check-updater.py` pass. Signed update feed, embedded Sparkle helpers and manual-only update policy remain unchanged.

## Native UI acceptance

- Custom/preset/random colors, preview before Apply, invalid HEX disabling Apply, persistence through restarts, and date-bound color preservation through move/tidy were checked using isolated data.
- Chinese/glass, English/white and Japanese/paper color panels were visually inspected. The light popup correctly uses a light background even when the system is dark.
- The visible This week controls returned from 26 weeks in the past and 26 weeks in the future. Weekly review return also passed. The journal stayed byte-for-byte unchanged.
- Detailed feature checks: [daily colors](verification-daily-colors.md).

## Release gates

The publication workflow signs, notarizes and staples app and DMG, checks the mounted DMG contents, signs the final DMG for Sparkle, and verifies public assets, website, appcast and a real update from the published v0.1.2. Final publication evidence is retained separately and attached to the release process; preparation alone is not a claim that all public gates passed.

Versions 0.1.0 and 0.1.1 require one manual installation of v0.1.2 or later. Version 0.1.2 can update in the app while retaining local notes and drafts.

This is host-Mac acceptance. No claim is made for new physical multi-display, Intel or older-macOS UI acceptance. Accessibility preferences and host Gatekeeper policy were not changed. Developer ID, notarization and `syspolicy_check distribution` are checked independently.
