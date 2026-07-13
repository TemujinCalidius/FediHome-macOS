#!/usr/bin/env bash
#
# package-macos.sh — build, sign, notarize, and package FediHome for distribution.
#
# Two modes:
#   direct     (default)  → notarized, stapled .dmg for GitHub Releases (Developer ID)
#   appstore              → signed .pkg for App Store Connect upload (Apple Distribution)
#
# Nothing personal is committed: your Team ID, signing identities, and notary
# credentials are read from the environment, and ExportOptions.plist is generated
# at runtime into a temp dir. Run from the repo root.
#
# ── Required environment ────────────────────────────────────────────────────────
#   DEVELOPMENT_TEAM         Your 10-char Apple Team ID (e.g. ABCDE12345)
#
# For notarization (direct mode) — EITHER an App Store Connect API key:
#   NOTARY_KEY_ID            ASC API key id
#   NOTARY_KEY_ISSUER_ID     ASC API issuer id (UUID)
#   NOTARY_KEY_PATH          path to the .p8 private key
# OR a stored notarytool keychain profile:
#   NOTARY_PROFILE           name of a profile created with:
#                            xcrun notarytool store-credentials <name> \
#                              --team-id "$DEVELOPMENT_TEAM" --apple-id you@x --password <app-specific>
#
# ── Optional environment ────────────────────────────────────────────────────────
#   DEVELOPER_ID_APP         signing identity for direct mode
#                            (default: "Developer ID Application")
#   DISTRIBUTION_IDENTITY    signing identity for appstore mode
#                            (default: "Apple Distribution")
#   SCHEME                   xcodebuild scheme (default: FediHome)
#
set -euo pipefail

MODE="${1:-direct}"
SCHEME="${SCHEME:-FediHome}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
ARCHIVE="$BUILD_DIR/FediHome.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_NAME="FediHome"

die() { echo "❌ $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

[[ -n "${DEVELOPMENT_TEAM:-}" ]] || die "DEVELOPMENT_TEAM is required (your Apple Team ID)."
have xcodegen || die "xcodegen not found (brew install xcodegen)."

echo "▸ Regenerating Xcode project"
( cd "$ROOT" && xcodegen generate >/dev/null )

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT/App/Info.plist" 2>/dev/null || echo "0.0.0")"
# Info.plist stores build-variable substitutions, so read the real value from project.yml.
[[ "$VERSION" == *'$'* ]] && VERSION="$(grep -E 'MARKETING_VERSION:' "$ROOT/project.yml" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"

rm -rf "$BUILD_DIR"
mkdir -p "$EXPORT_DIR"

echo "▸ Archiving $SCHEME (Release) — v$VERSION"
if [[ "$MODE" == "direct" ]]; then
  # Sign directly with Developer ID at archive time. Automatic signing would
  # instead demand an "Apple Development" cert (which a Developer-ID-only setup
  # doesn't have) — that's the "No signing certificate Mac Development" failure.
  ARCHIVE_SIGN=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="${DEVELOPER_ID_APP:-Developer ID Application}")
else
  ARCHIVE_SIGN=(CODE_SIGN_STYLE=Automatic)   # App Store: needs Apple Distribution + a dev cert
fi
xcodebuild archive \
  -project "$ROOT/FediHome.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  "${ARCHIVE_SIGN[@]}" \
  | tail -3

case "$MODE" in
  direct)
    # The archived app is already Developer-ID-signed (hardened runtime +
    # entitlements from the project), so collect it straight from the archive —
    # no exportArchive re-sign step (which is where automatic signing crept in).
    APP="$EXPORT_DIR/$APP_NAME.app"
    rm -rf "$APP"
    cp -R "$ARCHIVE/Products/Applications/$APP_NAME.app" "$APP"
    [[ -d "$APP" ]] || die "archive did not contain $APP_NAME.app"

    echo "▸ Verifying Developer ID signature + hardened runtime"
    codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | sed 's/^/    /' \
      || die "signature verification failed"
    codesign -dvv "$APP" 2>&1 | grep -E "Authority=Developer ID|runtime" | sed 's/^/    /' || true

    NOTARY_ARGS=()
    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
      NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
    elif [[ -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_KEY_ISSUER_ID:-}" && -n "${NOTARY_KEY_PATH:-}" ]]; then
      NOTARY_ARGS=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_KEY_ISSUER_ID")
    else
      die "notary creds missing: set NOTARY_PROFILE, or NOTARY_KEY_ID + NOTARY_KEY_ISSUER_ID + NOTARY_KEY_PATH."
    fi

    # Notarize the APP first, then staple it — so the app that ends up inside the
    # DMG is itself stapled (works offline). Then notarize + staple the DMG. The
    # DMG must be the exact file that was submitted, so it is NOT rebuilt afterward.
    echo "▸ Notarizing the app (a few minutes)"
    APP_ZIP="$BUILD_DIR/$APP_NAME.zip"
    ditto -c -k --keepParent "$APP" "$APP_ZIP"
    xcrun notarytool submit "$APP_ZIP" "${NOTARY_ARGS[@]}" --wait
    echo "▸ Stapling the app"
    xcrun stapler staple "$APP"

    echo "▸ Building DMG (with the stapled app)"
    DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
    STAGE="$BUILD_DIR/dmg"
    rm -rf "$STAGE"; mkdir -p "$STAGE"
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGE" \
      -ov -format UDZO "$DMG" >/dev/null

    echo "▸ Notarizing the DMG (a few minutes)"
    xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait
    echo "▸ Stapling the DMG"
    xcrun stapler staple "$DMG"

    echo "▸ Verifying Gatekeeper acceptance"
    spctl -a -vvv --type install "$DMG" 2>&1 | sed 's/^/    /' || true
    spctl -a -vvv "$APP" 2>&1 | sed 's/^/    /' || true

    echo
    echo "✅ Done: $DMG"
    echo "   Attach it to the GitHub Release:  gh release create v$VERSION \"$DMG\" ..."
    ;;

  appstore)
    cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$DEVELOPMENT_TEAM</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST

    echo "▸ Exporting App Store package (.pkg)"
    xcodebuild -exportArchive \
      -archivePath "$ARCHIVE" \
      -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
      -exportPath "$EXPORT_DIR" | tail -3

    PKG="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.pkg' | head -1)"
    [[ -n "$PKG" ]] || die "export failed: no .pkg produced."
    echo
    echo "✅ Done: $PKG"
    echo "   Upload to App Store Connect with Transporter, or:"
    echo "   xcrun notarytool submit is NOT needed for App Store; use:"
    echo "   xcrun altool --upload-app -f \"$PKG\" -t macos --apiKey \$NOTARY_KEY_ID --apiIssuer \$NOTARY_KEY_ISSUER_ID"
    ;;

  *)
    die "unknown mode '$MODE' (use 'direct' or 'appstore')."
    ;;
esac
