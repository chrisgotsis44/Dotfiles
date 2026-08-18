-- ==================================================================== --
--  HyDE — Minimal 2
--  The smallest preset that still animates: one curve, five branches, uniform
--  speed. No in/out asymmetry at all.
--  Use when: you want motion present but completely unobtrusive.
-- ==================================================================== --

-- /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #
--
-- # name "Minimal-2"
-- credit https://github.com/prasanthrangan/hyprdots

hl.config({ animations = { enabled = true } })

hl.curve("quart", { type = "bezier", points = { {0.25, 1}, {0.5, 1} } })

hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "quart", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "quart" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 6, bezier = "quart" })
hl.animation({ leaf = "fade", enabled = true, speed = 6, bezier = "quart" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "quart" })

-- ---- Hyprland 0.56 additions ------------------------------------- --
-- Layer surfaces (bar, launcher, notifications, the settings overlay) had no
-- animation at all here, so they were the one thing that snapped. Fade, not
-- slide: these surfaces run their own entrance animations internally and a
-- compositor-side slide fights them.
-- glowangle/shadowangle are 0.56's siblings of borderangle: same rotation, for
-- decoration:glow:* and the shadow. Harmless when glow is off.
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "quart", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3.2, bezier = "quart", style = "fade" })
hl.animation({ leaf = "glowangle", enabled = true, speed = 6, bezier = "default", style = "once" })
hl.animation({ leaf = "shadowangle", enabled = true, speed = 6, bezier = "default", style = "once" })
hl.animation({ leaf = "fadeGlow", enabled = true, speed = 4, bezier = "quart" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 4, bezier = "quart" })
hl.animation({ leaf = "monitorAdded", enabled = true, speed = 4, bezier = "quart" })
