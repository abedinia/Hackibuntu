#!/usr/bin/env python3
"""Write the Matrix-style icons into files/icons/Hacker/."""
import random
from pathlib import Path

import gi

gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf, Gio, GLib

OUT = Path(__file__).resolve().parent.parent / "files/icons/Hacker"
SVG = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">'

# file name (the Icon= value) -> glyph drawn on a 128x128 tile
APPS = {
    "google-chrome": '<circle cx="64" cy="64" r="36"/><ellipse cx="64" cy="64" rx="16" ry="36"/><path d="M28 64H100"/>',
    "org.gnome.Nautilus": '<path d="M28 40h26l10 10h36v42H28z"/>',
    "org.gnome.Ptyxis": '<path d="M32 42l24 22-24 22M66 88h30"/>',
    "telegram": '<path d="M26 62L102 32 88 98 62 80 50 94 48 72zM48 72L102 32"/>',
    "claude-desktop": '<path d="M64 28v72M28 64h72M39 39l50 50M89 39L39 89"/>',
    "chatgpt": '<path d="M64 28l31 18v36L64 100 33 82V46z"/><circle cx="64" cy="64" r="11"/>',
    "vscode": '<path d="M46 40L22 64l24 24M82 40l24 24-24 24M72 32L56 96"/>',
    "antigravity": '<path d="M32 96L64 30l32 66M48 74h32"/>',
    "localsend": '<circle cx="64" cy="64" r="8"/><path d="M44 44a28 28 0 000 40M84 44a28 28 0 010 40M32 32a45 45 0 000 64M96 32a45 45 0 010 64"/>',
    "dbeaver": '<ellipse cx="64" cy="40" rx="30" ry="11"/><path d="M34 40v48c0 15 60 15 60 0V40M34 64c0 15 60 15 60 0"/>',
    "bitwarden": '<path d="M64 28l32 12v24c0 18-14 30-32 38-18-8-32-20-32-38V40z"/><path d="M64 56v20"/><circle cx="64" cy="56" r="6"/>',
    "throne": '<path d="M30 90l-4-46 22 18 16-30 16 30 22-18-4 46z"/>',
    "anydesk": '<path d="M30 44h60M76 30l16 14-16 14M98 84H38M52 70L36 84l16 14"/>',
    "teams-for-linux": '<path d="M36 38h56M64 38v56"/><circle cx="96" cy="72" r="10"/><circle cx="32" cy="72" r="10"/>',
    "zed": '<path d="M36 36h56L36 92h56"/>',
    "waveterm": '<path d="M26 52q19-22 38 0t38 0M26 80q19-22 38 0t38 0"/>',
    "termius": '<path d="M30 34h68v60H30zM44 50l14 14-14 14M66 80h18"/>',
    # dock trash, empty and full
    "user-trash": '<path d="M34 42h60M52 42V30h24v12M42 42l5 56h34l5-56M54 56v28M74 56v28"/>',
    "user-trash-full": '<path d="M34 42h60M52 42V30h24v12M42 42l5 56h34l5-56M54 56v28M74 56v28M34 30l6-10 8 8M80 28l4-10 11 5"/>',
}


def rain(seed):
    """Falling code: columns of small blocks, brightest at the bottom."""
    rnd = random.Random(seed)  # same name, same rain
    cells = []
    for x in range(15, 111, 12):
        head, length = rnd.randint(2, 10), rnd.randint(3, 7)
        for i in range(length):
            row = head - i
            if row < 0:
                break
            color = "#d8ffe0" if i == 0 else "#00ff41"
            alpha = 0.9 if i == 0 else 0.65 * (1 - i / length)
            width = rnd.choice((3, 5, 6))
            cells.append(f'<rect x="{x + (6 - width) / 2:g}" y="{14 + row * 9.5:g}" width="{width}" '
                         f'height="6" fill="{color}" fill-opacity="{alpha:.2f}"/>')
    return "".join(cells)


def icon(name, glyph):
    line = 'fill="none" stroke-linecap="round" stroke-linejoin="round"'
    return (f'{SVG}<rect x="6" y="6" width="116" height="116" rx="22" fill="#030603"/>'
            f'{rain(name)}'
            # dark outline and soft glow keep the glyph readable over the rain
            f'<g {line} stroke="#030603" stroke-width="17" stroke-opacity="0.85">{glyph}</g>'
            f'<g {line} stroke="#00ff41" stroke-width="12" stroke-opacity="0.25">{glyph}</g>'
            f'<g {line} stroke="#39ff6a" stroke-width="6">{glyph}</g>'
            '<rect x="6" y="6" width="116" height="116" rx="22" fill="none" stroke="#00ff41" '
            'stroke-opacity="0.55" stroke-width="3"/></svg>\n')


def main():
    apps, actions = OUT / "scalable/apps", OUT / "scalable/actions"
    apps.mkdir(parents=True, exist_ok=True)
    actions.mkdir(parents=True, exist_ok=True)
    for name, glyph in APPS.items():
        (apps / f"{name}.svg").write_text(icon(name, glyph))

    # The dock's "Show Apps" button. A PNG, because GNOME repaints *-symbolic.svg
    # files in one flat color, which would lose the tile and the rain.
    grid = "".join(f'<path d="M{x} {y}h12v12h-12z"/>' for y in (33, 58, 83) for x in (33, 58, 83))
    name = "view-app-grid-ubuntu-symbolic"
    data = Gio.MemoryInputStream.new_from_bytes(GLib.Bytes.new(icon(name, grid).encode()))
    GdkPixbuf.Pixbuf.new_from_stream_at_scale(data, 256, 256, True, None).savev(
        str(actions / f"{name}.png"), "png", [], [])
    # same drawing as localsend, under the name the other LocalSend package uses
    (apps / "org.localsend.localsend_app.svg").write_text(icon("localsend", APPS["localsend"]))


if __name__ == "__main__":
    main()
