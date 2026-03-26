#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Countdown"
DIST_APP="$ROOT_DIR/dist/$APP_NAME.app"
INSTALL_DIR="/Applications/$APP_NAME.app"
DESKTOP_APP="$HOME/Desktop/$APP_NAME.app"
CREATE_ALIAS=true

if [[ "${1:-}" == "--no-alias" ]]; then
    CREATE_ALIAS=false
fi

"$ROOT_DIR/scripts/build-app.sh"

echo "Installing $APP_NAME.app to /Applications..."
rm -rf "$INSTALL_DIR"
cp -R "$DIST_APP" "$INSTALL_DIR"

if $CREATE_ALIAS; then
    if [[ -L "$DESKTOP_APP" ]]; then
        rm -f "$DESKTOP_APP"
    elif [[ -e "$DESKTOP_APP" ]]; then
        BACKUP_PATH="$DESKTOP_APP.backup-$(date +%Y%m%d-%H%M%S)"
        mv "$DESKTOP_APP" "$BACKUP_PATH"
        echo "Backed up existing Desktop app to:"
        echo "$BACKUP_PATH"
    fi

    ln -s "$INSTALL_DIR" "$DESKTOP_APP"
fi

echo "Installed app bundle at:"
echo "$INSTALL_DIR"
