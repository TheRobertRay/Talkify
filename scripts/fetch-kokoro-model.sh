#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESTINATION="$ROOT/Talkify/Models/kokoro-en-v0_19"
URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-en-v0_19.tar.bz2"

if [[ -f "$DESTINATION/model.onnx" && -f "$DESTINATION/voices.bin" ]]; then
  exit 0
fi

ARCHIVE="$(mktemp -t kokoro-en-v0_19).tar.bz2"
STAGING="$(mktemp -d -t kokoro-en-v0_19)"
trap 'rm -f "$ARCHIVE"; rm -rf "$STAGING"' EXIT

curl -L --fail --retry 3 --output "$ARCHIVE" "$URL"
tar -xjf "$ARCHIVE" -C "$STAGING"
mkdir -p "$(dirname "$DESTINATION")"
mv "$STAGING/kokoro-en-v0_19" "$DESTINATION"

test -f "$DESTINATION/model.onnx"
test -f "$DESTINATION/voices.bin"
test -f "$DESTINATION/tokens.txt"
test -d "$DESTINATION/espeak-ng-data"
