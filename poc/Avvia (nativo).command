#!/bin/bash
# Avvia il POC direttamente dall'editor Godot, senza passare dal browser.
cd "$(dirname "$0")/.." || exit 1
exec ./tools/Godot.app/Contents/MacOS/Godot --path poc --resolution 1280x720
