-- ==================================================================== --
--  ML4W — Moving
--  Emphasises movement over scale: windows slide with overshoot, and it is one of
--  the few presets that animates fadeDim (the dim-inactive fade).
--  Use when: you use dim_inactive and want that transition smoothed too.
-- ==================================================================== --

-- /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #
--
-- name "Moving"
-- credit https://github.com/mylinuxforwork/dotfiles


hl.config({ animations = { enabled = true } })
hl.curve("overshot", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("smoothOut", { type = "bezier", points = { {0.5, 0}, {0.99, 0.99} } })
hl.curve("smoothIn", { type = "bezier", points = { {0.5, -0.5}, {0.68, 1.5} } })
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "overshot", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "smoothOut" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "smoothOut" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "smoothIn", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "smoothIn" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 5, bezier = "smoothIn" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })

-- ---- Hyprland 0.56 additions ------------------------------------- --
-- Layer surfaces (bar, launcher, notifications, the settings overlay) had no
-- animation at all here, so they were the one thing that snapped. Fade, not
-- slide: these surfaces run their own entrance animations internally and a
-- compositor-side slide fights them.
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "smoothIn", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3.2, bezier = "smoothOut", style = "fade" })
hl.animation({ leaf = "fadeGlow", enabled = true, speed = 4, bezier = "smoothIn" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 4, bezier = "smoothIn" })
hl.animation({ leaf = "monitorAdded", enabled = true, speed = 4, bezier = "smoothIn" })
