pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick

// Lockscreen state and the whole PAM conversation.
//
// The lock surface is instantiated once per monitor by WlSessionLock, so
// nothing that must be shared -- the password buffer, the fail count, the
// idle state -- can live in the surface. It all lives here; the surfaces
// are pure views that read this and never touch PAM themselves.
//
// This process is spawned to lock and exits once unlocked (the same model
// hyprlock used), so `finished` is what shell.qml quits on.
Singleton {
    id: root

    // ---- lifecycle ----------------------------------------------------
    // Drives WlSessionLock.locked.
    property bool locked: false
    // Auth succeeded and the exit animation is playing. Still locked --
    // `locked` only drops once exitTimer fires, so the compositor keeps
    // the session locked until the reveal has actually finished.
    property bool unlocking: false
    // No key or pointer activity for idleTimeoutMs.
    property bool idle: false

    // Unlocked, and safe to tear the process down.
    signal finished

    // ---- auth ---------------------------------------------------------
    property string buffer: ""
    // PAM's own message text, shown verbatim -- so a faillock backoff
    // reads as the lockout it is instead of looking like a broken field.
    property string message: ""
    property bool messageIsError: false
    property int failCount: 0
    // PAM refused to keep trying. Input stays dead until the next attempt
    // window; there is nothing useful the user can type in the meantime.
    property bool lockedOut: false
    property bool capsLock: false
    readonly property bool authenticating: pam.active

    signal failed

    readonly property int idleTimeoutMs: 20000
    // Past this the dot row compresses instead of growing the capsule.
    readonly property int maxDots: 12
    // Long enough for the background to un-blur before the surface goes.
    readonly property int exitMs: 480

    // PamContext emits `error` AND `completed` for the same failure, which
    // used to fire failed() twice and double-trigger the shake.
    property bool errorSeen: false

    function lock(): void {
        if (root.locked)
            return;
        root.buffer = "";
        root.message = "";
        root.messageIsError = false;
        root.failCount = 0;
        root.lockedOut = false;
        root.unlocking = false;
        root.idle = false;
        root.locked = true;
        idleTimer.restart();
        capsProc.running = true;
    }

    function noteActivity(): void {
        if (!root.locked || root.unlocking)
            return;
        root.idle = false;
        idleTimer.restart();
    }

    function submit(): void {
        if (root.buffer === "" || pam.active || root.unlocking || root.lockedOut)
            return;
        root.message = "";
        root.messageIsError = false;
        root.errorSeen = false;
        if (!pam.start()) {
            root.message = "Could not start authentication";
            root.messageIsError = true;
            root.failed();
        }
    }

    // Single input path for however many monitors are attached: the
    // surface forwards every key here rather than owning a focused field.
    function handleKey(key: int, text: string, modifiers: int): void {
        root.noteActivity();
        if (root.unlocking)
            return;

        if (key === Qt.Key_CapsLock) {
            // hyprctl reflects the new state a moment after the keypress.
            capsTimer.restart();
            return;
        }
        // Mid-auth keystrokes would land in a buffer PAM has already read.
        if (pam.active || root.lockedOut)
            return;

        if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            root.submit();
            return;
        }
        if (key === Qt.Key_Backspace) {
            root.buffer = (modifiers & Qt.ControlModifier) ? "" : root.buffer.slice(0, -1);
            return;
        }
        if (key === Qt.Key_Escape || (key === Qt.Key_U && (modifiers & Qt.ControlModifier))) {
            root.buffer = "";
            return;
        }
        // Printable only -- `text` carries control characters for things
        // like Ctrl+U, which must never reach the password.
        if (text.length > 0 && text.charCodeAt(0) >= 0x20 && key !== Qt.Key_Delete)
            root.buffer += text;
    }

    PamContext {
        id: pam

        // Self-contained policy shipped beside this config, so the locker
        // depends on no package. See pam/qs-lock.
        configDirectory: Qt.resolvedUrl("../pam").toString().replace("file://", "")
        config: "qs-lock"

        onPamMessage: {
            if (pam.responseRequired) {
                pam.respond(root.buffer);
                return;
            }
            if (pam.message !== "") {
                root.message = pam.message;
                root.messageIsError = pam.messageIsError;
            }
        }

        onCompleted: result => {
            root.buffer = "";
            if (result === PamResult.Success) {
                root.message = "";
                root.messageIsError = false;
                root.unlocking = true;
                exitTimer.restart();
                return;
            }

            root.failCount++;
            root.messageIsError = true;
            if (result === PamResult.MaxTries) {
                root.lockedOut = true;
                root.message = "Too many attempts";
            } else if (root.message === "" || root.errorSeen) {
                root.message = result === PamResult.Error ? "Authentication error" : "Incorrect password";
            }
            // Already shaken on the error signal for this same failure.
            if (!root.errorSeen)
                root.failed();
            root.errorSeen = false;
        }

        onError: err => {
            root.buffer = "";
            root.errorSeen = true;
            root.messageIsError = true;
            root.message = "Authentication error";
            root.failed();
        }
    }

    Timer {
        id: exitTimer
        interval: root.exitMs
        onTriggered: {
            root.locked = false;
            root.unlocking = false;
            root.idle = false;
            root.message = "";
            quitTimer.restart();
        }
    }

    // The unlock has to actually reach the compositor before this process
    // goes away, or the session is left locked with no client to unlock it.
    Timer {
        id: quitTimer
        interval: 260
        onTriggered: root.finished()
    }

    Timer {
        id: idleTimer
        interval: root.idleTimeoutMs
        onTriggered: if (root.locked && !root.unlocking)
            root.idle = true
    }

    // Caps lock is not in Qt's modifier set, so it comes from Hyprland.
    // Only ever refreshed on lock and on an actual Caps Lock press -- not
    // polled -- so this costs two process spawns in a typical unlock.
    Timer {
        id: capsTimer
        interval: 60
        onTriggered: capsProc.running = true
    }

    Process {
        id: capsProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = (JSON.parse(text).keyboards ?? []).find(k => k.main);
                    root.capsLock = kb?.capsLock ?? false;
                } catch (e) {
                    root.capsLock = false;
                }
            }
        }
    }
}
