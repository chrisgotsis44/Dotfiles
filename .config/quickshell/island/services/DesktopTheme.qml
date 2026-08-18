pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// GTK and Qt application theming -- the toolkit settings that live
// OUTSIDE this shell, for the apps running on top of it.
//
// Scope, because it overlaps with the shell's own theme switcher:
// apply-theme.sh owns the *colour scheme* (it sets the GTK theme name via
// gsettings, symlinks the GTK4 css, and swaps Kvantum's kvconfig). This
// service owns everything that script does NOT touch -- icon theme,
// cursor theme and size, toolkit fonts, Qt style -- plus the GTK/Kvantum
// theme names themselves, on the understanding that applying a shell
// theme later will overwrite those two. The panel says as much.
//
// Writes go to every place that matters at once, because no single one
// covers all apps:
//   gsettings       -> running GTK apps, live, no restart
//   gtk-3.0 / 4.0
//   settings.ini    -> GTK apps that ignore XSETTINGS, and new launches
//   qt5ct/qt6ct.conf-> Qt apps, picked up on their next start
//   kvantummanager  -> Kvantum's own theme
//   hyprctl setcursor -> the compositor's cursor, which gsettings alone
//                        does not reach (this is what sync-cursor.sh
//                        does by hand)
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cfg: home + "/.config"

    // ---- current values ----
    property string gtkTheme: ""
    property string iconTheme: ""
    property string cursorTheme: ""
    property int cursorSize: 24
    property string gtkFont: ""
    property bool preferDark: true

    // GTK stores one string ("Adwaita Sans 14"); Qt stores a 17-field
    // serialized QFont. Both are split into family/size here so the UI
    // can drive them as two independent controls.
    readonly property string gtkFontFamily: {
        const m = /^(.*?)\s+(\d+(?:\.\d+)?)$/.exec(gtkFont);
        return m ? m[1] : gtkFont;
    }
    readonly property real gtkFontSize: {
        const m = /^(.*?)\s+(\d+(?:\.\d+)?)$/.exec(gtkFont);
        return m ? parseFloat(m[2]) : 11;
    }

    property string qtFontFamily: ""
    property real qtFontSize: 11

    property var fontFamilies: []

    property string qtStyle: ""
    property string kvantumTheme: ""
    property string qtIconTheme: ""

    // ---- available options, scanned from disk ----
    property var gtkThemes: []
    property var iconThemes: []
    property var cursorThemes: []
    property var kvantumThemes: []
    readonly property var qtStyles: ["kvantum", "kvantum-dark", "Fusion", "Breeze", "Windows"]

    property bool scanned: false

    function refresh(): void {
        readProc.running = false;
        readProc.running = true;
        if (!scanned) {
            scanProc.running = false;
            scanProc.running = true;
        }
    }

    // ------------------------------------------------------------ //
    //  GTK                                                          //
    // ------------------------------------------------------------ //
    function setGtkTheme(name: string): void {
        gtkTheme = name;
        gsettings("gtk-theme", name);
        writeIni("gtk-theme-name", name);
    }

    function setIconTheme(name: string): void {
        iconTheme = name;
        qtIconTheme = name;
        gsettings("icon-theme", name);
        writeIni("gtk-icon-theme-name", name);
        // Keep Qt in step -- an icon theme differing between toolkits is
        // the most visible way a desktop looks unfinished.
        writeQtConf("icon_theme", name);
    }

    function setCursorTheme(name: string): void {
        cursorTheme = name;
        gsettings("cursor-theme", name);
        writeIni("gtk-cursor-theme-name", name);
        applyCursor();
    }

    function setCursorSize(size: int): void {
        cursorSize = size;
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface",
            "cursor-size", String(size)]);
        writeIni("gtk-cursor-theme-size", String(size));
        applyCursor();
    }

    function applyCursor(): void {
        // gsettings alone does not reach the compositor's own cursor.
        Quickshell.execDetached(["hyprctl", "setcursor", root.cursorTheme, String(root.cursorSize)]);
    }

    function setGtkFont(font: string): void {
        gtkFont = font;
        gsettings("font-name", font);
        writeIni("gtk-font-name", font);
    }

    // Both of these compose the new value from the CURRENT one, so they
    // are only safe once the initial read has landed. This singleton is
    // lazy, and its read is async: touching it and immediately setting a
    // size composed "" + " 13" and wrote a font with no family at all.
    // Refusing beats writing a nameless font that silently falls back.
    function setGtkFontFamily(family: string): void {
        if (!family)
            return;
        setGtkFont(family + " " + root.gtkFontSize);
    }

    function setGtkFontSize(size: real): void {
        const fam = root.gtkFontFamily;
        if (!fam)
            return;
        setGtkFont(fam + " " + size);
    }

    // qt5ct/qt6ct persist fonts as a serialized QFont: 17 comma-separated
    // fields where [0] is the family and [1] the point size. The rest
    // encode weight, style hints and stretch; they are reproduced from a
    // known-good regular-weight default rather than invented, because a
    // malformed string here makes Qt fall back silently and the setting
    // looks like it did nothing.
    function qtFontString(family: string, size: real): string {
        return `"${family},${size},-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Regular,0,0"`;
    }

    function setQtFont(family: string, size: real): void {
        // Same hazard as the GTK pair above: a family-less QFont string
        // parses, then resolves to nothing.
        if (!family)
            return;
        qtFontFamily = family;
        qtFontSize = size;
        const v = qtFontString(family, size);
        // Both roles: `general` is the UI font, `fixed` the monospace
        // one. Only general's family is user-chosen here; fixed keeps
        // pace on size so the two do not drift apart.
        writeQtFont("general", v);
        writeQtFont("fixed", v);
    }

    function writeQtFont(key: string, value: string): void {
        for (const ver of ["qt5ct", "qt6ct"]) {
            const path = `${root.cfg}/${ver}/${ver}.conf`;
            Quickshell.execDetached(["bash", "-c",
                `f=${JSON.stringify(path)}; k=${JSON.stringify(key)}; v=${JSON.stringify(value)}; `
                + `[ -f "$f" ] || exit 0; `
                + `if grep -q "^$k=" "$f"; then `
                + `sed -i "s|^$k=.*|$k=$v|" "$f"; else `
                + `sed -i "0,/^\\[Fonts\\]/s//[Fonts]\\n$k=$v/" "$f"; fi`]);
        }
    }

    function setPreferDark(dark: bool): void {
        preferDark = dark;
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface",
            "color-scheme", dark ? "prefer-dark" : "prefer-light"]);
        writeIni("gtk-application-prefer-dark-theme", dark ? "1" : "0");
    }

    function gsettings(key: string, value: string): void {
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", key, value]);
    }

    // settings.ini is a flat INI; replace the key in place if present,
    // append it under [Settings] otherwise. Both GTK3 and GTK4 read the
    // same key names, so both files get the same edit.
    function writeIni(key: string, value: string): void {
        for (const ver of ["gtk-3.0", "gtk-4.0"]) {
            const path = `${root.cfg}/${ver}/settings.ini`;
            Quickshell.execDetached(["bash", "-c",
                `f=${JSON.stringify(path)}; k=${JSON.stringify(key)}; v=${JSON.stringify(value)}; `
                + `mkdir -p "$(dirname "$f")"; [ -f "$f" ] || printf '[Settings]\\n' > "$f"; `
                + `if grep -q "^$k=" "$f"; then `
                + `sed -i "s|^$k=.*|$k=$v|" "$f"; else `
                + `sed -i "0,/^\\[Settings\\]/s//[Settings]\\n$k=$v/" "$f"; fi`]);
        }
    }

    // ------------------------------------------------------------ //
    //  Qt                                                           //
    // ------------------------------------------------------------ //
    function setQtStyle(name: string): void {
        qtStyle = name;
        writeQtConf("style", name);
    }

    function setKvantumTheme(name: string): void {
        kvantumTheme = name;
        // kvantummanager owns this file's format; let it write.
        Quickshell.execDetached(["kvantummanager", "--set", name]);
    }

    // Same in-place-or-append shape as writeIni, under [Appearance], for
    // both qt5ct and qt6ct.
    function writeQtConf(key: string, value: string): void {
        for (const ver of ["qt5ct", "qt6ct"]) {
            const path = `${root.cfg}/${ver}/${ver}.conf`;
            Quickshell.execDetached(["bash", "-c",
                `f=${JSON.stringify(path)}; k=${JSON.stringify(key)}; v=${JSON.stringify(value)}; `
                + `[ -f "$f" ] || exit 0; `
                + `if grep -q "^$k=" "$f"; then `
                + `sed -i "s|^$k=.*|$k=$v|" "$f"; else `
                + `sed -i "0,/^\\[Appearance\\]/s//[Appearance]\\n$k=$v/" "$f"; fi`]);
        }
    }

    // ------------------------------------------------------------ //
    //  Reading current state                                        //
    // ------------------------------------------------------------ //
    Process {
        id: readProc
        command: ["bash", "-c", `
gs() { gsettings get org.gnome.desktop.interface "$1" 2>/dev/null | sed "s/^'//;s/'$//"; }
echo "gtkTheme=$(gs gtk-theme)"
echo "iconTheme=$(gs icon-theme)"
echo "cursorTheme=$(gs cursor-theme)"
echo "cursorSize=$(gs cursor-size)"
echo "gtkFont=$(gs font-name)"
echo "colorScheme=$(gs color-scheme)"
echo "qtStyle=$(grep -m1 '^style=' ~/.config/qt6ct/qt6ct.conf 2>/dev/null | cut -d= -f2)"
echo "qtIcon=$(grep -m1 '^icon_theme=' ~/.config/qt6ct/qt6ct.conf 2>/dev/null | cut -d= -f2)"
echo "kvantum=$(grep -m1 '^theme=' ~/.config/Kvantum/kvantum.kvconfig 2>/dev/null | cut -d= -f2)"
echo "qtFont=$(grep -m1 '^general=' ~/.config/qt6ct/qt6ct.conf 2>/dev/null | cut -d= -f2- | tr -d '\"')"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("=");
                    if (i < 0)
                        continue;
                    const k = line.slice(0, i);
                    const v = line.slice(i + 1).trim();
                    if (k === "gtkTheme" && v) root.gtkTheme = v;
                    else if (k === "iconTheme" && v) root.iconTheme = v;
                    else if (k === "cursorTheme" && v) root.cursorTheme = v;
                    else if (k === "cursorSize" && v) root.cursorSize = parseInt(v) || 24;
                    else if (k === "gtkFont" && v) root.gtkFont = v;
                    else if (k === "colorScheme") root.preferDark = v !== "prefer-light";
                    else if (k === "qtStyle" && v) root.qtStyle = v;
                    else if (k === "qtIcon" && v) root.qtIconTheme = v;
                    else if (k === "kvantum" && v) root.kvantumTheme = v;
                    else if (k === "qtFont" && v) {
                        const parts = v.split(",");
                        if (parts.length >= 2) {
                            root.qtFontFamily = parts[0];
                            root.qtFontSize = parseFloat(parts[1]) || 11;
                        }
                    }
                }
            }
        }
    }

    // A theme dir counts as a GTK theme only if it actually ships a gtk-3
    // or gtk-4 subdir -- /usr/share/themes is full of directories that
    // are only Metacity or Xfwm assets and would be dead entries here.
    // Cursor themes are the dirs with a cursors/ subdir; icon themes are
    // the ones with an index.theme but no cursors/.
    Process {
        id: scanProc
        command: ["bash", "-c", `
{
  for d in /usr/share/themes/* ~/.themes/*; do
    [ -d "$d" ] || continue
    if [ -d "$d/gtk-3.0" ] || [ -d "$d/gtk-4.0" ]; then echo "gtk|$(basename "$d")"; fi
  done
  for d in /usr/share/icons/* ~/.icons/* ~/.local/share/icons/*; do
    [ -d "$d" ] || continue
    if [ -d "$d/cursors" ]; then echo "cursor|$(basename "$d")";
    elif [ -f "$d/index.theme" ]; then echo "icon|$(basename "$d")"; fi
  done
  for d in /usr/share/Kvantum/* ~/.config/Kvantum/*; do
    [ -d "$d" ] && echo "kv|$(basename "$d")"
  done
  # 600+ families are installed; listing them all would make the picker
  # unusable. Offer a curated set of UI-suitable faces, filtered to the
  # ones actually present.
  fc-list : family | tr ',' '\n' | sed 's/^ *//' | sort -u > /tmp/.island-fams.$$
  for f in "Adwaita Sans" "Cantarell" "Inter" "Noto Sans" "DejaVu Sans" \
           "Liberation Sans" "Roboto" "Ubuntu" "Fira Sans" "Open Sans" \
           "Source Sans 3" "IBM Plex Sans" "Lato" "SF Pro Text" \
           "JetBrainsMono Nerd Font Propo" "JetBrains Mono" "Fira Code" \
           "Hack" "Cascadia Code"; do
    grep -qxF "$f" /tmp/.island-fams.$$ && echo "font|$f"
  done
  rm -f /tmp/.island-fams.$$
} | sort -u
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const gtk = [], icon = [], cur = [], kv = [], fonts = [];
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("|");
                    if (i < 0)
                        continue;
                    const kind = line.slice(0, i);
                    const name = line.slice(i + 1);
                    if (kind === "gtk") gtk.push(name);
                    else if (kind === "icon") icon.push(name);
                    else if (kind === "cursor") cur.push(name);
                    else if (kind === "kv") kv.push(name);
                    else if (kind === "font") fonts.push(name);
                }
                root.gtkThemes = gtk;
                root.iconThemes = icon;
                root.cursorThemes = cur;
                root.kvantumThemes = kv;
                root.fontFamilies = fonts;
                root.scanned = true;
            }
        }
    }

    Component.onCompleted: root.refresh()
}
