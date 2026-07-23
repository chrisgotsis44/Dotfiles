pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Wayland clipboard history via cliphist.
//
// `cliphist list` emits "<id>\t<preview>" lines. Image entries preview
// as "[[ binary data <size> <ext> <WxH> ]]"; those are decoded into
// $XDG_RUNTIME_DIR so the manager can show real thumbnails. Copying an
// entry pipes `cliphist decode` back into wl-copy, which works for text
// and images alike.
//
// Requires `wl-paste --watch cliphist store` to be running (see README).
Singleton {
    id: root

    // [{ id, preview, isImage, size, ext, dims }]
    property var entries: []
    // Bumped when thumbnail decoding finishes so Image sources reload.
    property int revision: 0

    readonly property string imageDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-island-cliphist"

    function refresh(): void {
        listProc.running = true;
    }

    function copy(id: string): void {
        Quickshell.execDetached(["sh", "-c", `printf '%s' '${id}' | cliphist decode | wl-copy`]);
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab <= 0)
                        continue;
                    const id = line.slice(0, tab);
                    const preview = line.slice(tab + 1);
                    const m = preview.match(/^\[\[ binary data ([0-9.]+ \w+) (\w+) (\d+x\d+) \]\]$/);
                    const isImage = !!m && ["png", "jpg", "jpeg", "webp", "bmp", "gif"].includes(m[2]);
                    out.push({
                        id: id,
                        preview: preview,
                        isImage: isImage,
                        size: m?.[1] ?? "",
                        ext: m?.[2] ?? "",
                        dims: m?.[3] ?? ""
                    });
                }
                root.entries = out;

                // Decode thumbnails for image entries we haven't cached
                // yet (ids are stable, so existing files are reused).
                const imgs = out.filter(e => e.isImage).slice(0, 15);
                if (imgs.length > 0) {
                    const cmds = imgs.map(e =>
                        `[ -f '${root.imageDir}/${e.id}' ] || printf '%s' '${e.id}' | cliphist decode > '${root.imageDir}/${e.id}'`);
                    decodeProc.command = ["sh", "-c", `mkdir -p '${root.imageDir}'; ` + cmds.join("; ")];
                    decodeProc.running = true;
                }
            }
        }
    }

    Process {
        id: decodeProc
        onExited: root.revision++
    }
}
