import qs.services
import "Glyphs.js" as Glyphs

// SUPER+. — Unicode text symbols and Nerd Font icons in one list.
//
// The two sources stay separate in the data file because they need
// different fonts to draw, and are merged here into the single list the
// picker searches. Each row carries the `nerd` flag that tells the
// delegate which font can render it.
//
// The merge runs once, when the island first builds this section (see
// the lazy Section in Bar.qml) -- roughly 11k rows, which is why it is
// worth never doing again while the shell lives.
PickerContent {
    entries: {
        const out = [];
        for (const x of Glyphs.symbols)
            out.push({
                e: x.e,
                n: x.n,
                k: x.k,
                nerd: false
            });
        for (const x of Glyphs.nerd)
            out.push({
                e: x.e,
                n: x.n,
                k: x.k,
                nerd: true
            });
        return out;
    }
    placeholder: "Search symbols and Nerd Font icons…"
    icon: "font_download"
    active: GlobalState.glyphPickerOpen
    onDismissed: GlobalState.glyphPickerOpen = false
}
