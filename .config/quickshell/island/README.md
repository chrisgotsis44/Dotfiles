# island — a Dynamic Island shell for Quickshell

One centered pill that IS the entire shell: it morphs between the
clock, a hover-expanded status strip, a volume OSD, notification
banners, and full menus (Control Center, launcher, calendar, power,
theme switcher) — no popup windows for any of those. The one deliberate
exception is the wallpaper picker (`modules/wallpaper/`): a full-screen
overlay in its own right, not a Section the pill morphs into — see
"Wallpaper picker" below.
Colors are NOT hardcoded: every widget reads from `config/Colors.qml`,
which follows whichever theme is currently active in the system theme
switcher (see "Theming" below) and updates live the moment you switch
themes — including from the island's own Themes menu.

## Run

```sh
qs -c island
```

Hyprland autostart + binds:

```conf
exec-once = qs -c island

bind = SUPER, Space, exec, qs -c island ipc call shell toggleLauncher
bind = SUPER, C,     exec, qs -c island ipc call shell toggleControlCenter
bind = SUPER, X,     exec, qs -c island ipc call shell togglePowerMenu
bind = SUPER, D,     exec, qs -c island ipc call shell toggleCalendar
bind = SUPER, V,     exec, qs -c island ipc call shell toggleClipboard
bind = SUPER, T,     exec, qs -c island ipc call shell toggleThemeMenu

# Big Island mode -- statically replaces the idle/hover pill with a wide
# workspaces | clock | sound/battery/power bar on every monitor, and
# disables the usual hover-to-expand while it's on. Toggle off to go
# back to the normal dynamic pill.
bind = SUPER, B,       exec, qs -c island ipc call shell toggleBigIsland

# System Dashboard (Performance / Weather / Customize) -- also reachable by
# right-clicking the pill outside a menu.
bind = SUPER, M,       exec, qs -c island ipc call shell toggleDashboard
bind = SUPER SHIFT, B, exec, qs -c island ipc call shell toggleDashboard

# Wallpaper picker -- full-screen overlay, not part of the pill's morph
# states (see "Wallpaper picker" below). Also reachable from the
# Dashboard's Customize tab.
bind = SUPER SHIFT, W, exec, qs -c island ipc call shell toggleWallpaperPicker

# Clipboard history backend (required for the clipboard manager)
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store

# Volume keys — the island OSD reacts automatically via PipeWire
bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindel = , XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
```

> The lines above go in whichever file your real Hyprland config sources
> its `bind = ...` lines from (e.g. `~/.config/hypr/hyprland.conf` or a
> binds file it `source`s) — this repo doesn't apply them anywhere. Add
> the ones you want yourself, check for collisions with existing binds,
> and `hyprctl reload`. Any of the `ipc call` ones can also be triggered
> by hand at any time, e.g. `qs -c island ipc call shell toggleBigIsland`.

## Dependencies

- **quickshell** (git; needs the `qs.*` import root, PipeWire/Mpris/UPower/Notifications services)
- **Material Symbols Rounded** font — `ttf-material-symbols-variable-git` (AUR).
  Without it, icons render as ligature names.
- **Adwaita Sans** (UI text) and **JetBrainsMono Nerd Font Propo**
  (numbers/status readouts) — both already installed on this system
- `nmcli` (NetworkManager), `brightnessctl`, `bluetoothctl`, `curl`
  (weather via wttr.in)
- `cliphist` + `wl-clipboard` for the clipboard manager
- `~/.local/bin/idle-inhibitor.sh` and `~/.local/bin/night-mode.sh` —
  user scripts run by the Display / Night Light tiles (stubs using
  `systemd-inhibit` / `wlsunset` are provided; replace freely)
- Hyprland (used for cursor-monitor detection via `Quickshell.Hyprland`)

