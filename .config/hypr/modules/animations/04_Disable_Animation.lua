-- ==================================================================== --
--  Animations off
--  Every animation disabled at the root. Nothing below `animations` is
--  evaluated, so this is genuinely zero cost rather than zero-duration.
--  Use when: recording the screen, remoting in, running on battery, or
--  chasing a compositor bug where motion hides what is happening.
--  Note: the shell's own QML animations are separate -- turn those off in
--  Settings > Shell > Motion (animScale 0).
-- ==================================================================== --

-- /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #

hl.config({ animations = { enabled = false } })
