-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

--Toolkit Backend
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

--XDG 
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

--Qt
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

--Nvidia
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- DP-1 runs vrr = 2 (see monitors.lua) -- GSYNC_ALLOWED=1 enables NVIDIA's
-- own G-Sync signaling path; VRR_ALLOWED=0 is the wiki's specific
-- recommendation to avoid the separate legacy GLX/XWayland adaptive-sync
-- path double-handling VRR on top of what Hyprland's compositor already
-- does for Wayland-native windows, which is what causes game issues.
hl.env("__GL_GSYNC_ALLOWED", "1")
hl.env("__GL_VRR_ALLOWED", "0")
-- Activates the already-installed libva-nvidia-driver package for VA-API
-- hardware video acceleration -- without this the package does nothing.
hl.env("NVD_BACKEND", "direct")

--Electron/CEF (VSCodium, Vesktop, ...): native Wayland instead of XWayland,
-- fixes flickering.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
