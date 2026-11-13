#!/bin/bash
# Builds the plugin binary + icons into it.alese.ears.sdPlugin (Apple Silicon).
set -euo pipefail
cd "$(dirname "$0")"
OUT=it.alese.ears.sdPlugin
mkdir -p "$OUT/imgs"
swiftc -O -target arm64-apple-macos11 Sources/main.swift -o "$OUT/ears-streamdeck"
swift scripts/icons.swift "$OUT/imgs"
echo "Built $OUT"
