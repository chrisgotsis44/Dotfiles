-- ==================================================================== --
--  Riverine — Horizontal
--  Riverine with horizontal workspaces and layers sliding in from the RIGHT --
--  tuned for a right-hand sidebar.
--  Use when: you want Riverine but your workspaces read left-to-right.
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
hl.animation({ leaf = "layersIn", enabled = true, speed = 5, bezier = "menu_decel", style = "slide right" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3, bezier = "menu_accel", style = "slide right" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 4.5, bezier = "menu_accel" })

-- Workspaces
hl.animation({ leaf = "workspaces", enabled = true, speed = 7, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "md3_decel", style = "slide" })

-- Fade
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "md3_decel" })

-- ---- Hyprland 0.56 additions ------------------------------------- --
-- 0.56 can animate the scratchpad's entrance and exit separately; exit is
-- quicker, since you are already looking away from it.
hl.animation({ leaf = "fadeGlow", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 3, bezier = "md3_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2.4, bezier = "md3_accel", style = "slide" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "monitorAdded", enabled = true, speed = 3, bezier = "md3_decel" })
