# Quickshell Lockscreen — Design

Last updated: 2026-07-28

Replaces hyprlock entirely. Runs as its own Quickshell config so that a fault in the
island shell cannot take the lockscreen down with it.

## Lifecycle

Spawned to lock, exits once unlocked — the same model hyprlock used, and the reason
there is no long-running lock daemon to crash.

```
lock.sh  →  flock -n  →  qs -c lock
                            ├ Lock.lock()            on startup
                            ├ … authenticate …
                            ├ Lock.unlocking = true  exit animation
                            ├ Lock.locked = false    compositor unlocks
                            └ Lock.finished          +260ms → Qt.quit()
```

The gap between `locked = false` and `finished` is load-bearing: quitting while still
locked would strand the session with no client to unlock it.

`lock.sh` holds a flock because `hypridle`'s `lock_cmd`, the `SUPER+L` bind and
`loginctl lock-session` can all fire at once, and a second session-lock client
stacking on the first is not something the protocol recovers from cleanly.

## Independence

Nothing here imports from `~/.config/quickshell/island`. `config/`, `components/` and
the service layer are deliberate copies, trimmed to what the lockscreen uses.

The only things outside this directory it touches are shared *data*, never code:

| Path | Used for |
|---|---|
| `~/.config/colorschemes/.current-theme` | which palette is live |
| `~/.config/quickshell/colors/custom/<theme>.qml` | the palette itself |
| `~/.config/colorschemes/.current-wallpaper` | background image |
| `~/.cache/wallpaper_picker/thumbs_<theme>/` | still frame for video wallpapers |

### PAM

`pam/qs-lock`, loaded through `PamContext.configDirectory` (`pam_start_confdir(3)`,
needs PAM ≥ 1.4 — the system has 1.7.2). It used to borrow `/etc/pam.d/hyprlock`,
which disappears with the package.

The stack is spelled out rather than `include system-auth`: inside a confdir PAM
resolves `include` against *that* directory, so the include silently fails to find the
system file and authentication returns `PAM_PERM_DENIED`. It mirrors Arch's
`system-auth`, keeping `pam_faillock` so repeated wrong passwords back off exactly as
before.

## Files

| File | Responsibility |
|---|---|
| `shell.qml` | `WlSessionLock`, locks on start, quits on `Lock.finished` |
| `services/Lock.qml` | Lock/idle/auth state, PAM conversation, idle timer, caps-lock probe |
| `services/NetStatus.qml` | Minimal nmcli poll — one glyph's worth of state |
| `services/NowPlaying.qml` | Read-only MPRIS view |
| `services/Time.qml`, `Battery.qml` | Clock, UPower |
| `modules/LockSurface.qml` | Composition, key routing, entrance stagger, parallax |
| `modules/LockBackground.qml` | Wallpaper, blur, dim, scrim, drift, settle, parallax |
| `modules/LockClock.qml` | The stacked display clock |
| `modules/RollingDigits.qml` | One rolling numeral |
| `modules/LockStatus.qml` | Bottom edge: now-playing, status chips |
| `modules/LockInput.qml` | Password capsule, dots, shake, success morph |

`LockSurface` is independent of the session-lock protocol on purpose: it renders
identically inside a plain `PanelWindow`, which is what makes the whole look testable
without ever locking the machine.

## Layout

```
┌──────────────────────────────────────────┐
│  Tuesday, 28 July                        │
│                                          │
│                    19     ← Colors.accent│
│                    46     ← Colors.text  │
│                                          │
│              ╭──────────────╮            │
│              │ • • • •    🔒 │            │
│              ╰──────────────╯            │
│                                          │
│  ♪ art  title / artist        ⇪ ⛨ ▣ 87% │
└──────────────────────────────────────────┘
```

### The clock

Hour stacked over minute at `height * 0.155` (~168px at 1080p), Adwaita Sans Black.
Stacking lets the type run this large without spanning the screen, and it drops the
colon, which at display size reads as debris. Two details make or break it:

- **Negative leading** at `-0.36 × digitSize`, so the rows nearly touch. Adwaita Sans
  reserves ~1.3× the pixel size as line height; without clawing that back the gap
  reads as an accident.
