#!/usr/bin/env python3
"""Make Matrix tiles for installed apps that have no hand-drawn icon.

Usage: make-app-icons.py OUTDIR
Writes OUTDIR/<icon name>.png, and prints "<desktop file>\t<desktop id>\t<icon name>" for each
launcher whose Icon= is a file path and so has to be changed to use its tile.
"""
import base64
import importlib.util
import sys
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf, Gio, GLib, Gtk

HERE = Path(__file__).resolve().parent
sys.dont_write_bytecode = True  # keep the repo clean
spec = importlib.util.spec_from_file_location("make_icons", HERE / "make-icons.py")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

OUT = Path(sys.argv[1])
DRAWN = {p.stem for p in (HERE.parent / "files/icons/Hacker").rglob("*.*")}

# brightness -> shade of green, transparency kept
GREEN = ('<filter id="g" color-interpolation-filters="sRGB"><feColorMatrix type="matrix" values="'
         '.06 .20 .02 0 0  .17 .57 .06 0 .24  .09 .29 .03 0 .03  0 0 0 1 0"/></filter>')

# Papirus, not Hacker, so a second run does not tint its own tiles again
theme = Gtk.IconTheme.new()
theme.set_custom_theme("Papirus-Dark")


def tile(name, source):
    art = GdkPixbuf.Pixbuf.new_from_file_at_scale(source, 256, 256, True)
    png = base64.b64encode(art.save_to_bufferv("png", [], [])[1]).decode()
    svg = (f'{base.SVG}{GREEN}<rect x="6" y="6" width="116" height="116" rx="22" fill="#030603"/>'
           f'{base.rain(name)}'
           f'<image x="24" y="24" width="80" height="80" filter="url(#g)" href="data:image/png;base64,{png}"/>'
           '<rect x="6" y="6" width="116" height="116" rx="22" fill="none" stroke="#00ff41" '
           'stroke-opacity="0.55" stroke-width="3"/></svg>')
    data = Gio.MemoryInputStream.new_from_bytes(GLib.Bytes.new(svg.encode()))
    GdkPixbuf.Pixbuf.new_from_stream_at_scale(data, 256, 256, True, None).savev(
        str(OUT / f"{name}.png"), "png", [], [])


for app in Gio.AppInfo.get_all():
    icon = app.get_icon()
    if not app.should_show() or icon is None:
        continue
    try:
        if isinstance(icon, Gio.FileIcon):
            source = icon.get_file().get_path()
            name = "hk-" + app.get_id().removesuffix(".desktop")
            tile(name, source)
            print(app.get_filename(), app.get_id(), name, sep="\t")
        else:
            name = icon.get_names()[0]
            found = theme.lookup_icon(name, 256, Gtk.IconLookupFlags.FORCE_SIZE)
            if name not in DRAWN and not name.startswith("hk-") and found:
                tile(name, found.get_filename())
    except GLib.Error as error:
        print(f"  skipped {app.get_id()}: {error.message}", file=sys.stderr)
