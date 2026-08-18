-- ==================================================================== --
--  ML4W — Fast
--  Short durations, small popin, expo-out workspaces. Built for speed over drama.
--  Use when: you want animation present but never in the way.
-- ==================================================================== --

-- /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #
--
-- name "Fast"
-- credit https://github.com/mylinuxforwork/dotfiles

hl.config({ animations = { enabled = true } })
hl.curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })
hl.curve("md3_standard", { type = "bezier", points = { {0.2, 0}, {0, 1} } })
hl.curve("md3_decel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
hl.curve("md3_accel", { type = "bezier", points = { {0.3, 0}, {0.8, 0.15} } })
hl.curve("overshot", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.1} } })
hl.curve("crazyshot", { type = "bezier", points = { {0.1, 1.5}, {0.76, 0.92} } })
hl.curve("hyprnostretch", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.0} } })
hl.curve("fluent_decel", { type = "bezier", points = { {0.1, 1}, {0, 1} } })
hl.curve("easeInOutCirc", { type = "bezier", points = { {0.85, 0}, {0.15, 1} } })
hl.curve("easeOutCirc", { type = "bezier", points = { {0, 0.55}, {0.45, 1} } })
hl.curve("easeOutExpo", { type = "bezier", points = { {0.16, 1}, {0.3, 1} } })
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "md3_decel", style = "popin 60%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 2.5, bezier = "md3_decel" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "easeOutExpo", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "md3_decel", style = "slidevert" })

-- ---- Hyprland 0.56 additions ------------------------------------- --
-- Layer surfaces (bar, launcher, notifications, the settings overlay) had no
-- animation at all here, so they were the one thing that snapped. Fade, not
-- slide: these surfaces run their own entrance animations internally and a
-- compositor-side slide fights them.
-- 0.56 can animate the scratchpad's entrance and exit separately; exit is
-- quicker, since you are already looking away from it.
hl.animation({ leaf = "layersIn", enabled = true, speed = 2.5, bezier = "md3_decel", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.0, bezier = "md3_decel", style = "fade" })
hl.animation({ leaf = "fadeGlow", enabled = true, speed = 2.5, bezier = "md3_decel" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 2.5, bezier = "md3_decel", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2.0, bezier = "md3_decel", style = "slidevert" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 2.5, bezier = "md3_decel" })
hl.animation({ leaf = "monitorAdded", enabled = true, speed = 2.5, bezier = "md3_decel" })
