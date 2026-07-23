export QT_QPA_PLATFORMTHEME=qt6ct  # Use qt5ct if you are on an older version of Dolphin
export QT_STYLE_OVERRIDE=kvantum

if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
  exec start-hyprland
fi

# Added by Antigravity CLI installer
export PATH="/home/christoforos/.local/bin:$PATH"
