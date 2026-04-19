#!/bin/bash
set -e

APP_NAME="ZhiPuMonitor"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building $APP_NAME..."
swift build -c release

BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ZhiPuMonitor</string>
    <key>CFBundleIdentifier</key>
    <string>com.zhipu.monitor</string>
    <key>CFBundleName</key>
    <string>ZhiPu Monitor</string>
    <key>CFBundleDisplayName</key>
    <string>智谱用量监控</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo ""
echo "Built: $APP_BUNDLE"
echo "Run: open $APP_BUNDLE"
