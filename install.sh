#!/bin/bash
# Symlinks the plugin into Stream Deck and restarts the app.
set -euo pipefail
cd "$(dirname "$0")"
DEST="$HOME/Library/Application Support/com.elgato.StreamDeck/Plugins/it.alese.ears.sdPlugin"
[ -e "$DEST" ] || ln -s "$PWD/it.alese.ears.sdPlugin" "$DEST"
osascript -e 'quit app "Elgato Stream Deck"' || true
sleep 2
open -a "Elgato Stream Deck"
