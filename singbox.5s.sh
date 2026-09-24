#!/bin/bash

CONFIG_DIR="$HOME/.config/sing-box"
LOG_PATH="/tmp/singbox_log.txt"
SING_BOX="/opt/homebrew/bin/sing-box"
KILLALL="/usr/bin/killall"
PGREP="/usr/bin/pgrep"

# Обработка команд из меню
if [ "$1" = "toggle" ]; then
    if $PGREP sing-box > /dev/null; then
        sudo $KILLALL sing-box
    else
        # Сначала переходим в рабочую папку, чтобы cache.db создавался там
        cd "$CONFIG_DIR" || exit
        # Запускаем, ипользуя локальный config.json
        nohup sudo $SING_BOX run -c config.json > "$LOG_PATH" 2>&1 &
    fi
    exit
elif [ "$1" = "quit" ]; then
    if $PGREP sing-box > /dev/null; then
        sudo $KILLALL sing-box
    fi
    osascript -e 'quit app "SwiftBar"'
    exit
fi

# Получаем версию sing-box (только первую строку)
SB_VERSION=$($SING_BOX version | head -n 1)

# Отрисовка интерфейса в строке меню
if $PGREP sing-box > /dev/null; then
    echo "🟢"
    echo "---"
    echo "Статус: Подключен"
    echo "Отключить VPN | bash=\"$0\" param1=toggle terminal=false refresh=true"
    echo "---"
    echo "$SB_VERSION"
    echo "Выход | bash=\"$0\" param1=quit terminal=false"
else
    echo "⚪️"
    echo "---"
    echo "Статус: Отключен"
    echo "Включить VPN | bash=\"$0\" param1=toggle terminal=false refresh=true"
    echo "---"
    echo "$SB_VERSION"
    echo "Выход | bash=\"$0\" param1=quit terminal=false"
fi