- **Shared row width.** Digits are proportional, so `19` and `46` are never the same
  width, and a Column left-aligns its children. Both rows take `max(implicitWidth)`
  with centred text, measured off hidden labels — the visible rows clip and take their
  width *from* this, so reading it back off them would be a binding loop.

Separation from the wallpaper is a soft `MultiEffect` drop shadow, not a text outline,
which at this size would read as a sticker.

## Motion

| | |
|---|---|
| **Entrance** | Staged, not simultaneous: clock → date → input → status, 150/90/90ms apart. Clock rows slide in from opposite sides; date from the left; input and status rise. |
| **Wallpaper settle** | Background starts 6% wider and eases back as the blur ramps, so lock reads as a camera settling rather than a still being covered. |
| **Ambient drift** | 60s scale/translate cycle, so the background is never quite frozen. |
| **Pointer parallax** | Background leans *away* from the cursor by up to 16×11px, which reads as depth rather than as the image being dragged. |
| **Minute roll** | The outgoing numeral rises and fades while the incoming one comes up from below. |
| **Typing** | Capsule rim picks up the accent while there is something to submit. |
| **Failure** | 400ms shake, danger rim flash, dots cleared, PAM's own message below. |
| **Success** | Capsule collapses to a circle with a check, foreground lifts 4%, and the whole surface dissolves over 380ms — blur held to the end (see below). |
| **Idle (20s)** | Everything fades but the clock, which drops to 0.5 opacity and sinks 18px. Blur deepens. Waking replays the entrance stagger — the sequence is re-runnable for exactly this reason. |

## Non-obvious details

- **The unlock must NOT un-blur.** Easing blur and dim back to zero so the wallpaper
  sharpened seemed like the natural reverse of the entrance, but it exposed the
  trick: the source is decoded at 512px wide precisely *because* it is always
  blurred, so un-blurring put a visibly soft, low-resolution wallpaper on screen for
  the last half second of every unlock. Holding the blur and dissolving opacity
  instead means the real desktop wallpaper is what comes through.
- **The roll's crossfade finishes well before its movement does.** The negative
  leading makes the two rows' boxes overlap by ~60px, so `clip` on a row cannot stop a
  departing numeral straying over the row above — the fade has to do that work.
- **`NetStatus` hides its chip until the first reading lands.** The nmcli triple-call
  takes ~1.4s; until then every field is at its default and the icon would
  confidently show "no signal" on a perfectly good connection.
- **`NetStatus`'s bare `echo` is load-bearing.** `tr` emits no trailing newline, so
  without it the signal value lands on the end of the device line and the third line
  never exists — strength silently reads 0.
- **`PamContext` emits `error` *and* `completed` for the same failure.** Both firing
  `failed()` double-triggered the shake; `errorSeen` suppresses the second.
- **The lock surface is transparent** so the unlock reveal can show the desktop
  through it. `LockBackground`'s unconditional opaque base rectangle — not the surface
  colour — is what guarantees the desktop is never visible while locked.
- **No IPC unlock exists.** A call that could unlock the session would make the
  lockscreen worthless.

## What hyprlock left behind

Removed: `~/.config/hypr/hyprlock.conf`, `~/.config/hypr/hyprlock/` (both theme
variants and the wallpaper symlink), the symlink writes in `apply-theme.sh` and
`wallpaper-apply-post.sh`, the `hyprlock.conf` copies in both, and the dead
`/tmp/lock_bg.png` writes in the island's `WallpaperPicker.qml` — nothing read that
file; all three hyprlock configs used `path = screenshot`.

Rewired: `binds.lua` `SUPER+L` and `hypridle.conf`'s `lock_cmd` + 5-minute listener
now call `lock.sh`.

The `hyprlock` package itself is still installed. Removing it is
`sudo pacman -Rns hyprlock`; nothing in the config depends on it any more.

## Recovery

If the locker ever fails while the session is locked: **Ctrl+Alt+F2 → log in →
`loginctl unlock-session`**. That path does not depend on the shell, the locker, or
Hyprland.
