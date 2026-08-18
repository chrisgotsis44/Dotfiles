-- ==================================================================== --
--  ML4W — Classic
--  The minimal ML4W set: one curve, popin-80% on close, everything else default.
--  Use when: you want ML4W's look with the fewest moving parts.
-- ==================================================================== --

-- /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #
--
-- name "Classic"
-- credit https://github.com/mylinuxforwork/dotfiles

hl.config({ animations = { enabled = true } })
hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })

-- ---- Hyprland 0.56 additions ------------------------------------- --
-- Layer surfaces (bar, launcher, notifications, the settings overlay) had no
-- animation at all here, so they were the one thing that snapped. Fade, not
-- slide: these surfaces run their own entrance animations internally and a
-- compositor-side slide fights them.
-- glowangle/shadowangle are 0.56's siblings of borderangle: same rotation, for
-- decoration:glow:* and the shadow. Harmless when glow is off.
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "myBezier", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3.2, bezier = "default", style = "fade" })
hl.animation({ leaf = "glowangle", enabled = true, speed = 8, bezier = "default", style = "once" })
hl.animation({ leaf = "shadowangle", enabled = true, speed = 8, bezier = "default", style = "once" })
hl.animation({ leaf = "fadeGlow", enabled = true, speed = 4, bezier = "myBezier" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 4, bezier = "myBezier" })
hl.animation({ leaf = "monitorAdded", enabled = true, speed = 4, bezier = "myBezier" })
