#!/bin/bash
#
# 检查 display-keepawake 是否生效
#
set -uo pipefail

LABEL="io.github.owenweng0101.display-keepawake"
UID_NUM="$(id -u)"

echo "=== LaunchAgent ==="
if launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1; then
    launchctl print "gui/$UID_NUM/$LABEL" | grep -E "^\s+(state|pid|runs) " | sed 's/^/  /'
else
    echo "  未加载"
fi

echo
echo "=== 电源断言 ==="
pmset -g assertions | grep -i caffeinate | sed 's/^/  /' || echo "  无 caffeinate 断言"

echo
echo "=== 显示器空闲计时器 ==="
pmset -g | grep -i displaysleep | sed 's/^/  /'

echo
echo "=== 硬件状态 ==="
echo "  合盖状态: $(ioreg -r -k AppleClamshellState -d 4 2>/dev/null | awk -F'= ' '/AppleClamshellState/{print $2; exit}')"
echo "  供电:     $(pmset -g batt | head -1 | sed 's/Now drawing from //')"
pmset -g batt | tail -1 | sed 's/^/  电池:    /'

echo
echo "=== 最近的显示器休眠事件 ==="
pmset -g log 2>/dev/null | grep -E "Display is turned (on|off)" | tail -4 | sed 's/^/  /' || echo "  无记录"

echo
echo "提示：如果「电源断言」里能看到 PreventUserIdleDisplaySleep，且「显示器空闲计时器」"
echo "      那行写着 prevented by ... caffeinate，说明已在生效。"
