-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Ignore maximize requests
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Remove the right-click menu blurring in Chromium browsers
hl.window_rule({
    name  = "chromium-no-blur",
    match = { class = "^$", title = "^$" },
    no_blur = true,
})

-- Remove the weird pop-up behavior in VSCode
hl.window_rule({
    name  = "codium-min-size",
    match = { class = "^(codium)$" },
    min_size = { 1, 1 },
})

-- Make file picker windows floating
hl.window_rule({
    name  = "file-pickers",
    match = {
        title = "^(Open File|Open|Save|Save As|Export|Import|Choose File|Rename|script-fu)",
        class = "^(.*)$",
    },
    float  = true,
    center = true,
})

hl.window_rule({
    name  = "xdg-portal-float",
    match = { class = "^([Xx]dg-desktop-portal-gtk|[Xx]dg-desktop-portal-hyprland)$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name  = "xdg-portal-no-border",
    match = { class = "^(Xdg-desktop-portal-gtk)$" },
    border_size = 0,
})

-- Disable borders for swaync
hl.window_rule({
    name  = "swaync-no-border",
    match = { class = "^(swaync)$" },
    border_size = 0,
})

-- Pulsecontrol
hl.window_rule({
    name  = "pulsecontrol-float",
    match = { class = "^(org\\.test\\.pulsecontrol)$" },
    float  = true,
    center = true,
    size   = { 800, 650 },
})

-- Blueman-Manager
hl.window_rule({
    name  = "blueman-manager-float",
    match = { class = "^(blueman-manager)$" },
    float  = true,
    center = true,
    size   = { 800, 500 },
})

-- Layer Rules (Animations & Decorations)

hl.layer_rule({
    name  = "waybar-blur",
    match = { namespace = "waybar" },
    blur         = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name  = "swaync-blur",
    match = { namespace = "swaync-control-center" },
    blur         = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name  = "swaync-notifications-blur",
    match = { namespace = "swaync-notification-window" },
    blur         = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name  = "wlogout-blur",
    match = { namespace = "logout_dialog" },
    blur = true,
})

hl.layer_rule({
    name  = "rofi-blur",
    match = { namespace = "rofi" },
    blur         = true,
    ignore_alpha = 0.5,
    animation    = "popin 95%",
})
