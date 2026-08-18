---------------------
---- MY PROGRAMS ----
---------------------

local mainMod = "SUPER"

-- Set programs that you use
local terminal    = "kitty"
local fileManager = "thunar"
local menu        = "qs -c island ipc call shell toggleLauncher"
--local menu        = "pkill rofi || rofi -show drun -theme ~/.config/rofi/launchers/apps.rasi"
local browser     = "google-chrome-stable"
local editor      = "codium"

---------------------
---- KEYBINDINGS ----
---------------------

-- Compositor Binds
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + DELETE", hl.dsp.exit())
--hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("pkill wlogout || wlogout -b 5"))
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("qs -c island ipc call shell togglePowerMenu"))
-- Lockscreen: ~/.config/quickshell/lock, its own Quickshell process so a
-- fault in the island shell cannot take it down. lock.sh flocks so a second
-- press cannot stack a second locker.
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("lock.sh"))

-- Window switcher (island). Two gestures onto the same state:
--   SUPER+Tab  sticky -- stays open, Tab/arrows cycle, Enter or a click
--              commits, Escape cancels. Works with a plain bind.
--   ALT+Tab    classic -- hold ALT and tap Tab, release ALT to commit.
--              The release itself is caught inside the island, not here.
hl.bind(mainMod .. " + Tab",           hl.dsp.exec_cmd("qs -c island ipc call switcher cycle"))
hl.bind(mainMod .. " + SHIFT + Tab",   hl.dsp.exec_cmd("qs -c island ipc call switcher prev"))
hl.bind("ALT + Tab",                   hl.dsp.exec_cmd("qs -c island ipc call switcher cycle"))
hl.bind("ALT + SHIFT + Tab",           hl.dsp.exec_cmd("qs -c island ipc call switcher prev"))
-- ALT release commits. This raced the ALT+Tab bind (separate processes,
-- no ordering guarantee), which is now handled inside the island: a select
-- arriving before the switcher is open is armed for 250ms rather than
-- dropped, so the result is the same whichever process wins.
hl.bind("ALT + Alt_L",                 hl.dsp.exec_cmd("qs -c island ipc call switcher select"), { release = true })
hl.bind(mainMod .. " + G", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- Programs
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(editor))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(browser))

-- App Launcher
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(menu))

-- Character pickers. These used to be the launcher's ":" prefix mode;
-- they are now island menus of their own, Enter copies to the clipboard.
--   SUPER+,  emoji
--   SUPER+.  Unicode symbols (arrows, math, box-drawing) + Nerd Font icons
hl.bind(mainMod .. " + comma",  hl.dsp.exec_cmd("qs -c island ipc call shell toggleEmojiPicker"))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("qs -c island ipc call shell toggleGlyphPicker"))

-- Dashboards
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("qs -c island ipc call shell toggleControlCenter"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("qs -c island ipc call shell toggleDashboard"))
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("qs -c island ipc call shell toggleCalendar"))
-- Settings panel (centered overlay, not an island morph)
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("qs -c island ipc call shell toggleSettings"))


-- Custom Themes And Wallpapers
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("qs -c island ipc call shell toggleThemeMenu"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("qs -c island ipc call shell toggleWallpaperPicker"))

--UI
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("qs -c island ipc call shell toggleBigIsland"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("island-reload.sh"))

-- Cliphist (Using Lua's [[ ]] to safely wrap the complex shell piping)
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("qs -c island ipc call shell toggleClipboard"))

-- Screenshot
hl.bind("Print", hl.dsp.exec_cmd([[grim - | satty --filename - --fullscreen --output-filename ~/Pictures/Screenshots/satty-$(date '+%Y%m%d-%H:%M:%S').png]]))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | satty --filename - --fullscreen --output-filename ~/Pictures/Screenshots/satty-$(date '+%Y%m%d-%H:%M:%S').png]]))

-- Color Picker & History
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("pkill -SIGUSR1 ie-r"))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.exec_cmd("pkill -SIGUSR2 ie-r"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a -n -l"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- Maps 10 to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
--hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
--hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness (bindel behavior handled by properties)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl (bindl behavior handled by properties)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
