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