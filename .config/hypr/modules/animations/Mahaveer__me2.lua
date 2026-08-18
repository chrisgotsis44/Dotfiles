-- ==================================================================== --
--  Mahaveer — Me-2
--  Close to 00default -- sliding windows, looping borderangle -- but adds explicit
--  workspacesIn/Out so entering and leaving a workspace differ.
--  Use when: you want 00default with directional workspace transitions.
-- ==================================================================== --

-- /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #
--
-- name "Me-2"
-- credit https://github.com/mahaveergurjar


hl.config({ animations = { enabled = true } })

hl.curve("wind", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("winIn", { type = "bezier", points = { {0.1, 1.1}, {0.1, 1.1} } })
hl.curve("winOut", { type = "bezier", points = { {0.3, -0.3}, {0, 1} } })
hl.curve("liner", { type = "bezier", points = { {1, 1}, {1, 1} } })
hl.curve("overshot", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("smoothOut", { type = "bezier", points = { {0.5, 0}, {0.99, 0.99} } })
hl.curve("smoothIn", { type = "bezier", points = { {0.5, -0.5}, {0.68, 1.5} } })

hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "wind", style = "slide" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "winIn", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "smoothOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "wind", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 1, bezier = "liner" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "liner", style = "loop" }) --used by rainbow borders and rotating colors
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "smoothOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "overshot" })

-- animations for -git or version >0.42.0
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 5, bezier = "winIn", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 5, bezier = "winOut", style = "slide" })

-- ---- Hyprland 0.56 additions ------------------------------------- --
-- Layer surfaces (bar, launcher, notifications, the settings overlay) had no
-- animation at all here, so they were the one thing that snapped. Fade, not
-- slide: these surfaces run their own entrance animations internally and a
-- compositor-side slide fights them.
-- glowangle/shadowangle are 0.56's siblings of borderangle: same rotation, for
-- decoration:glow:* and the shadow. Harmless when glow is off.
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "smoothOut", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.4, bezier = "winOut", style = "fade" })
hl.animation({ leaf = "glowangle", enabled = true, speed = 100, bezier = "default", style = "loop" })
hl.animation({ leaf = "shadowangle", enabled = true, speed = 100, bezier = "default", style = "loop" })
hl.animation({ leaf = "fadeGlow", enabled = true, speed = 3, bezier = "smoothOut" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 3, bezier = "smoothOut" })
hl.animation({ leaf = "monitorAdded", enabled = true, speed = 3, bezier = "smoothOut" })
