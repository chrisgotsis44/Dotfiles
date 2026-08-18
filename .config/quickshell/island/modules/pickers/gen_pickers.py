#!/usr/bin/env python3
"""Split the launcher's old Emoji.js into an emoji set and a glyph set,
and merge the Nerd Font glyph table into the latter.

Emoji vs symbol is decided by Unicode's own Emoji_Presentation property
(emoji-data.txt), not by guesswork: those are exactly the codepoints that
render as color emoji by default, which is the distinction a user makes
when they reach for one picker over the other.

Nerd Font glyphs are filtered against the installed font's actual charset
so the picker can never show a box for something the system cannot draw.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).parent
OUT = Path.home() / ".config/quickshell/island/modules/pickers"

# ---------------------------------------------------------------- #
#  Unicode Emoji_Presentation set                                    #
# ---------------------------------------------------------------- #
def emoji_presentation_codepoints():
    cps = set()
    for line in (HERE / "emoji-data.txt").read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        parts = [p.strip() for p in line.split(";")]
        if len(parts) < 2 or parts[1] != "Emoji_Presentation":
            continue
        rng = parts[0]
        if ".." in rng:
            lo, hi = rng.split("..")
            cps.update(range(int(lo, 16), int(hi, 16) + 1))
        else:
            cps.add(int(rng, 16))
    return cps


# ---------------------------------------------------------------- #
#  Parse the existing Emoji.js                                       #
# ---------------------------------------------------------------- #
ENTRY = re.compile(
    r'\{\s*e:\s*"(?P<e>[^"]+)"\s*,\s*n:\s*"(?P<n>[^"]*)"\s*'
    r'(?:,\s*k:\s*"(?P<k>[^"]*)"\s*)?\}'
)


def parse_old(path):
    out = []
    for m in ENTRY.finditer(path.read_text(encoding="utf-8")):
        out.append({"e": m.group("e"), "n": m.group("n"), "k": m.group("k")})
    return out


# ---------------------------------------------------------------- #
#  Installed font coverage                                           #
# ---------------------------------------------------------------- #
def font_charset(family):
    path = subprocess.run(
        ["fc-match", "-f", "%{file}", family], capture_output=True, text=True
    ).stdout.strip()
    if not path:
        return None
    cs = subprocess.run(
        ["fc-query", "-f", "%{charset}", path], capture_output=True, text=True
    ).stdout.strip()
    covered = set()
    for tok in cs.split():
        if "-" in tok:
            lo, hi = tok.split("-")
            covered.update(range(int(lo, 16), int(hi, 16) + 1))
        else:
            covered.add(int(tok, 16))
    return covered


# ---------------------------------------------------------------- #
#  Emit                                                              #
# ---------------------------------------------------------------- #
def js_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def emit(entries, var):
    lines = [f"var {var} = ["]
    for x in entries:
        row = f'    {{ e: "{js_escape(x["e"])}", n: "{js_escape(x["n"])}"'
        if x.get("k"):
            row += f', k: "{js_escape(x["k"])}"'
        row += " },"
        lines.append(row)
    lines.append("];")
    return "\n".join(lines)


def main():
    OUT.mkdir(parents=True, exist_ok=True)

    presentation = emoji_presentation_codepoints()
    old = parse_old(Path.home() / ".config/quickshell/island/modules/launcher/Emoji.js")

    emoji, symbols = [], []
    for x in old:
        # Multi-codepoint sequences are emoji by construction (ZWJ, flags).
        cp = ord(x["e"][0]) if len(x["e"]) >= 1 else 0
        (emoji if (cp in presentation or len(x["e"]) > 1) else symbols).append(x)

    # -------- Nerd Font ---------------------------------------- #
    covered = font_charset("JetBrainsMono Nerd Font")
    if not covered:
        print("!! could not read JetBrainsMono Nerd Font charset", file=sys.stderr)
        return 1

    raw = json.loads((HERE / "glyphnames.json").read_text(encoding="utf-8"))
    nerd, skipped, seen = [], 0, set()
    for name, v in sorted(raw.items()):
        if name == "METADATA" or not isinstance(v, dict) or "char" not in v:
            continue
        ch = v["char"]
        if len(ch) != 1:
            continue
        if ord(ch) not in covered:
            skipped += 1
            continue
        # Same glyph reachable under several names (fa-github / dev-github):
        # keep the first, fold the rest in as extra search keywords.
        words = re.split(r"[-_]+", name)
        if ch in seen:
            for e in nerd:
                if e["e"] == ch:
                    kw = set((e["k"] or "").split()) | set(words)
                    e["k"] = " ".join(sorted(kw))
                    break
            continue
        seen.add(ch)
        nerd.append({"e": ch, "n": name, "k": " ".join(words)})

    header = (
        ".pragma library\n\n"
        "// GENERATED -- see scratchpad/gen_pickers.py in the session that\n"
        "// created it. Hand edits are fine; regenerating overwrites them.\n\n"
    )

    (OUT / "Emoji.js").write_text(
        header
        + "// Codepoints with Unicode's Emoji_Presentation property, i.e. the\n"
        "// ones that render as color emoji by default. Everything else that\n"
        "// used to live in the launcher's ':' mode moved to Glyphs.js.\n\n"
        + emit(emoji, "list")
        + "\n",
        encoding="utf-8",
    )

    (OUT / "Glyphs.js").write_text(
        header
        + "// Two sources, kept separate so the picker can render each in the\n"
        "// font that can actually draw it: `symbols` are ordinary text\n"
        "// codepoints, `nerd` are Private Use Area glyphs that need a Nerd\n"
        "// Font. Both are searched as one list.\n"
        "//\n"
        "// `nerd` is filtered to the glyphs JetBrainsMono Nerd Font really\n"
        "// covers, so nothing here can render as tofu.\n\n"
        + emit(symbols, "symbols")
        + "\n\n"
        + emit(nerd, "nerd")
        + "\n",
        encoding="utf-8",
    )

    print(f"emoji   : {len(emoji)}")
    print(f"symbols : {len(symbols)}")
    print(f"nerd    : {len(nerd)}  (skipped {skipped} not covered by the font)")
    for f in ("Emoji.js", "Glyphs.js"):
        print(f"{f}: {(OUT / f).stat().st_size / 1024:.0f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
