#!/bin/bash

# Network speed indicator for Waybar
# Displays download and upload speeds based on /sys/class/net interface statistics

# Get active network interface (excluding loopback)
get_interface() {
    ip route 2>/dev/null | grep default | awk '{print $5}' | head -1
}

# Format bytes to human readable format
format_bytes() {
    local bytes=$1

    if [ "$bytes" -lt 1000 ]; then
        echo "${bytes}B/s"
    elif [ "$bytes" -lt 1000000 ]; then
        echo "$((bytes / 1000))KB/s"
    elif [ "$bytes" -lt 1000000000 ]; then
        echo "$((bytes / 1000000))MB/s"
    else
        echo "$((bytes / 1000000000))GB/s"
    fi
}

# Get the primary active network interface
INTERFACE=$(get_interface)

if [ -z "$INTERFACE" ]; then
    echo "{\"text\":\"📡 N/A\",\"class\":\"disconnected\"}"
    exit 0
fi

# Get stat file paths
RX_FILE="/sys/class/net/$INTERFACE/statistics/rx_bytes"
TX_FILE="/sys/class/net/$INTERFACE/statistics/tx_bytes"

# Check if interface stats are available
if [ ! -f "$RX_FILE" ] || [ ! -f "$TX_FILE" ]; then
    echo "{\"text\":\"📡 N/A\",\"class\":\"disconnected\"}"
    exit 0
fi

# Read initial stats
RX_START=$(cat "$RX_FILE")
TX_START=$(cat "$TX_FILE")

# Wait for 1 second to measure bandwidth
sleep 1

# Read final stats
RX_END=$(cat "$RX_FILE")
TX_END=$(cat "$TX_FILE")

# Calculate speeds (bytes per second)
RX_SPEED=$((RX_END - RX_START))
TX_SPEED=$((TX_END - TX_START))

# Format output
RX_FMT=$(format_bytes $RX_SPEED)
TX_FMT=$(format_bytes $TX_SPEED)

# Only display if speed is > 1 MB/s (1000000 bytes)
THRESHOLD=1000000
if [ $RX_SPEED -gt $THRESHOLD ] || [ $TX_SPEED -gt $THRESHOLD ]; then
    echo "⬇️ ${RX_FMT} | ⬆️ ${TX_FMT}"
else
    echo ""
fi