> This shell registers itself as the notification daemon — stop
> mako/dunst/**swaync** (whichever is actually running) before starting
> it, or you'll see `Could not register notification server at
> org.freedesktop.Notifications` in the logs and the island's own
> notification banners will never fire (the other daemon's still handling
> them instead). Check with `busctl --user list | grep Notifications` to
> see who currently owns the name.

## Interactions

| Gesture                     | Action                                       |
|-----------------------------|----------------------------------------------|
| Hover the pill              | Expands: workspaces · time/date · weather    |
| Left-click pill             | Morph into Control Center                    |
| Middle-click pill           | Morph into the media player popup            |
| Right-click pill            | Morph into the System Dashboard              |
| `SUPER, K`                  | Morph into calendar                          |
| Scroll on pill              | Volume (morphs into the OSD)                 |
| Click during notification   | Dismiss it                                   |
| Click outside the island    | Close any open menu                          |
| `SUPER, B`                  | Toggle Big Island mode (see below)           |
| Big Island: click sound/power icons | Toggle mute / open Power Menu |
| CC tiles: left-click        | Toggle (Wi-Fi/Audio/BT/Display/Peace/Night)  |
| CC Wi-Fi/Audio/BT: right-click | Slide to detail list (networks/sinks/devices), Back returns |
| Esc (in launcher)           | Close launcher                               |
| Themes menu: click a theme, or ↑↓/j/k + Enter | Apply it (apply-theme.sh) and close the menu |
| `SUPER, Tab`                | Window switcher (sticky: Tab/←→ cycle, Enter or click commits, Escape cancels) |
| `ALT, Tab`                  | Window switcher (classic: hold ALT, tap Tab, release ALT to commit) |
| Launcher `=`                | Calculator — `=8*1024`, Enter copies the result |
| Launcher `:`                | Emoji picker — `:rocket`, Enter copies the glyph |
| Esc (in Themes menu)        | Close without applying                       |

Live Activities (`services/Activities.qml`) give the island a persistent
compact state: while one is running the idle pill carries a chip -- glyph
plus one live value -- on the left flank, with the clock still exactly
centred, and hovering expands into the `activity` section (one row per
activity, with controls) instead of the usual hover view. Activities
outrank the media art/visualizer for that flank, since an activity is
actionable where the spectrum is decoration. Scripts push their own:

```
qs -c island ipc call activity push   dl download "Downloading" "linux-firmware" "0%" 0
qs -c island ipc call activity update dl "linux-firmware" "63%" 0.63
qs -c island ipc call activity remove dl
```

Pushing an existing id updates it in place; `progress` is 0..1 or negative
for indeterminate. Script-pushed activities get a dismiss and no transport
controls -- the shell can't pause someone else's download.

`kind` is `"task"` (default) or `"mode"`. Modes are states you have left
switched on rather than work in progress, so they draw no progress track at
all -- an indeterminate bar would claim something is happening.

What currently produces one:

| Source | Activity |
|---|---|
| `services/Timers.qml`   | stopwatch, countdown timer, pomodoro |
| `services/GlobalState.qml` | Keep Awake and Peace, as modes -- **currently disabled**, see `keepAwakeActivity` / `dndActivity` |
| `WallpaperPicker.qml`   | thumbnail generation, with a real fraction parsed from `generate-thumbs.sh`'s `TOTAL`/`PROGRESS` output |
| `wallpaper-apply-post.sh` | matugen palette regeneration -- **currently disabled**, see `ISLAND_MATUGEN_ACTIVITY` |
| `island-activity.sh`    | any command at all, see below |

`~/.local/bin/island-activity.sh <icon> <title> -- <cmd...>` wraps an
arbitrary long-running command:

```
island-activity.sh package "System update" -- yay -Syu
island-activity.sh sync "Backing up" -- rsync -a ~/Documents /mnt/backup/
```

It runs the command in the background and `wait`s rather than in the
foreground, because bash defers trap handlers until a foreground child
finishes -- which left the chip stuck on the pill after a Ctrl-C, exactly
when cleanup matters. `< /dev/stdin` on the async command is what keeps
interactive commands (a password prompt) working, since a non-interactive
shell otherwise redirects an async command's stdin from /dev/null.

Notifications preempt whatever the island is showing, then it morphs
back to the previous state after 5 s. On multi-monitor setups, only the
island on the monitor the cursor is on reacts (hover, menus, OSD,
notifications) — the others stay as idle clocks.

The bar reserves a tight strip sized to the idle pill (even gap above
and below); every expanded state overlays application windows, like the
real Dynamic Island.

`SUPER, B` (`GlobalState.bigIslandMode`, global -- every monitor's
island switches together, including monitors the cursor isn't on) is a
wide, genuinely thin bar spanning almost the full screen width, that
overrides hover-to-expand while it's on (checked in `Bar.qml`'s
`islandState` right before the `hover` branch, so hovering does
nothing until you toggle it off again). It's a `RowLayout` with two
`Item { Layout.fillWidth: true }` spacers:

```
[ workspaces ]  <spacer>  [ clock ]  <spacer>  [ sound  battery  power ]
```

- **Width** — `biRoot.implicitWidth: root.modelData.width - outerGap*2
  - hPadding*2`, i.e. the screen's own width minus a small fixed gap on
  each side (`outerGap: 40`), not a sum-of-content pill. This is what
  makes it a genuinely wide bar instead of a scaled-up version of the
  normal pill.
- **Height** — `implicitHeight: 26`, close to the idle/hover pill's own
  content height, so the total pill stays thin (~48px) rather than
  thick.
- **Left** — this monitor's own workspaces, capped at 5, filtered
  straight off `Hyprland.workspaces` (a separate inline `Repeater`, NOT
  the shared `WorkspaceIndicator.qml` used by the hover state — that
  component's own look was intentionally left untouched). Every
  workspace is a plain `MonoText` number; ONLY the focused one gets a
  small solid accent-colored circle behind it. Anchored to the left
  edge of its slot.
- **Center** — a single-line clock (`Time.time`, Adwaita Sans, no
  stacked date). It sits exactly on the horizontal center of the bar
  because the two side slots (workspaces, right-side row) are both
  forced to the same width — `sideSlotWidth: Math.max(wsRow.implicitWidth,
  rightRow.implicitWidth)` — so the two `fillWidth` spacers either side
  of the clock always divide the remaining space evenly. Plain
  `anchors.centerIn: parent` would only center relative to leftover
  space, drifting off-true whenever the two sides differ in width —
  which they normally do.
- **Right** (`rightRow`, right-aligned in its slot) — three
  always-visible modules:
  - **Sound** — a mute-toggle icon (`Audio.toggleMute()`), same icon
    logic as the OSD's speaker icon.
  - **Battery** — icon + percent, only when `Battery.available` (a
    real laptop battery, via UPower's `isLaptopBattery` — never a
    mouse/keyboard's own battery).
  - **Power** — opens the existing Power Menu
    (`GlobalState.powerMenuOpen = true`) rather than calling
    `systemctl poweroff` directly — a single tap on an always-visible
    icon is too easy to hit by accident for a hard shutdown.

  (An earlier version of this also had a collapsible arrow that
  revealed the real system tray on hover — removed per feedback; the
  right side is just these three fixed modules now.)

`implicitWidth` here is screen-width-based, not a sum of the three
sections plus a fixed margin — that fixed-margin approach was the
actual bug behind an earlier version looking like "a short, thick,
squished pill": with a screen this wide, the margin was totally
insignificant next to the sum, and everything read as cramped together
in the middle.

## Wallpaper picker

`modules/wallpaper/` — SUPER+SHIFT+W, or the Dashboard's Customize tab.
Started life as `~/.config/quickshell/wallpaper`, a completely separate
`quickshell -p Main.qml` process with its own git repo, spawned and killed
by `wallpaper-selector.sh`/`wallpapers-set-matugen.sh` each time. It's
folded into the island now as its own `PanelWindow` in `shell.qml`
(`WlrLayer.Overlay`, `WlrKeyboardFocus.Exclusive`, full-screen, gated on
`GlobalState.wallpaperPickerOpen`) — same full-screen skewed-grid look and
feel as before, deliberately **not** a Section the pill morphs into like
every other menu.

The old process-per-open model meant the picker's `Settings.qml` got
backed up, rewritten with whichever theme's wallpaper folder was active,
and restored on exit by the wrapper script — and picking a wallpaper wrote
its path to `/tmp/qs_last_wallpaper` for that same wrapper script to read
*after the process had already exited* and do the real work (state file,
matugen regen). None of that works once the picker is a
permanent component that never exits, so:

- `modules/wallpaper/Settings.qml` replaces the rewritten-on-disk file:
  `wallpaperDir`/`thumbDir` are computed straight from `Colors.themeName`
  (which already tracks `~/.config/colorschemes/.current-theme` live), and
  `enableColorFiltering` (the Red/Orange/.../Monochrome filter chips) is
  just `Colors.themeName === "matugen"` — matugen's large varied wallpaper
  pool is the only place those ever made sense.
- `~/.local/bin/wallpaper-apply-post.sh [--set-live] <path>` replaces the
  wrapper scripts' post-exit bookkeeping: `applyWallpaper()` calls it
  directly (execDetached, right alongside the awww/mpvpaper call) instead
  of writing to a temp file. It reads `.current-theme` itself and either
  does the plain state-file/notify-send bookkeeping, or,
  only for the matugen theme, the full matugen regen + config-copy
  pipeline. `apply-theme.sh` also calls this directly (with `--set-live`,
  since nothing else has put the image on screen yet) when switching
  *into* matugen with a previously-saved wallpaper — this absorbed what
  used to be `wallpapers-set-matugen.sh --wallpaper <path>`, since both
  ended in the exact same ~50-line regen block. `wallpapers-set-matugen.sh`
  itself is gone now; its other job (opening the picker when there's no
  saved matugen wallpaper to fall back on) is just
  `qs -c island ipc call shell toggleWallpaperPicker` in `apply-theme.sh`
  directly — the old script's no-args branch still spawned the *original
  standalone* picker process, a leftover nobody had re-pointed at the
  integrated one until this pass caught it.
- `Qt.quit()` (there were two: the post-apply close timer, and Escape)
  is now `GlobalState.wallpaperPickerOpen = false` — quitting would have
  killed the whole island.
- Since this component is now constructed once at island startup instead
  of once per open, anything the standalone app got for free from
  `Component.onCompleted` on every launch (grabbing keyboard focus,
  resetting the color filter, kicking off thumbnail generation) has to be
  re-triggered explicitly on every open instead — see `onPickerOpened()`,
  called from `onVisibleChanged`'s visible-true branch.
- `import QtCore` was silently shadowing the picker's own `Settings` type
  with `QtCore`'s built-in `Settings` (QSettings-backed) element — the
  original file avoided this by having its local `import "config"` win
  instead. Not needed for anything else here, so it's just removed.

`~/.config/quickshell/wallpaper` (the old standalone repo) is no longer
used by anything. `wallpaper-selector.sh` and `wallpapers-set-matugen.sh`
have both been deleted outright — all of their jobs are covered above.

## Theming

`config/Colors.qml` is a live bridge, not a hardcoded palette. It watches:

- `~/.config/colorschemes/.current-theme` — one line, the active theme's name
- `~/.config/quickshell/colors/custom/<name>.qml` — that theme's palette

Both are `FileView`s with `watchChanges: true`, so switching themes in the
system theme switcher (or matugen regenerating its palette for a new
wallpaper) re-themes the whole shell instantly, no restart.

Matugen's own quickshell template
(`~/.config/matugen/templates/quickshell-colors.qml`) originally only
emitted 9 raw Material-3 tokens (`background`, `primary`, ...) and none of
the base-palette keys below — so every time matugen actually regenerated
`custom/matugen.qml` for a new wallpaper, the island silently fell back to
its defaults instead of following it. Fixed by extending that template to
also emit the compat block, mapped from matugen's own surface-container
ramp: `bg0`–`bg4` from `surface_container_lowest`→`...highest`, `grey0`–
`grey2` from `outline_variant`/`outline`/`on_surface_variant`, `green`
(accent) from `primary`, `red` from `error`.

`fg` is mapped to `primary_fixed`, not the more obvious `on_surface`.
`on_surface` is M3's plain "text on background" role and is deliberately
kept near-neutral (~25% saturation for a typical wallpaper) — next to a
hand-picked theme's fg (catppuccin: ~64%) it reads as flat/colorless,
most noticeably on the clock text (which binds straight to
`Colors.text`, i.e. `fg`). `primary_fixed` is matugen's
light-but-fully-chromatic tone from the same hue family and lands at
roughly the same saturation as a hand-picked fg, with no saturation math
involved — just picking the token matugen already generates for exactly
this purpose. One consequence: since it shares primary's hue, matugen
theme's text and accent read as the same hue family (different tones of
one wallpaper-derived color) rather than the deliberately different hues
hand-picked themes use for fg vs accent — that's an inherent trait of
wallpaper-driven theming, not a bug.

Only the "base palette" keys (`bg0`–`bg4`, `fg`, `red/orange/yellow/green/
aqua/blue/purple`, `grey0`–`grey2`) are read out of the theme file — those
are always literal hex there. The semantic tokens the shell actually binds
to (`Colors.bg`, `Colors.accent`, `Colors.danger`, ...) are derived from
that base palette the same way for every theme, since the theme files'
own "Semantic / Material Mappings" section sometimes just aliases another
key in the same file (e.g. `accent: primary`) rather than a literal color,
which isn't safe to pull out with a regex. If a theme file is missing or
fails to parse, `Colors.qml` falls back to its original hardcoded palette
so the shell never breaks.

## Architecture

```
shell.qml                 root: island bar per screen, click-away catcher, IPC
config/
  Colors.qml              live theme bridge (singleton) — see "Theming" above
  Appearance.qml          metrics, durations, bezier curves (singleton)
services/                 system state — all singletons
  GlobalState.qml         UI state hub: menu visibilities, island inputs,
                          DND, script-backed Display/Night Light toggles
  Audio.qml               PipeWire default sink + all sinks (detail view)
  Media.qml               MPRIS w/ Spotify priority + on-disk last-session
                          cache (survives player exit and shell restarts)
  Activities.qml          Live Activities store: ongoing things worth a
                          glance (timer, download, recording, build). Owns
                          no domain logic -- Timers pushes one, scripts push
                          their own over IPC (target "activity")
  Windows.qml             open windows via wlr-foreign-toplevel-management,
                          plus the switcher's selection state
  Timers.qml              stopwatch + countdown timer + pomodoro; pushes
                          all three into Activities. Pomodoro lengths and
                          the clock tile's mode persist to
                          ~/.cache/qs-island-timers.json
  Weather.qml             wttr.in temp/condition/humidity/wind, 30 min
  Clipboard.qml           cliphist history + image thumbnail decoding
  Network.qml             nmcli status + network scan list + wired
                          (ethernet) connection detection
  Bluetooth.qml           bluetoothctl power + device list
  Battery.qml             UPower display device
  Brightness.qml          brightnessctl, debounced writes
  Notifs.qml              NotificationServer (the shell IS the daemon)
  Time.qml                SystemClock formatting
  Themes.qml              theme list, active theme + wallpaper-state watch,
                          per-theme swatches read live from each theme's own
                          custom/*.qml (blue/purple/green -- NOT bg0, which
                          is near-black for every dark theme by definition
                          and made every swatch's first dot converge on the
                          same color), apply() -> apply-theme.sh,
                          openWallpaperPicker() toggles
                          GlobalState.wallpaperPickerOpen (see
                          modules/wallpaper/ below)
  AppUsage.qml            launch counts per DesktopEntry.id, persisted to
                          ~/.cache/qs-island-app-usage.json (debounced
                          writes) -- backs the launcher's frequency sort
  SysMonitor.qml          dashboard stats: CPU (/proc/stat + k10temp),
                          GPU (nvidia-smi), memory, net speeds, disks --
                          one aggregated 2s poll, ONLY while the
                          dashboard is open
  HyprConfig.qml          animation presets (same symlink+reload
                          mechanism as animation-switcher.sh) + live
                          blur/shadow/border on-off toggles AND their
                          actual values (size, passes, vibrancy, range,
                          render power, sharp, border size), plus gaps
                          in/out, active/inactive window opacity, and
                          corner rounding + rounding power -- no
                          decoration-preset switcher (that folder is
                          now a fixed, hand-edited config).
                          Applied via `hyprctl eval 'hl.config({...})'`
                          with a Lua table literal, NOT `hyprctl keyword`
                          -- this config uses Hyprland's Lua parser
                          (hl.config({...}), see modules/decoration/*.lua),
                          and `keyword` errors with "can't work with
                          non-legacy parsers. Use eval." there. gaps_in/
                          gaps_out read back from hyprctl as a 4-value
                          CSS-margin-style string (e.g. "9 9 9 9") even
                          when configured with one uniform number --
                          only the first value is used.

                          Every change is ALSO written back into
                          blur.lua/shadow.lua/decoration.lua on disk
                          (debounced ~500ms, like AppUsage.qml's cache
                          writes), via a plain in-place `sed` substitution
                          on the one line matching that field's name --
                          these files are small and consistently
                          formatted (`key = value,` per line), so a
                          per-field regex is enough; no real Lua parser
                          involved. This is what makes a value survive a
                          reload, a crash, or just closing the bar --
                          without it, hyprctl eval only changes the
                          *running* compositor state, and the next reload
                          (or restart) would silently revert to whatever
                          was last on disk. If you hand-edit one of these
                          files and change its formatting (e.g. drop the
                          trailing comma, rename a field), the matching
                          `sed` silently stops finding anything to
                          replace -- the live hyprctl change still
                          applies, it just won't persist until the
                          formatting matches again.

                          Verified live end-to-end, not just a clean QML
                          load: called the real setters through a
                          temporary debug IPC hook, confirmed both
                          hyprctl getoption AND the actual file contents
                          changed, then restored the files from a backup
                          and diffed byte-for-byte to confirm a clean
                          restore.
components/               dumb, reusable primitives
  StyledRect / StyledText / MaterialIcon / IconButton / CcSlider /
  ToggleSwitch (iOS-style animated switch)
modules/
  bar/                    Bar.qml — the island + its whole state machine,
                          WorkspaceIndicator (per-monitor, max 5), WeatherPill
  controlcenter/          ControlCenterContent (main grid + sliding detail
                          pages), CcToggle (badgeIcon overlay -- e.g. the
                          Wi-Fi tile's ethernet badge when wired is also
                          connected), DetailView, WeatherCard (between
                          sliders and clocks), TimerTile, NotifCard; the
                          brightness slider hides when no backlight exists
  launcher/               LauncherContent -- with no query, most-launched
                          apps sort first (rofi-style); while typing, they
                          break ties among equally-good text matches
  clipboard/              ClipboardManager — cliphist search + text/image
                          previews, launcher-style UI
  calendar/               CalendarContent
  power/                  PowerMenuContent
  thememenu/              ThemeMenuContent — the system theme switcher,
                          folded into the island: theme list + live swatches
                          on the left, wallpaper preview on the right;
                          mouse or full keyboard nav (↑↓/jk, Enter, Esc)
  dashboard/              Dashboard (right-click the pill or SUPER+M) —
                          animated Performance/Customize segmented tabs
                          (Performance left, Customize right);
                          Performance: StatCard grid (CPU/GPU tiles w/
                          temp bar + usage squircle, Storage w/ ring for
                          the drive mounted at "/" -- no picker, Memory
                          ring, Network speeds, vertical fluid battery
                          pill w/ gradient fill + graph-style 25/50/75%
                          guide lines, hidden entirely unless a real
                          battery exists -- no fallback to other UPower
                          devices); Customize: two centered 100x100 square
                          quick-action buttons above Animations (Theme ->
                          morphs into the island's own Themes menu via
                          GlobalState.themeMenuOpen; Wallpaper -> opens
                          the wallpaper picker overlay and closes the
                          dashboard), animation preset chips,
                          expandable Blur/Shadows/Borders effect rows --
                          tap a row (not its switch) to reveal its actual
                          values as sliders (size, passes, vibrancy,
                          range, render power, sharp, border size) -- and
                          a Window card with the same expand pattern but
                          no switch (Gaps: in/out; Opacity: active/
                          inactive; Rounding: radius + power), all live
                          via hyprctl eval. EffectRow/EffectSlider are
                          root-scoped components (not nested in one
                          card) so every Customize card can reuse them,
                          and each EffectRow's expand state is local to
                          itself, not a shared accordion -- opening one
                          doesn't close another. Each row's tap-to-expand
                          zone stops BEFORE its switch (doesn't span the
                          full row) -- sibling TapHandlers don't reliably
                          respect item z-order for exclusivity the way
                          MouseArea hit-testing did, so a full-row
                          TapHandler was ALSO firing when the switch
                          itself was tapped, expanding the submenu on
                          every on/off flip. A submenu's own height
                          Behavior uses Appearance.anim.durations.menu
                          (550ms, shared with the island's own inMenu
                          resize in Bar.qml) rather than the shorter
                          .normal (300ms), so the reveal doesn't outrun
                          the island's own resize mid-animation --
                          CircularProgress = Shape-based ring
```

Since each EffectRow's submenu now expands independently rather than as
a shared accordion, several can be open at once -- with the quick-action
buttons and animation presets above them, that comfortably exceeds
Bar.qml's `PanelWindow.implicitHeight`, which isn't just a starting
size but a hard Wayland surface ceiling: content taller than it gets
clipped by the surface boundary itself, no matter how well an inner
animation is timed against the island's own resize (matching durations
above fixes the animation lagging behind mid-reveal, but not a
persistently-too-short ceiling). Bumped from 900 to 1500 to cover
Blur+Shadows+Borders+Gaps+Opacity+Rounding all expanded simultaneously.
The window is transparent and only the island (its own
ClippingRectangle) is ever visible, so there's no real cost to
over-provisioning this rather than tuning it to the exact pixel.

**How the morph works:** the bar window is a fixed transparent strip
with an input mask over the pill. Each island state is a crossfading
Section (Loader); the pill — a ClippingRectangle — binds its implicit
size to the active section and `Behavior`s on width/height/radius turn
every state switch into a smooth morph. Pill↔pill transitions use an
overshoot curve; pill↔menu transitions use a pure decelerate curve.
Menu contents are transparent Items: the island itself is their panel.

**Data flow** is strictly one-directional: services own system state,
widgets bind to it and call service functions to mutate it. `GlobalState`
owns UI state only (which menu the island is morphed into, transient
OSD/notification flashes) — flip one of its booleans from anywhere and
the island follows.
