#!/bin/bash
# Builds and packages release artifacts into dist/.
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
rm -rf dist && mkdir dist
npx -y @elgato/cli@1.10.4 pack it.alese.ears.sdPlugin -o dist --no-update-check
ditto -c -k --keepParent it.alese.ears.sdPlugin dist/it.alese.ears.sdPlugin.zip
ls -la dist
