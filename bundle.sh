#!/bin/bash
set -e

APP_NAME="BlockedBySquare"
APP_DIR="${APP_NAME}.app"
BINARY_PATH=".build/release/${APP_NAME}"

echo "Building release binary..."
swift build -c release

echo "Creating .app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BINARY_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Write Info.plist before signing so it gets bound into the signature
cat > "${APP_DIR}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>BlockedBySquare</string>
    <key>CFBundleIdentifier</key>
    <string>com.blockedbysquare.app</string>
    <key>CFBundleName</key>
    <string>BlockedBySquare</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Signing app bundle..."
# Use a designated requirement based only on bundle identifier (not binary hash).
# Without this, every rebuild changes the cdhash → TCC invalidates the permission.
codesign --force --deep --sign - \
  --requirements "=designated => identifier \"com.blockedbysquare.app\"" \
  "${APP_DIR}"

echo ""
echo "✅  Done! App bundle created: ${APP_DIR}"
echo ""
echo "First run: open ${APP_DIR}"
echo "  → It will ask for Accessibility permission — grant it, then reopen."
echo ""
echo "Usage:"
echo "  • App activates instantly — your screen is now protected"
echo "  • Press ESC to stop + lock your Mac"
