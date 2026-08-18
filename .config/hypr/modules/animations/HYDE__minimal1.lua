-- ==================================================================== --
--  HyDE — Minimal 1
--  HyDE default minus the scratchpad animation. Windows and workspaces only.
--  Use when: you want a small, predictable set and don't use special workspaces.
-- ==================================================================== --

-- /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #
--
-- # name "Minimal-1"
-- credit https://github.com/prasanthrangan/hyprdots-

hl.config({ animations = { enabled = true } })

-- █▄▄ █▀▀ ▀█ █ █▀▀ █▀█   █▀▀ █░█ █▀█ █░█ █▀▀
-- █▄█ ██▄ █▄ █ ██▄ █▀▄   █▄▄ █▄█ █▀▄ ▀▄▀ ██▄
hl.curve("wind", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("winIn", { type = "bezier", points = { {0.1, 1.1}, {0.1, 1.1} } })
hl.curve("winOut", { type = "bezier", points = { {0.3, -0.3}, {0, 1} } })
hl.curve("liner", { type = "bezier", points = { {1, 1}, {1, 1} } })


--▄▀█ █▄░█ █ █▀▄▀█ ▄▀█ ▀█▀ █ █▀█ █▄░█
--█▀█ █░▀█ █ █░▀░█ █▀█ ░█░ █ █▄█ █░▀█
hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "wind", style = "slide" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 6, bezier = "winIn", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "winOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "wind", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 1, bezier = "liner" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "liner", style = "once" })
hl.animation({ leaf = "fade", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "wind" })

-- ---- Hyprland 0.56 additions ------------------------------------- --
-- Layer surfaces (bar, launcher, notifications, the settings overlay) had no
-- animation at all here, so they were the one thing that snapped. Fade, not
-- slide: these surfaces run their own entrance animations internally and a
-- compositor-side slide fights them.
-- glowangle/shadowangle are 0.56's siblings of borderangle: same rotation, for
-- decoration:glow:* and the shadow. Harmless when glow is off.
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "wind", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.4, bezier = "winOut", style = "fade" })
hl.animation({ leaf = "glowangle", enabled = true, speed = 30, bezier = "default", style = "once" })
hl.animation({ leaf = "shadowangle", enabled = true, speed = 30, bezier = "default", style = "once" })
hl.animation({ leaf = "fadeGlow", enabled = true, speed = 3, bezier = "wind" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 3, bezier = "wind" })
hl.animation({ leaf = "monitorAdded", enabled = true, speed = 3, bezier = "wind" })
