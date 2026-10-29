#!/bin/bash
#
# 让 MacBook 合盖后远程桌面不再卡在「正在传输画面」
#
# 原理：持有 macOS 的 PreventUserIdleDisplaySleep 电源断言，阻止外接显示器
#       按空闲计时器休眠。显示器不睡，远程软件连接时就不需要「唤醒 + 重新
#       枚举音频设备」，ScreenCaptureKit 的采集流可以毫秒级启动。
#
# 用法：
#   ./install.sh              始终保持显示器唤醒（默认）
#   ./install.sh --lid-only   只在合盖时保持唤醒，开盖后恢复系统正常休眠行为
#
set -euo pipefail

LABEL="io.github.owenweng0101.display-keepawake"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SUPPORT_DIR="$HOME/Library/Application Support/display-keepawake"
WRAPPER="$SUPPORT_DIR/lid-only.sh"
UID_NUM="$(id -u)"
MODE="always"

usage() {
    cat <<'EOF'
用法: ./install.sh [--lid-only]

  --lid-only   只在合盖时保持显示器唤醒（更省电，推荐笔记本用户）
  默认         始终保持显示器唤醒

卸载: ./uninstall.sh
EOF
}

for arg in "$@"; do
    case "$arg" in
        --lid-only) MODE="lid-only" ;;
        -h|--help)  usage; exit 0 ;;
        *) echo "未知参数: $arg"; usage; exit 1 ;;
    esac
done

mkdir -p "$HOME/Library/LaunchAgents"

# 先卸载旧版本，保证重复执行是幂等的
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true

if [ "$MODE" = "lid-only" ]; then
    mkdir -p "$SUPPORT_DIR"

    cat > "$WRAPPER" <<'EOF'
#!/bin/bash
# 仅在合盖时持有显示器防睡眠断言；开盖后最多 10 秒内释放。
while true; do
    if /usr/sbin/ioreg -r -k AppleClamshellState -d 4 2>/dev/null | /usr/bin/grep -q '"AppleClamshellState" = Yes'; then
        /usr/bin/caffeinate -d -i -t 10
    else
        /bin/sleep 10
    fi
done
EOF
    chmod +x "$WRAPPER"

    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$WRAPPER</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ThrottleInterval</key>
	<integer>10</integer>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
EOF
else
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/caffeinate</string>
		<string>-d</string>
		<string>-i</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ThrottleInterval</key>
	<integer>10</integer>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
EOF
fi

plutil -lint "$PLIST" >/dev/null
launchctl bootstrap "gui/$UID_NUM" "$PLIST"

sleep 1

echo
echo "已安装（模式：${MODE}）"
echo "  LaunchAgent: $PLIST"
echo
echo "当前状态："
launchctl print "gui/$UID_NUM/$LABEL" 2>/dev/null | grep -E "^\s+(state|pid) " | sed 's/^/  /' || true
pmset -g assertions | grep -i "caffeinate" | sed 's/^/  /' || echo "  （lid-only 模式下开盖时不会持有断言，属正常）"
echo
pmset -g | grep -i displaysleep | sed 's/^/  /'
echo
echo "验证方法：上面 displaysleep 那行应出现 \"prevented by ... caffeinate\""
echo "卸载：./uninstall.sh"
