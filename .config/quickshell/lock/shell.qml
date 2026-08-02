import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules
import qs.services

// Standalone Quickshell lockscreen.
//
// A separate config from the island on purpose: the lock must not be able
// to die because the shell did. Nothing here imports anything from
// ~/.config/quickshell/island, and the PAM policy ships in pam/qs-lock, so
// the only things this depends on are Quickshell itself and the theme
// files under ~/.config/colorschemes.
//
// Spawned to lock and exits once unlocked -- the same lifecycle hyprlock
// had. Launch it via lock.sh, which holds a flock so a second press of the
// keybind cannot stack a second locker on top of the first.
ShellRoot {
    WlSessionLock {
        locked: Lock.locked

        WlSessionLockSurface {
            // Transparent so the unlock reveal can show the desktop
            // through the fading surface. LockBackground carries an
            // unconditional opaque base rectangle -- that, not this, is
            // what guarantees the desktop is never visible while locked.
            color: "transparent"

            LockSurface {
                anchors.fill: parent
            }
        }
    }

    // Locking is the whole reason this process exists, so it happens at
    // startup rather than waiting to be told. There is deliberately no IPC
    // unlock: a call that could unlock the session would make the
    // lockscreen worthless.
    Component.onCompleted: Lock.lock()

    Connections {
        target: Lock

        // Fired a beat after `locked` drops, so the compositor has already
        // been told to unlock before this process goes away -- quitting
        // while still locked would strand the session with no client.
        function onFinished(): void {
            Qt.quit();
        }
    }
}
