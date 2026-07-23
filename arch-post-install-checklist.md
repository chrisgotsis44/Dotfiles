1. `ping google.com` to make sure Internet works.

2. Connect to Wi-Fi: `sudo nmcli dev wifi connect <network-ssid> password <password>`

3. Install only necessary programs like a text editor, `git`, `reflector` (to get the fastest mirrors) and whatever else you use, **in the TTY first**. If you install all needed programs in the TTY, you won't end up installing unnecessary bloat that you otherwise would if you were in a graphical environment (it's weird, but it works; the TTY makes you focus).

4. Use `reflector` to speed up downloading and installing programs:
	1. Back up your current mirrorlist with `sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak`.
	   
	2. Generate a new mirrorlist with `sudo reflector --save /etc/pacman.d/mirrorlist --sort rate --sort age --country "United States" --country "Worldwide"`
	   
	3. Replace *United States* with your country if need be.
	   
	4. This saves a new *mirrorlist* file to `/etc/pacman.d` which contains mirror links sorted by download speed and how old each link's packages are, from a particular country.
	   
	5. Syncing packages with `pacman -S` should now be blazingly fast.

5. Set up an AUR helper:
	1. `sudo pacman -S git --needed --noconfirm && git clone https://aur.archlinux.org/yay-bin && cd yay-bin/ && makepkg -si && cd .. && rm -rf yay-bin/`
	   
	2. This makes sure `git` is installed first and then installs `yay`, the AUR helper. Using `yay` is the same as `pacman`. Replace `pacman` with `yay`.
	   
	3. `yay` can get rid of *orphans* (unused dependencies) with `yay -Yc` and clear out package cache (remove all *.pkg.tar.zst* files and their signatures in `/var/cache/pacman/pkg`).

6. Set up Chaotic AUR (install AUR packages without manually compiling them):
	1. Retrieve the primary key to enable the installation of their keyring and mirror list.
		1. `sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com`
		   
		2. `sudo pacman-key --lsign-key 3056513887B78AEB`
		   
	2. This allows you to install `chaotic-keyring` and `chaotic-mirrorlist`.
		1. `sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'`
		   
		2. `sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'`
		   
		3. Append (add to the end) of `/etc/pacman.conf`.
			1. `echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' | sudo tee -a /etc/pacman.conf > /dev/null`
			   
		4. Run a system update.
			1. `sudo pacman -Syu`
			   
		5. You can now install apps from the AUR without compiling.
			1. `pacman -S brave-bin`

7. Clone and restore these dotfiles:
	1. `git clone https://github.com/chrisgotsis44/Dotfiles.git ~/Dotfiles && cd ~/Dotfiles`
	2. **Before you push/pull anything else**: the old remote had a GitHub
	   personal access token baked directly into the URL
	   (`https://ghp_...@github.com/...`). That token should already be
	   revoked on GitHub's side — set the remote up cleanly instead, e.g.
	   with SSH: `git remote set-url origin git@github.com:chrisgotsis44/Dotfiles.git`
	   (or use a credential helper instead of embedding a token in the URL).
	3. Copy the config folders into place (this **overwrites** anything
	   already at these paths, which is the point on a fresh install):
	   `cp -a ~/Dotfiles/.config/. ~/.config/ && cp -a ~/Dotfiles/.local/. ~/.local/`
	4. Copy the top-level dotfiles into `$HOME`:
	   `cp -a ~/Dotfiles/.zshrc ~/Dotfiles/.zshenv ~/Dotfiles/.zprofile ~/Dotfiles/.gtkrc-2.0 ~/`
	5. Copy over `.icons`, `.themes`, `Pictures` if you want them too:
	   `cp -a ~/Dotfiles/.icons ~/Dotfiles/.themes ~/Dotfiles/Pictures ~/`
	6. `.vscode-oss` in this repo currently vendors full extension
	   binaries from an old setup rather than just a settings/extension
	   list — reinstall VSCodium extensions from the marketplace instead
	   of copying that folder over; it's stale and much bigger than it
	   needs to be.

8. Install all packages: `cd ~/Dotfiles && ./install_deps.sh` (reads
   `deps.txt`, installs `yay` first if it's missing, then installs
   everything with `yay -S --needed`). This includes `quickshell-git`
   (the actual shell — see below), `ttf-material-symbols-variable-git`
   and `adwaita-fonts` (both required for the island bar's icons/text to
   render correctly — without them you'll see ligature names instead of
   icons and a fallback system font instead of the intended one).

9. Clone the wallpaper picker separately — it's its own repo, not
   vendored inside Dotfiles:
   `git clone https://github.com/magetsu002/qs-wallpaper-picker.git ~/.config/quickshell/wallpaper`

10. Enable services and log in:
	1. `sudo systemctl enable sddm --now` (display manager)
	2. `sudo systemctl enable NetworkManager bluetooth --now`
	3. Log in, and Hyprland's `exec-once = qs -c island` in
	   `~/.config/hypr/modules/autostart.lua` starts the bar automatically
	   — see `~/.config/quickshell/island/README.md` for the full bind
	   list to wire up in your Hyprland config, and stop any other
	   notification daemon (mako/dunst/swaync) if you want the island's
	   own notification banners to work — only one can own the
	   `org.freedesktop.Notifications` D-Bus name at a time.