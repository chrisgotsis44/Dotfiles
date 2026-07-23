import QtQuick
import qs.config

// Text in the mono/status font — use for numbers and readouts (clock,
// percentages, temperatures) so digits align and don't jitter as they
// change.
StyledText {
    font.family: Appearance.font.mono
}
