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
bind = SUPER, S,     exec, qs -c island ipc call shell toggleSettings

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

> This shell also owns `org.kde.StatusNotifierWatcher` for the system
> tray (see "System tray" below), so it conflicts with any other tray
> host the same way it does with another notification daemon — don't run
> waybar's tray, a panel, or `snixembed` alongside it. Check with
> `busctl --user list | grep StatusNotifierWatcher`.

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
| Tray icon: left-click       | Activate the app (or open its menu if that's all it has) |
| Tray icon: right-click      | Morph into that app's menu                   |
| Tray icon: middle-click     | Secondary activate                           |
| Tray icon: scroll           | Passed through to the app (mixer applets use it) |
| Tray menu: click a submenu  | Drills in; the header becomes a Back row     |
| Click during notification   | Dismiss it                                   |
| Click outside the island    | Close any open menu                          |
| `SUPER, B`                  | Toggle Big Island mode (see below)           |
| Big Island: click sound/power icons | Toggle mute / open Power Menu |
| CC tiles: left-click        | Toggle (Wi-Fi/Audio/BT/Display/Peace/Night)  |
| CC Wi-Fi/Audio/BT: right-click | Slide to detail list (networks/sinks/devices), Back returns |
| Esc (in launcher)           | Close launcher                               |
| Themes menu: click a theme, or ↑↓/j/k + Enter | Apply it (apply-theme.sh) and close the menu |
| `SUPER, S`                  | Settings panel (centered overlay: shell config, Hyprland effects/window/animations) |
| `SUPER, Tab`                | Window switcher (sticky: Tab/←→ cycle, Enter or click commits, Escape cancels) |
| `ALT, Tab`                  | Window switcher (classic: hold ALT, tap Tab, release ALT to commit) |
| Launcher `=`                | Calculator — `=8*1024`, Enter copies the result |
| Launcher `:`                | Emoji picker — `:rocket`, Enter copies the glyph |
| Esc (in Themes menu)        | Close without applying                       |

## Settings panel & runtime config

`SUPER+S` opens the Settings panel (`modules/settings/SettingsPanel.qml`).
Like the wallpaper picker -- and unlike every menu -- it is NOT a Section
the pill morphs into: it's a centered overlay with a search field, a
category sidebar (Shell / Island / Modules / Monitors / Theme / Apps /
Effects / Window / Animations / About)
and a scrollable page, the same shape as caelestia's and
DankMaterialShell's settings windows. A settings surface is a place you
stay and adjust several things, not a state the island passes through.
Opening it closes whatever island menu is up.

There is deliberately **no scrim**: dimming the whole desktop to show one
panel is heavier than the panel deserves. Separation comes from six
stacked translucent rounded rects behind the card instead. That is not
laziness about `MultiEffect` -- MultiEffect renders its *source* itself,
so shadowing an interactive card means hiding the real one and losing
every click in it.

Click-away and Escape both close it, and both have a subtlety worth
keeping:

- The outside catcher is a **MouseArea, not a TapHandler**. A TapHandler
  takes a passive grab and does not consume the press, so a full-screen
  one fires even when the click landed on the card above it -- which
  meant clicking *any* control in the panel also closed the panel. The
  card declares its own MouseArea first, purely to eat presses on dead
  area before they reach the catcher. Same reasoning as Bar.qml's
  backdrop.
- Escape **clears a non-empty search query first** and only closes on a
  second press.

Search matches against a flat declarative index of every setting
(`card.searchIndex`) rather than scraping the built pages -- only one
page is ever instantiated, so a live scrape could never match settings
on the other five. Selecting a result jumps to its page. `↑`/`↓` move
between categories.

Each Shell section has its own reset; About has a global one, plus the
Quickshell version, the paths involved, and buttons to open config.json
or restart the shell.

`CcSlider` no longer adjusts on the mouse wheel: it is `wheelEnabled:
false` by default and hands the event back (`accepted = false`) so an
enclosing Flickable scrolls instead. A slider that changes under the
wheel is a trap anywhere it sits inside something scrollable -- in this
panel, scrolling the page over a slider silently edited the setting. Set
`wheelEnabled: true` per-slider on a surface that does not scroll (the
Control Center, if you want volume-by-scroll back there).

Two backends sit behind one UI, and each page's footer says which:

- **Shell** writes `~/.config/island/config.json` through
  `config/Config.qml` (FileView + JsonAdapter, atomic writes, debounced
  save). The file is watched, so hand edits hot-reload into the running
  shell -- and into the panel's own sliders -- live. A missing file or
  key falls back to the defaults declared on the adapter, and the file is
  created from those defaults on first run.
- **Effects / Window / Animations** are the Dashboard's old Customize tab
  (`hyprctl keyword` + persist into the Hyprland config via HyprConfig),
  moved here wholesale. The Dashboard is Performance | Weather now.
- **Theme** drives the Themes service directly -- a grid of every scheme
  with its real accent/blue/purple swatches, so switching no longer means
  leaving the panel for the island's Themes menu.

The mechanism throughout is that `Appearance.qml`'s tokens are readonly
BINDINGS to Config rather than literals, so all ~90 call sites go live
without touching any of them. Values are clamped where they are consumed,
so a hand-edited `"fontSize": 400` cannot render the shell unusable.

**Text size is the exception, and it needed its own mechanism.**
`Appearance.font.size` is only the *default* for StyledText, and all 218
call sites set `font.pixelSize` themselves -- which replaces the binding
outright. So the setting did nothing: it changed the size of text that
had not asked for one, of which there was none. Every explicit size now
goes through

```qml
font.pixelSize: Appearance.font.px(13)
```

which scales relative to a base of 15 and rounds (a fractional
`pixelSize` renders blurry). Icons go through it too -- `MaterialIcon`'s
default and the `iconSize`/`textSize` properties on IconButton and
BatteryPill -- so glyphs keep pace with the text beside them instead of
the layout coming apart. `modules/wallpaper/` is deliberately excluded:
it has its own `Scaler.qml` and would double-scale.

Anything new should use `Appearance.font.px(n)` rather than a bare
number, or it will be the one thing on screen that ignores the setting.

config.json keys, by the page that owns them:

| Page | Keys |
|---|---|
| Shell | `fontSize` `fontFamily` `roundingScale` `barTopMargin` · `borderEnabled` `borderWidth` `borderOpacity` `borderAccentOnMenu` `borderAccentOpacity` · `animScale` `islandSnappy` · `osdDurationMs` `notifDurationMs` |
| Island | `barHPadding` `barVPadding` `hoverGraceMs` · `maxWorkspaces` `bigIslandGap` · `showTray` `trayIconSize` |
| Modules | `clock24h` `showSeconds` `dateFormat` · `volumeStep` `cavaBars` · `launcherMaxResults` `clipboardLimit` · `weatherRefreshMin` · `showTimer` `showPomodoro` `showUpdates` |

Two of those are worth knowing about:

- `barVPadding` feeds the reserved exclusive zone, so raising it moves
  tiled windows down -- it is the one appearance setting with a
  compositor-visible side effect.
- `islandSnappy` is the pill-morph tempo (fast spatial token at 350ms vs
  the default at 500ms). It used to be a two-word source edit; it is a
  switch now because it was always the subjective call in the motion
  system.

`cavaBars` only lands the next time cava starts, since cava is spawned
with its bar count baked into a generated config and only runs while
music is playing.

The island's border is `borderEnabled` / `borderWidth` /
`borderOpacity`, plus `borderAccentOnMenu` and `borderAccentOpacity` for
the accent rim shown while a menu is open. Only the rim's *alpha* is
configurable -- the hue is taken from the active palette's own border
colour, so it still follows the theme.

Two pages drive things outside config.json entirely:

**Monitors** (`services/Monitors.qml`) reads `hyprctl monitors all -j`
and applies with `hyprctl eval` + `hl.monitor{...}`. Not `hyprctl keyword
monitor`, which is the obvious call and refuses outright here: this
Hyprland config is Lua, and keyword answers *"keyword can't work with
non-legacy parsers. Use eval."* Changes are **live only** -- nothing is
written back to `modules/monitors.lua`, which is hand-written Lua with a
workspace-rule loop in it, and a Hyprland reload restores whatever it
declares. The last active output has no disable switch, since turning it
off would leave no screen to turn it back on from.

**System update** (`services/Updates.qml`) is the slim strip in the
Control Center, below the clock tiles. Deliberately a strip and not a
tile in the grid: it is something you act on occasionally, not a state
you toggle, and a full tile would put "run a system upgrade" one stray
click from the Wi-Fi switch. Muted while there is nothing to do, accent
only when there is; clicking it with nothing pending re-checks rather
than launching an upgrade that would report nothing to do.

Counting is split because the halves fail differently. `checkupdates`
handles repos -- it syncs a *temporary* pacman database rather than
`/var/lib/pacman/sync`, which is the whole reason to prefer it over
`pacman -Sy`: no root, and it cannot leave the real database half-synced
and turn a later `-Syu` into a partial upgrade. `yay -Qua` handles the
AUR and needs the network, so `aurOk` is tracked separately and the row
says "AUR unavailable" rather than quietly reporting a smaller number.

The upgrade itself runs interactively in kitty, wrapped in
`island-activity.sh`, so the pill carries a live chip for its duration --
this is the Live Activities API's intended use, and interactive because
a full upgrade asks for a sudo password and may need conflicts resolved.
Doing it silently is how an upgrade wedges on a prompt nobody can see.

It is **not** a bare `yay -Syu`. That does repos and AUR in one pass and
resolves AUR packages *before* installing anything, so one unreachable
RPC aborts the lot and the repository packages -- which need nothing
beyond the mirrors -- never install at all. Not hypothetical: it happened
on the first real click, with 52 repo updates pending and the AUR RPC
returning a TLS EOF.

`runUpdate()` runs the two in sequence instead:

1. `sudo pacman -Syu` — repositories, no AUR involvement at all
2. `yay -Sua` — AUR only, no repo re-sync

with asymmetric failure handling that matters in both directions:

- **Phase 1 failing stops the run.** A cancelled or failed repo upgrade
  followed by AUR builds would compile packages against libraries that
  were about to change -- the partial-upgrade trap.
- **Phase 2 failing does not fail the script.** The AUR RPC being down is
  routine and non-fatal once the repos are done, and a non-zero exit
  there would make `island-activity.sh` report the whole update as failed
  when the important half succeeded.

**Apps** (`services/DesktopTheme.qml`) is GTK and Qt theming for the
applications, not the shell. It writes to every place that matters
because no single one covers all apps: `gsettings` (running GTK apps,
live), `gtk-3.0`/`gtk-4.0/settings.ini` (apps that ignore XSETTINGS, and
new launches), `qt5ct`/`qt6ct.conf` (Qt apps, next start),
`kvantummanager --set`, and `hyprctl setcursor` -- that last one because
gsettings alone does not reach the compositor's own cursor, which is what
`sync-cursor.sh` has always done by hand.

Toolkit fonts are the one setting stored in two very different shapes:
GTK keeps a single string (`Adwaita Sans 14`), Qt a 17-field serialized
`QFont` where only field 0 (family) and 1 (point size) matter here. Both
are split into family/size so the panel can drive them independently,
and `setGtkFontSize`/`setGtkFontFamily`/`setQtFont` all **refuse when the
family is empty**: this singleton is lazy and its read is async, so
touching it and immediately setting a size once composed `"" + " 13"` and
wrote a font with no family at all, which Qt and GTK both resolve to
silent fallback.

Scope against the theme switcher: `apply-theme.sh` owns the *colour
scheme* (GTK theme name via gsettings, GTK4 css symlinks, Kvantum
kvconfig). The Apps page owns what that script does not touch -- icon
theme, cursor theme and size, fonts, Qt style -- plus the GTK and Kvantum
theme names, on the understanding that applying a shell theme later
overwrites those two. The page says so.

The adapter normalises the file once per session on load, so a
config.json written by an older version gains every new key rather than
staying half-empty and leaving the new settings undiscoverable by hand.

## Motion

`config/Appearance.qml` carries the full Material 3 *Expressive* token set
-- twelve curves, each with the duration it is meant to run at.
`components/Anim.qml` bundles the two so they cannot be mismatched:

```qml
Behavior on x { Anim { type: Anim.DefaultSpatial } }
```

The distinction that decides which half of the list to reach for:

- **spatial** -- things that MOVE or RESIZE. Underdamped, so they overshoot
  slightly and settle. This is what reads as alive rather than computed.
- **effects** -- things that FADE or RECOLOR. Critically damped. Opacity
  past 1 is clamped, and a colour that overshoots just looks like a bug.

Three things about how the island uses them are deliberate:

- **The content's spatial tempo IS the island's spatial tempo.** They used
  to differ -- content settled in 300ms inside a box that kept growing for
  another 200 -- and the tell was content sitting perfectly still while
  its container was visibly still moving. Sharing one number is what makes
  the two read as a single object.
- **Section enter and exit are asymmetric.** With one duration for both,
  the outgoing and incoming sections sit at ~50% opacity together halfway
  through and you read the overlap as a double exposure. The outgoing one
  accelerates away in half the time so the incoming has clean air.
- **Menus still use pure decelerate, not an expressive curve.** Two
  reasons: a 700px panel overshooting by ~70px looks unhinged, and
  decelerate is the only family that reaches full size *early*, which is
  what stops content being clipped by a container still on its way out.

`durations.fast/normal/expand/menu` and `curves.standard/emphasized/
expressive` are kept as-is under their old names -- roughly 90 call sites
across this shell and the lock shell are tuned against them. Note that
`curves.emphasized` is really M3's *emphasizedDecel*; the true two-segment
emphasized curve is `emphasizedFull`.

The lock shell has its own `config/Appearance.qml` and was not touched.

## System tray

`modules/bar/TrayRow.qml` is a StatusNotifierItem host rendered as a plain
row of icons. It lives in Big Island's right cluster and nowhere else --
left of sound/battery/power, so the shell's own controls stay pinned to
the edge where muscle memory expects them. It collapses to nothing when no
app has registered.

Deliberately NOT in the hover strip. Hovering is a glance at time, date,
workspaces and weather; the tray is a set of click targets whose width
changes as apps come and go, and a strip that resizes under the pointer
is a strip you misclick. `SUPER+B` is where the tray lives.

Everything registered is drawn. The SNI spec's `Passive` status nominally
means "nothing to show", but enough apps register `Passive` and never move
off it that filtering on it hides exactly the icons whose absence people
notice — so `Passive` is only dimmed, and `NeedsAttention` gets an accent
badge.

Menus are the interesting part. A tray item hands you a DBus menu, and the
obvious way to show it — the item's own `display()`, or a `QsMenuAnchor` —
opens a real platform popup window: a second surface, styled by Qt rather
than by us, floating next to a shell whose one rule is that there are no
popup windows. So `modules/bar/TrayMenuContent.qml` walks the same menu
with `QsMenuOpener` and draws it as an island Section instead, with the
shell's own type, colors and rounding.

Submenus **drill** rather than cascade — a cascading menu needs somewhere
to put the second column, and the island is a centred pill with no notion
of "to the right of". Entering a submenu replaces the list and turns the
header into a Back row.

Two things in there are deliberate and look like oversights:

- **Labels render verbatim, mnemonic underscores and all.** Stripping them
  is the obvious-looking thing to do and it is wrong: almost nothing on
  this bus sends mnemonics, while plenty of entries are user data with
  real underscores. Stripping turned the SSID `Chris_Internet-Panw_5G`
  into `ChrisInternet-Panw5G`.
- **Every delegate reads `modelData` through null-guarded aliases.** A
  DBus menu updates in place — nm-applet rewrites its whole list as
  networks come and go — and `QsMenuEntry` objects are destroyed on the
  C++ side while the ListView still holds delegates bound to them.
  Reading properties off `modelData` directly throws a TypeError on every
  such update.

The `SystemTray` singleton is touched once in `shell.qml` at startup.
Owning `org.kde.StatusNotifierWatcher` is a side effect of that singleton
being constructed, and QML singletons construct on first access — without
it the watcher would not exist until the first time you hovered the pill,
and an autostarted tray app that races the shell at login and never
re-registers would be invisible for the rest of the session.

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
