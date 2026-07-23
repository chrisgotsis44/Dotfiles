#!/bin/bash

# 1. Check if deps.txt exists in the same folder
if [ ! -f "deps.txt" ]; then
    echo "❌ Error: deps.txt not found in the current directory."
    echo "Please ensure deps.txt is in the same folder as this script."
    exit 1
fi

# 2. Check for yay (AUR helper). Install it if missing.
if ! command -v yay &> /dev/null; then
    echo "⚠️ 'yay' is not installed. It is required for AUR packages."
    echo "🔧 Installing yay-bin..."
    
    # Ensure base-devel and git are installed (required to build yay)
    sudo pacman -S --needed --noconfirm git base-devel
    
    # Clone and build yay
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
    cd ..
    rm -rf yay-bin # Clean up the build folder
    
    echo "✅ 'yay' installed successfully!"
fi

echo "🚀 Starting installation of packages from deps.txt..."

# 3. Read the file and pass all package names to yay
# The --needed flag skips packages that are already installed and up-to-date
yay -S --needed $(cat deps.txt)

echo "🎉 All done! Your dependencies have been processed."