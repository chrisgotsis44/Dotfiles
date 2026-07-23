----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = false, -- If true disables the random hyprland logo / anime girl background. :(

        -- Everything else already animates (20+ presets in modules/animations/)
        -- -- these two were the gap: manual resize/drag now animates too.
        animate_manual_resizes       = true,
        animate_mouse_windowdragging = true,

        -- Launch a GUI app from kitty and the terminal hides while it runs,
        -- reappearing when it closes.
        enable_swallow = true,
        swallow_regex  = "^(kitty)$",
    },
})

-- See https://wiki.hypr.land/Configuring/Basics/Variables/#render
-- direct_scanout reduces latency when a single fullscreen app owns the
-- screen (games). 2 = auto, only kicks in for fullscreen game-content-type
-- windows. Known to occasionally cause graphical glitches on Nvidia --
-- revert to 0 if that happens.
hl.config({
    render = {
        direct_scanout = 2,
    },
})