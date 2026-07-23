hl.config({ animations = { enabled = true } })

hl.curve("md3_decel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
hl.curve("md3_accel", { type = "bezier", points = { {0.3, 0}, {0.8, 0.15} } })
hl.curve("menu_decel", { type = "bezier", points = { {0.1, 1}, {0, 1} } })
hl.curve("menu_accel", { type = "bezier", points = { {0.38, 0.04}, {1, 0.07} } })

-- Windows
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "md3_decel", style = "popin 60%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "md3_decel", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "md3_accel", style = "popin 60%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, bezier = "md3_decel" })

-- Layers
hl.animation({ leaf = "layers", enabled = true, speed = 5, bezier = "menu_decel" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 5, bezier = "menu_decel", style = "slide right" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3, bezier = "menu_accel", style = "slide right" })

-- Fade
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 3, bezier = "md3_accel" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, bezier = "menu_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 4.5, bezier = "menu_accel" })
hl.animation({ leaf = "fadePopups", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadePopupsIn", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "fadePopupsOut", enabled = true, speed = 3, bezier = "md3_accel" })
hl.animation({ leaf = "fadeDpms", enabled = true, speed = 3, bezier = "md3_decel" })

-- Border
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "default", style = "loop" })

-- Workspaces
hl.animation({ leaf = "workspaces", enabled = true, speed = 7, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 7, bezier = "menu_decel", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 7, bezier = "menu_accel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "md3_decel", style = "slide" })

-- Zoom
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 3, bezier = "md3_decel" })
hl.animation({ leaf = "monitorAdded", enabled = true, speed = 3, bezier = "md3_decel" })
