"""Check every translation row and every literal localization lookup."""
import pathlib, re
root = pathlib.Path(__file__).resolve().parents[1]
source = (root / "Sources/AetherNote/Localization.swift").read_text()
rows = re.findall(r'"([A-Za-z]+)": \[([^\]]+)\]', source)
assert rows
keys = set()
for key, row in rows:
    assert key not in keys, f"Duplicate localization: {key}"
    keys.add(key)
    assert len(re.findall(r'"(?:[^"\\]|\\.)*"', row)) == 3, key
for file in (root / "Sources/AetherNote").glob("*.swift"):
    for key in re.findall(r'\.l\("([A-Za-z]+)"\)', file.read_text()):
        assert key in keys, f"Missing {key} in {file.name}"
print(f"Validated {len(keys)} trilingual strings and all literal lookup sites.")
