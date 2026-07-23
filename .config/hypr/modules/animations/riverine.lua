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
