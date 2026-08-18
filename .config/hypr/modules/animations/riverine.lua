-- ==================================================================== --
--  Riverine — Vertical
--  Material-3 curves with VERTICAL workspace and scratchpad motion. Layer
--  animations were commented out upstream; a gentle fade is supplied below so
--  popups are not the one thing that snaps.
--  Use when: you want end-4-style motion with vertical workspaces.
-- ==================================================================== --

hl.config({ animations = { enabled = true } })

hl.curve("md3_decel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
hl.curve("md3_accel", { type = "bezier", points = { {0.3, 0}, {0.8, 0.15} } })
hl.curve("menu_decel", { type = "bezier", points = { {0.1, 1}, {0, 1} } })
hl.curve("menu_accel", { type = "bezier", points = { {0.38, 0.04}, {1, 0.07} } })

-- Windows
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "md3_decel", style = "popin 60%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "md3_decel", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "md3_accel", style = "popin 60%" })

-- Layers
--animation = layersIn, 1, 5, menu_decel, slide left
--animation = layersOut, 1, 3, menu_accel, slide left
--animation = fadeLayersIn, 1, 2, menu_decel
--animation = fadeLayersOut, 1, 4.5, menu_accel

-- Workspaces
hl.animation({ leaf = "workspaces", enabled = true, speed = 7, bezier = "menu_decel", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "md3_decel", style = "slidevert" })

-- Fade
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "md3_decel" })

-- ---- Hyprland 0.56 additions ------------------------------------- --
-- Layer surfaces (bar, launcher, notifications, the settings overlay) had no
-- animation at all here, so they were the one thing that snapped. Fade, not
-- slide: these surfaces run their own entrance animations internally and a
-- compositor-side slide fights them.
-- 0.56 can animate the scratchpad's entrance and exit separately; exit is
-- quicker, since you are already looking away from it.
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "md3_decel", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.4, bezier = "md3_accel", style = "fade" })
hl.animation({ leaf = "fadeGlow", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 3, bezier = "md3_decel", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2.4, bezier = "md3_accel", style = "slidevert" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "monitorAdded", enabled = true, speed = 3, bezier = "md3_decel" })
