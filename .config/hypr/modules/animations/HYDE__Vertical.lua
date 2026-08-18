-- ==================================================================== --
--  HyDE — Vertical
--  Vertical-first: workspaces slide-fade vertically 30%, scratchpad slides
--  horizontally, layers pop. Pairs with a top/bottom bar and vertical workspace binds.
--  Use when: your workspace keys feel 'up and down' rather than 'left and right'.
-- ==================================================================== --

-- /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #
--
-- name "Vertical"
-- credit https://github.com/prasanthrangan/hyprdots

hl.config({ animations = { enabled = true } })

hl.curve("fluent_decel", { type = "bezier", points = { {0, 0.2}, {0.4, 1} } })
hl.curve("easeOutCirc", { type = "bezier", points = { {0, 0.55}, {0.45, 1} } })
hl.curve("easeOutCubic", { type = "bezier", points = { {0.33, 1}, {0.68, 1} } })
hl.curve("easeinoutsine", { type = "bezier", points = { {0.37, 0}, {0.63, 1} } })

-- Windows
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.5, bezier = "easeinoutsine", style = "popin 60%" }) -- window open
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "easeOutCubic", style = "popin 60%" }) -- window close.
hl.animation({ leaf = "windowsMove", enabled = true, speed = 1.5, bezier = "easeinoutsine", style = "slide" }) -- everything in between, moving, dragging, resizing.

-- Fading
hl.animation({ leaf = "fade", enabled = true, speed = 2.5, bezier = "fluent_decel" })

-- [UNCERTAIN] animation = fadeLayersIn, 0
-- [UNCERTAIN] animation = border, 0


-- Layers
hl.animation({ leaf = "layers", enabled = true, speed = 1.5, bezier = "easeinoutsine", style = "popin" })

-- Workspaces
--animation = workspaces, 1, 3, fluent_decel, slidefade 30% # styles: slide, slidevert, fade, slidefade, slidefadevert
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "fluent_decel", style = "slidefadevert 30%" }) -- styles: slide, slidevert, fade, slidefade, slidefadevert

hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2, bezier = "fluent_decel", style = "slidefade 10%" })

-- ---- Hyprland 0.56 additions ------------------------------------- --
-- 0.56 can animate the scratchpad's entrance and exit separately; exit is
-- quicker, since you are already looking away from it.
hl.animation({ leaf = "fadeGlow", enabled = true, speed = 2, bezier = "fluent_decel" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 2, bezier = "fluent_decel", style = "slidefade 10%" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1.6, bezier = "easeOutCubic", style = "slidefade 10%" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 2, bezier = "fluent_decel" })
hl.animation({ leaf = "monitorAdded", enabled = true, speed = 2, bezier = "fluent_decel" })
