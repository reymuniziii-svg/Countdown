#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Countdown"
DIST_APP="$ROOT_DIR/dist/$APP_NAME.app"
INSTALL_DIR="/Applications/$APP_NAME.app"
CREATE_ALIAS=true

if [[ "${1:-}" == "--no-alias" ]]; then
    CREATE_ALIAS=false
fi

"$ROOT_DIR/scripts/build-app.sh"

echo "Installing $APP_NAME.app to /Applications..."
rm -rf "$INSTALL_DIR"
cp -R "$DIST_APP" "$INSTALL_DIR"

if $CREATE_ALIAS; then
    /usr/bin/osascript <<APPLESCRIPT
tell application "Finder"
    set desktopFolder to (path to desktop folder)
    if not (exists alias file "Countdown" of desktopFolder) then
        make new alias file at desktopFolder to POSIX file "/Applications/Countdown.app" with properties {name:"Countdown"}
    end if
end tell
APPLESCRIPT
fi

echo "Installed app bundle at:"
echo "$INSTALL_DIR"
