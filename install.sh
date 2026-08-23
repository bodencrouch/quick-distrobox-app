#!/usr/bin/env bash
# Symlinks the CLI onto the host PATH at ~/.local/bin/quick-distrobox-app.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"
TARGET="$LOCAL_BIN/quick-distrobox-app"

mkdir -p "$LOCAL_BIN"
ln -sf "$SCRIPT_DIR/bin/quick-distrobox-app" "$TARGET"
echo "Linked $TARGET -> $SCRIPT_DIR/bin/quick-distrobox-app"

case ":$PATH:" in
	*":$LOCAL_BIN:"*) ;;
	*) echo "Note: $LOCAL_BIN is not on your PATH — add it in your shell profile." ;;
esac

echo "Run: quick-distrobox-app ensure claude-desktop"
