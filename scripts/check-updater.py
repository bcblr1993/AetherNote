#!/usr/bin/env python3
"""Validate the packaged updater, not only the Swift sources."""
import base64
import pathlib
import plistlib
import subprocess
import sys

app = pathlib.Path(sys.argv[1])
info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
assert info["SUFeedURL"] == "https://aethernative.com/apps/aethernote/appcast.xml"
assert len(base64.b64decode(info["SUPublicEDKey"], validate=True)) == 32
assert info["SUVerifyUpdateBeforeExtraction"] is True
for key in ("SUEnableAutomaticChecks", "SUAllowsAutomaticUpdates", "SUAutomaticallyUpdate", "SUSendProfileInfo"):
    assert info[key] is False, key
framework = app / "Contents/Frameworks/Sparkle.framework"
for component in ("Sparkle", "XPCServices/Installer.xpc", "XPCServices/Downloader.xpc", "Autoupdate", "Updater.app"):
    assert (framework / "Versions/B" / component).exists(), component
assert (app / "Contents/Resources/Sparkle-LICENSE").is_file()
executable = app / "Contents/MacOS/AetherNote"
linked = subprocess.check_output(["otool", "-L", str(executable)], text=True)
assert "@rpath/Sparkle.framework" in linked
load_commands = subprocess.check_output(["otool", "-l", str(executable)], text=True)
assert "@executable_path/../Frameworks" in load_commands
print("Packaged Sparkle framework, update feed configuration, manual update policy and runtime path: PASS")
