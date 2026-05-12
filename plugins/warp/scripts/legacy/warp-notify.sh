#!/bin/bash
# Warp notification utility using OSC escape sequences
# Usage: warp-notify.sh <title> <body>

TITLE="${1:-Notification}"
BODY="${2:-}"

# 查找实际可用的 tty 设备写入 OSC 序列
# /dev/tty 在 Claude Code hook 沙箱中可能不可用（Device not configured）
# 回退策略：通过父进程链定位 Claude Code 所在终端 → 遍历 ttys → stdout
TTY_DEV=""

# 先尝试 /dev/tty
if [ -w /dev/tty ] && printf '' > /dev/tty 2>/dev/null; then
    TTY_DEV="/dev/tty"
fi

# 回退1：通过父进程链找到 Claude Code 实际所在的终端
if [ -z "$TTY_DEV" ]; then
    pid=$$
    while [ "$pid" -gt 1 ]; do
        tty=$(ps -o tty= -p "$pid" 2>/dev/null)
        tty="${tty#"${tty%%[![:space:]]*}"}"  # trim leading spaces
        tty="${tty%"${tty##*[![:space:]]}"}"  # trim trailing spaces
        if [ -n "$tty" ] && [[ "$tty" != "??"* ]]; then
            TTY_DEV="/dev/$tty"
            [ -w "$TTY_DEV" ] || TTY_DEV=""
            break
        fi
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null)
    done
fi

# 回退2：遍历当前用户可写的 /dev/ttys00* 设备（跳过系统伪终端 tty[0-9]）
if [ -z "$TTY_DEV" ]; then
    for dev in /dev/ttys00* /dev/ttys01*; do
        if [ -w "$dev" ] && printf '' > "$dev" 2>/dev/null; then
            TTY_DEV="$dev"
            break
        fi
    done 2>/dev/null
fi

# OSC 777 format: \033]777;notify;<title>;<body>\007
if [ -n "$TTY_DEV" ]; then
    printf '\033]777;notify;%s;%s\007' "$TITLE" "$BODY" > "$TTY_DEV" 2>/dev/null || true
else
    # 最终回退：stdout（某些环境下可工作）
    printf '\033]777;notify;%s;%s\007' "$TITLE" "$BODY" 2>/dev/null || true
fi
