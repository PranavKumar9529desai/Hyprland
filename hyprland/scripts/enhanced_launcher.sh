#!/bin/bash

# Enhanced App Launcher Script for Hyprland
# Provides history tracking, recent apps, and smooth animations

LAUNCHER_HISTORY="$HOME/.cache/launcher_history"
LAUNCHER_CONFIG="$HOME/.config/fuzzel/fuzzel.ini"

# Create cache directory if it doesn't exist
mkdir -p "$(dirname "$LAUNCHER_HISTORY")"

# Function to log app launches
log_launch() {
    local app="$1"
    echo "$(date +%s):$app" >> "$LAUNCHER_HISTORY"
    
    # Keep only last 100 entries
    tail -n 100 "$LAUNCHER_HISTORY" > "${LAUNCHER_HISTORY}.tmp" && 
    mv "${LAUNCHER_HISTORY}.tmp" "$LAUNCHER_HISTORY"
}

# Function to get recent apps for better sorting
get_recent_apps() {
    if [[ -f "$LAUNCHER_HISTORY" ]]; then
        sort -t: -k1,1nr "$LAUNCHER_HISTORY" | 
        cut -d: -f2 | 
        head -n 20
    fi
}

# Function to launch fuzzel with animations
launch_fuzzel() {
    # Kill existing fuzzel instances
    pkill fuzzel 2>/dev/null
    
    # Add slight delay for smooth appearance
    sleep 0.05
    
    # Launch fuzzel with our config
    fuzzel --config="$LAUNCHER_CONFIG" &
    
    # Get the PID for potential enhancements
    FUZZEL_PID=$!
    
    # Wait for fuzzel to finish and capture the launched app
    wait $FUZZEL_PID
    
    # Log frequently used applications (basic implementation)
    # This could be enhanced with fuzzel's output parsing
}

# Function to check for alternative launchers
check_alternatives() {
    if command -v rofi >/dev/null 2>&1; then
        echo "rofi"
    elif command -v wofi >/dev/null 2>&1; then
        echo "wofi"
    elif command -v tofi >/dev/null 2>&1; then
        echo "tofi"
    else
        echo "fuzzel"
    fi
}

# Function to launch with rofi (if available)
launch_rofi() {
    pkill rofi 2>/dev/null
    
    rofi -show drun \
         -theme-str 'window {width: 40%; height: 50%;}' \
         -theme-str 'listview {lines: 8;}' \
         -theme-str 'textbox-prompt-colon {enabled: false;}' \
         -show-icons &
}

# Main launcher logic
main() {
    case "${1:-fuzzel}" in
        "rofi")
            if command -v rofi >/dev/null 2>&1; then
                launch_rofi
            else
                echo "Rofi not installed, falling back to fuzzel"
                launch_fuzzel
            fi
            ;;
        "fuzzel"|*)
            launch_fuzzel
            ;;
    esac
}

# Execute main function
main "$@" 