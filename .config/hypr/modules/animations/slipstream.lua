-- ==================================================================== --
--  Slipstream
--  Custom: windows slide both in and out on one overshoot curve, workspaces fade
--  with no directional bias. Simple and quick.
--  Use when: you want uniform, direction-free motion.
-- ==================================================================== --

-- -- Custom-made animations: Slipstream -- #

hl.config({ animations = { enabled = true } })

hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 7, bezier = "myBezier", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "myBezier", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "myBezier" })

-- ---- Hyprland 0.56 additions ------------------------------------- --
-- Layer surfaces (bar, launcher, notifications, the settings overlay) had no
-- animation at all here, so they were the one thing that snapped. Fade, not
-- slide: these surfaces run their own entrance animations internally and a
-- compositor-side slide fights them.
-- glowangle/shadowangle are 0.56's siblings of borderangle: same rotation, for
-- decoration:glow:* and the shadow. Harmless when glow is off.
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "myBezier", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3.2, bezier = "myBezier", style = "fade" })
hl.animation({ leaf = "glowangle", enabled = true, speed = 8, bezier = "default", style = "once" })
hl.animation({ leaf = "shadowangle", enabled = true, speed = 8, bezier = "default", style = "once" })
hl.animation({ leaf = "fadeGlow", enabled = true, speed = 4, bezier = "myBezier" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 4, bezier = "myBezier" })
hl.animation({ leaf = "monitorAdded", enabled = true, speed = 4, bezier = "myBezier" })
