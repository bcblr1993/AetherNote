# Daily colors — development verification

Date: 2026-10-13. This change is on main and has not been published as a binary release.

## Behavior

- Eight muted presets, a native color picker and six-digit HEX entry, preview before custom Apply, and a different random preset on request.
- The automatic weekly palette is derived deterministically from the Monday date; its seven colors are distinct and stable across processes. Manual/random overrides are persisted by date in the journal, including JSON backups. No notes are created just by viewing a week or coloring a future day.
- The same tint appears on the clothesline, clip, editor and weekly review. macOS 26+ also receives the native glass tint; text remains neutral. Reduced motion disables color transitions.
- Legacy journals without color metadata remain valid. Invalid dates/RGB/HEX values are rejected. Color changes and arrangement changes preserve entries, timestamps and Markdown exports.

## Checks completed

- `swift test`: 21 tests pass, including six focused color tests.
- `scripts/build-app.sh`: release build, app bundle, deep ad-hoc signature and Sparkle package/configuration checks pass.
- `python3 scripts/check-localization.py`: 110 trilingual strings and literal lookup sites validated.
- Native macOS UI in an isolated `--data-dir`: preset selection, custom `#7A93C8` Apply, invalid `#XYZ` disabling Apply, random-color return to automatic mode, and color persistence through quit/reopen.
- Real clothesline move and tidy actions preserve the saved color map and entries; order changes as expected. Editor and weekly review visually inspected.
- Chinese/glass, English/white and Japanese/paper color panels visually inspected. Fixed a light-material popup inheriting a dark system background; the corrected light popup was rechecked. English singular entry count corrected.

## Boundaries

This is feature/build/UI verification, not a new signed/notarized release or a new website deployment. The new system color well is present; the completed arbitrary-color acceptance used HEX input. The host accessibility preferences were not changed, so this is not a new full accessibility-mode acceptance matrix.
