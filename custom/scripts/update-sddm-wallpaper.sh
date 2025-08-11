#!/bin/bash
# Update SDDM theme wallpaper to match current wallpaper

WALLPAPER_PATH=$(jq -r '.background.wallpaperPath' ~/.config/illogical-impulse/config.json 2>/dev/null)

if [ -n "$WALLPAPER_PATH" ] && [ -f "$WALLPAPER_PATH" ]; then
    sudo sed -i "s|background=.*|background=$WALLPAPER_PATH|" /usr/share/sddm/themes/hyprlock-style/theme.conf
    echo "Updated SDDM wallpaper to: $WALLPAPER_PATH"
else
    echo "Could not get wallpaper path from config"
fi 