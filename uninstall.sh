#!/bin/bash
#
# 卸载 display-keepawake
#
set -euo pipefail

LABEL="io.github.owenweng0101.display-keepawake"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SUPPORT_DIR="$HOME/Library/Application Support/display-keepawake"
UID_NUM="$(id -u)"

launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$SUPPORT_DIR"

echo "已卸载。"
echo
echo "确认："
if pmset -g assertions | grep -qi caffeinate; then
    echo "  仍有 caffeinate 断言（可能来自其他程序，请检查）"
else
    echo "  已无 caffeinate 断言"
fi
pmset -g | grep -i displaysleep | sed 's/^/  /'
