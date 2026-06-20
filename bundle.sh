#!/bin/bash
set -e

APP_NAME="BlockedBySquare"
APP_DIR="${APP_NAME}.app"
BINARY_PATH=".build/release/${APP_NAME}"
DO_RUN=false
DO_TEST=false
DO_RESET=false
DO_RELEASE=false

for arg in "$@"; do
  case "$arg" in
    --run)  DO_RUN=true ;;
    --settings) DO_TEST=true ;;
    --reset) DO_RESET=true ;;
    --release) DO_RELEASE=true ;;
  esac
done

echo "Building release binary..."
swift build -c release

echo "Creating .app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BINARY_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

OPEN_SETTINGS_KEY=""
if $DO_TEST; then
  OPEN_SETTINGS_KEY=$'\n    <key>BlockedBySquareOpenSettingsOnLaunch</key>\n    <true/>'
fi

# Write Info.plist before signing so it gets bound into the signature
cat > "${APP_DIR}/Contents/Info.plist" << EOF
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
    <true/>${OPEN_SETTINGS_KEY}
</dict>
</plist>
EOF

if $DO_RELEASE; then
  # Release: Developer ID + Hardened Runtime + notarize + staple.
  : "${DEVID_IDENTITY:?set DEVID_IDENTITY, e.g. \"Developer ID Application: Name (TEAMID)\"}"
  : "${APPLE_ID:?set APPLE_ID (Apple Developer account email)}"
  : "${TEAM_ID:?set TEAM_ID (10-char team identifier)}"
  # Prompt for the app-specific password — never written to disk or shell history.
  if [ -z "$APP_PW" ]; then
    read -rsp "App-specific password (from appleid.apple.com): " APP_PW
    echo ""
  fi

  echo "Signing with Hardened Runtime..."
  codesign --force --options runtime --timestamp \
    --sign "$DEVID_IDENTITY" "${APP_DIR}"

  echo "Notarizing (this can take a few minutes)..."
  ditto -c -k --keepParent "${APP_DIR}" "${APP_NAME}.zip"
  xcrun notarytool submit "${APP_NAME}.zip" \
    --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$APP_PW" --wait
  rm -f "${APP_NAME}.zip"

  echo "Stapling ticket..."
  xcrun stapler staple "${APP_DIR}"

  echo ""
  echo "✅  Release ready (signed + notarized + stapled): ${APP_DIR}"
  echo "    Verify: spctl -a -vvv -t install ${APP_DIR}"
  exit 0
fi

echo "Signing app bundle..."
# Use a designated requirement based only on bundle identifier (not binary hash).
# Without this, every rebuild changes the cdhash → TCC invalidates the permission.
codesign --force --deep --sign - \
  --requirements "=designated => identifier \"com.blockedbysquare.app\"" \
  "${APP_DIR}"

echo ""
echo "✅  Done! App bundle created: ${APP_DIR}"
echo ""

ARGS=""
if $DO_RESET; then
  ARGS="--args --reset"
fi

if $DO_RUN || $DO_TEST; then
  echo "Launching ${APP_DIR}..."
  open "${APP_DIR}" ${ARGS}
else
  echo "First run: open ${APP_DIR}"
  echo "  → It will ask for Accessibility permission — grant it, then reopen."
fi
echo ""
echo "Usage:"
echo "  • App activates instantly — your screen is now protected"
echo "  • Press ESC to stop + lock your Mac"
