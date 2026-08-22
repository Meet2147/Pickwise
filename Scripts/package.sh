#!/usr/bin/env bash
# One-shot release: universal build → sign → notarize → staple → DMG → sign → notarize → staple.
# Usage: Scripts/package.sh [version] [build]
# Requires (once): xcrun notarytool store-credentials "$NOTARY_PROFILE" --apple-id ... --team-id ... --password ...
set -euo pipefail

cd "$(dirname "$0")/.."
APP_NAME="WhosBetter"
VERSION="${1:-$(sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)}"
BUILD="${2:-$(sed -n 's/.*CURRENT_PROJECT_VERSION: "\(.*\)"/\1/p' project.yml)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-WhosBetterNotary}"       # keychain profile name; password never in repo
SIGN_ID="${SIGN_ID:-Developer ID Application: Meet Jethwa (C9NLF34677)}"
SITE_URL="${SITE_URL:-https://whosbetter.app}"

DIST="dist"; ARCHIVE="$DIST/$APP_NAME.xcarchive"; EXPORT="$DIST/export"
APP="$EXPORT/$APP_NAME.app"; DMG="$DIST/$APP_NAME-$VERSION.dmg"
ENTITLEMENTS="$APP_NAME/$APP_NAME.entitlements"

log(){ printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
die(){ printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

command -v xcodegen >/dev/null || die "xcodegen missing (brew install xcodegen)"
command -v create-dmg >/dev/null || die "create-dmg missing (brew install create-dmg)"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || die "Notary profile '$NOTARY_PROFILE' not found. Create it once with: xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id <email> --team-id C9NLF34677 --password <app-specific-password>"

rm -rf "$DIST"; mkdir -p "$DIST"

log "Generating project (v$VERSION build $BUILD)"
xcodegen generate >/dev/null

log "Archiving universal Release build"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
  -archivePath "$ARCHIVE" archive \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="$SIGN_ID" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=C9NLF34677 \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
  | grep -E "error:|warning: .*sign|ARCHIVE" || true
[ -d "$ARCHIVE/Products/Applications/$APP_NAME.app" ] || die "Archive failed"
mkdir -p "$EXPORT"; cp -R "$ARCHIVE/Products/Applications/$APP_NAME.app" "$APP"

log "Re-signing app (Developer ID, hardened runtime, timestamp)"
codesign --force --deep --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" --sign "$SIGN_ID" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP" || die "codesign verify failed"
BIN="$APP/Contents/MacOS/$APP_NAME"
lipo -archs "$BIN" | grep -q "x86_64" && lipo -archs "$BIN" | grep -q "arm64" || die "Not universal: $(lipo -archs "$BIN")"
echo "archs: $(lipo -archs "$BIN")"

log "Notarizing .app"
ditto -c -k --keepParent "$APP" "$DIST/$APP_NAME.zip"
xcrun notarytool submit "$DIST/$APP_NAME.zip" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$DIST/notary-app.json" \
  || { xcrun notarytool log "$(python3 -c 'import json;print(json.load(open("'"$DIST/notary-app.json"'"))["id"])')" --keychain-profile "$NOTARY_PROFILE"; die "App notarization failed"; }
grep -q '"status": *"Accepted"' "$DIST/notary-app.json" || { cat "$DIST/notary-app.json"; die "App notarization not Accepted"; }
xcrun stapler staple "$APP"

log "Building DMG"
create-dmg --volname "$APP_NAME" --window-size 540 380 --icon-size 128 \
  --icon "$APP_NAME.app" 140 170 --app-drop-link 400 170 --no-internet-enable \
  "$DMG" "$EXPORT" >/dev/null
[ -f "$DMG" ] || die "DMG not created"

log "Signing + notarizing DMG"
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$DIST/notary-dmg.json" \
  || die "DMG notarization failed"
grep -q '"status": *"Accepted"' "$DIST/notary-dmg.json" || { cat "$DIST/notary-dmg.json"; die "DMG notarization not Accepted"; }
xcrun stapler staple "$DMG"

log "Gatekeeper verification"
spctl -a -t open --context context:primary-signature -vv "$DMG" 2>&1 | tee "$DIST/spctl.txt"
grep -q "Notarized Developer ID" "$DIST/spctl.txt" || die "Gatekeeper did not accept the DMG"

log "Publishing to Site/"
mkdir -p Site/downloads
cp "$DMG" "Site/downloads/$APP_NAME-$VERSION.dmg"
cp "$DMG" "Site/downloads/$APP_NAME.dmg"   # stable URL for the Download button
NOTES="${NOTES:-Bug fixes and improvements.}"
cat > Site/version.json <<JSON
{
  "build": $BUILD,
  "version": "$VERSION",
  "url": "$SITE_URL/downloads/$APP_NAME-$VERSION.dmg",
  "notes": "$NOTES"
}
JSON

log "Done → $DMG  (size: $(du -h "$DMG" | cut -f1))"
