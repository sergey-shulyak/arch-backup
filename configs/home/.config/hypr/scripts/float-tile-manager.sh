#!/usr/bin/env bash

# Float first window in workspace with 16:10 ratio, tile when second window opens

# Get current workspace ID from focused window
WORKSPACE_ID=$(hyprctl activewindow -j 2>/dev/null | jq -r '.workspace.id' 2>/dev/null)

if [ -z "$WORKSPACE_ID" ] || [ "$WORKSPACE_ID" == "null" ]; then
    exit 0
fi

# Get all windows in current workspace, excluding special workspaces and hyprwhenthen
WINDOWS=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $WORKSPACE_ID) | select(.workspace.name | startswith(\"special\") | not) | select(.class | startswith(\"hyprwhenthen\") | not) | .address" | tr -d ' ')

# Count total windows (for existence check)
WINDOW_COUNT=$(echo "$WINDOWS" | grep -c "0x" || echo 0)

if [ "$WINDOW_COUNT" -eq 0 ]; then
    exit 0
fi

# Count non-TUI windows only (for tiling decision)
NON_TUI_COUNT=0
while IFS= read -r WINDOW; do
    WINDOW=$(echo "$WINDOW" | tr -d ' ')
    if [ -z "$WINDOW" ]; then
        continue
    fi

    WINDOW_TITLE=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$WINDOW\") | .title" 2>/dev/null)

    # Skip TUI apps from the count
    if [[ "$WINDOW_TITLE" =~ ^(btop|nmtui|bluetuith|pulsemixer)$ ]]; then
        continue
    fi

    ((NON_TUI_COUNT++))
done <<< "$WINDOWS"

if [ "$NON_TUI_COUNT" -eq 0 ]; then
    # Only TUI windows exist, don't tile them
    exit 0
fi

if [ "$NON_TUI_COUNT" -eq 1 ]; then
    # Float the single non-TUI window
    # Find the first non-TUI window
    WINDOW=""
    while IFS= read -r W; do
        W=$(echo "$W" | tr -d ' ')
        if [ -z "$W" ]; then
            continue
        fi

        W_TITLE=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$W\") | .title" 2>/dev/null)
        if ! [[ "$W_TITLE" =~ ^(btop|nmtui|bluetuith|pulsemixer)$ ]]; then
            WINDOW=$W
            break
        fi
    done <<< "$WINDOWS"

    if [ -z "$WINDOW" ] || [ "$WINDOW" == "null" ]; then
        exit 0
    fi

    # Check if window still exists and get its current state
    WINDOW_EXISTS=$(hyprctl clients -j | jq -e ".[] | select(.address == \"$WINDOW\")" 2>/dev/null)
    if [ -z "$WINDOW_EXISTS" ]; then
        exit 0
    fi

    # Unfullscreen and unmaximize first
    hyprctl dispatch fullscreen 0 address:$WINDOW > /dev/null 2>&1

    # Check if already floating, if not, float it
    IS_FLOATING=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$WINDOW\") | .floating" 2>/dev/null)
    if [ "$IS_FLOATING" != "true" ]; then
        hyprctl dispatch togglefloating address:$WINDOW > /dev/null 2>&1
        # Wait for window to transition to floating state
        sleep 0.1
    fi

    # Get screen dimensions
    SCREEN_HEIGHT=$(hyprctl monitors -j | jq -r ".[0].height" 2>/dev/null)
    SCREEN_WIDTH=$(hyprctl monitors -j | jq -r ".[0].width" 2>/dev/null)

    if [ -z "$SCREEN_HEIGHT" ] || [ -z "$SCREEN_WIDTH" ] || [ "$SCREEN_HEIGHT" -eq 0 ]; then
        exit 0
    fi

    # Calculate 4:3 dimensions (75% of screen)
    WINDOW_HEIGHT=$((SCREEN_HEIGHT * 75 / 100))
    WINDOW_WIDTH=$((WINDOW_HEIGHT * 4 / 3))

    # Ensure width doesn't exceed screen width
    if [ "$WINDOW_WIDTH" -gt "$SCREEN_WIDTH" ]; then
        WINDOW_WIDTH=$((SCREEN_WIDTH * 75 / 100))
        WINDOW_HEIGHT=$((WINDOW_WIDTH * 3 / 4))
    fi

    # Center the window
    X_OFFSET=$(( (SCREEN_WIDTH - WINDOW_WIDTH) / 2 ))
    Y_OFFSET=$(( (SCREEN_HEIGHT - WINDOW_HEIGHT) / 2 ))

    # Resize and move window only if it exists
    if hyprctl clients -j | jq -e ".[] | select(.address == \"$WINDOW\")" 2>/dev/null > /dev/null; then
        hyprctl dispatch resizewindowpixel exact $WINDOW_WIDTH $WINDOW_HEIGHT address:$WINDOW > /dev/null 2>&1
        hyprctl dispatch movewindowpixel exact $X_OFFSET $Y_OFFSET address:$WINDOW > /dev/null 2>&1
    fi

elif [ "$NON_TUI_COUNT" -gt 1 ]; then
    # Tile non-TUI windows when 2+ non-TUI windows exist (TUI windows always float)
    while IFS= read -r WINDOW; do
        WINDOW=$(echo "$WINDOW" | tr -d ' ')
        if [ -z "$WINDOW" ]; then
            continue
        fi

        # Get window title to check if it's a TUI app that should stay floating
        WINDOW_TITLE=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$WINDOW\") | .title" 2>/dev/null)

        # Skip tiling for TUI apps that should always stay floating
        if [[ "$WINDOW_TITLE" =~ ^(btop|nmtui|bluetuith|pulsemixer)$ ]]; then
            continue
        fi

        IS_FLOATING=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$WINDOW\") | .floating" 2>/dev/null)
        if [ "$IS_FLOATING" == "true" ]; then
            hyprctl dispatch togglefloating address:$WINDOW > /dev/null 2>&1
        fi
    done <<< "$WINDOWS"
fi
