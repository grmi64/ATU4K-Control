#!/bin/sh
set -eu
cd "$(dirname "$0")"
APP='dist/ATU4K Control.app'
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp src/index.html src/controller.js src/replies.js src/app.js src/style.css "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.ny6c.ladderline.simulation.preview</string><key>CFBundleName</key><string>ATU4K Control</string><key>CFBundleExecutable</key><string>LadderlineControl</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>0.9.4</string><key>CFBundleVersion</key><string>24</string><key>CFBundleIconFile</key><string>ATU4K</string><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
swiftc -module-cache-path /tmp/ladderline-swift-cache src/DXCBridge.swift src/SettingsBackup.swift src/MacHost.swift src/USBStatus.swift src/MotorGate.swift src/MemoryGate.swift src/USBDiscovery.swift -o "$APP/Contents/MacOS/LadderlineControl" -framework Cocoa -framework WebKit -framework IOKit -framework Network
cp assets/ATU4K.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
