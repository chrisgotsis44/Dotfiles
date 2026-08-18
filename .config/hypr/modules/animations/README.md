# Animation presets

Swapped by symlinking `../animations.lua` at one of these, then
`hyprctl reload` — the shell's Settings ▸ Animations page does exactly that.
Every file opens with a header describing its character and when to reach for it.

| Preset | Character |
|---|---|
| `04_Disable_Animation` | Off. Recording, remoting, battery, or debugging. |
| `default` | Hyprland stock. Popin 87%, workspaces cross-fade, no movement. Calmest full set. |
| `03defaultv3` | Stock with popin 95% and workspaces that slide-fade 10%. |
| `00default` | JaKooLit default. Sliding windows, overshooting workspaces, **looping** border. |
| `01default__v2` | Older JaKooLit. Bouncy popin windows. |
| `Mahaveer__me2` | 00default plus directional workspacesIn/Out. |
| `Mahaveer__me1` | Big curve library, conservative wiring. Good experimenting base. |
| `END4` | end-4 / illogical-impulse. Material 3 easing, popin 60%, layers slide from **left**. |
| `maximum` | Every branch of the tree set explicitly. Nothing falls back. Tuning reference. |
| `riverine` | Material curves, **vertical** workspaces and scratchpad. |
| `riverinehorizontal` | Riverine with horizontal workspaces, layers slide from **right**. |
| `HYDE__default` | hyprdots standard. Slide windows, vertical scratchpad, border sweeps **once**. |
| `HYDE__minimal1` | HyDE default minus the scratchpad. |
| `HYDE__minimal2` | Smallest set that still animates. One curve, uniform speed. |
| `HYDE__optimized` | HyDE retuned shorter and flatter for modest hardware. |
| `HYDE__Vertical` | Vertical-first: workspaces slide-fade vertically 30%. |
| `ML4W__standard` | ML4W baseline. |
| `ML4W__classic` | Minimal ML4W. Popin 80% on close only. |
| `ML4W__dynamic` | ML4W's liveliest, **looping** border. |
| `ML4W__high` | Dynamic's motion, border sweeps **once**. |
| `ML4W__fast` | Short durations. Present but never in the way. |
| `ML4W__moving` | Movement over scale; also animates `fadeDim`. |
| `slipstream` | Uniform, direction-free motion. |
| `vertical` | Slipstream with vertical workspaces. |

## What changed for Hyprland 0.56

- **`glowangle` / `shadowangle`** — 0.56 siblings of `borderangle`, driving
  `decoration:glow:*` and the shadow. Added wherever `borderangle` was already
  animated, inheriting its style and speed. Inert while `decoration:glow:enabled = false`.
- **`fadeGlow`** — the glow's own fade.
- **`specialWorkspaceIn` / `specialWorkspaceOut`** — the scratchpad's entrance and
  exit can now differ; exit is quicker, since you are already looking away.
- **`zoomFactor`**, **`monitorAdded`** — the zoom keybind and monitor hotplug.
- **`layersIn` / `layersOut`** — added to the presets that had no layer animation at
  all. Layer surfaces are the bar, launcher, notifications and the settings overlay,
  so they were the one thing that snapped. Deliberately `fade`, not `slide`: those
  surfaces run their own entrance animations and a compositor-side slide fights them.

## Fixed

- `HYDE__optimized` defined `easeInOutCirc` twice; the earlier `{0.75,0}` copy was
  dead code and has been removed.
