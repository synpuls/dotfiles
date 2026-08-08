#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.synpuls.memory-watchdog"
TEMPLATE="$SCRIPT_DIR/launchagents/$LABEL.plist.template"
TARGET_DIR="$HOME/Library/LaunchAgents"
TARGET="$TARGET_DIR/$LABEL.plist"
DOMAIN="gui/$(id -u)"

mkdir -p "$TARGET_DIR" "$HOME/Library/Logs/memory-watchdog"
escaped_home=$(printf '%s' "$HOME" | sed 's/[&|]/\\&/g')
sed "s|__HOME__|$escaped_home|g" "$TEMPLATE" > "$TARGET.tmp"
plutil -lint "$TARGET.tmp" >/dev/null
mv -f "$TARGET.tmp" "$TARGET"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$TARGET"
launchctl enable "$DOMAIN/$LABEL"
launchctl kickstart -k "$DOMAIN/$LABEL"

echo "Memory Watchdogを有効にしました: $TARGET"

