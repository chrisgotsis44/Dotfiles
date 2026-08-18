import qs.services
import "Emoji.js" as Emoji

// SUPER+, — emoji only. Entries carry no `nerd` flag, so the delegate
// draws them in the UI font, which is what renders color emoji.
PickerContent {
    entries: Emoji.list
    placeholder: "Search emoji…"
    icon: "mood"
    active: GlobalState.emojiPickerOpen
    onDismissed: GlobalState.emojiPickerOpen = false
}
