#!/usr/bin/env python3
"""Put the Hacker colors and transparency into a Terminator config's default profile.

Usage: set-terminator-theme.py PALETTE CONFIG
Edits CONFIG in place (it may not exist yet). Other settings are kept.
"""
import configparser
import sys

from configobj import ConfigObj  # comes with Terminator

palette = configparser.ConfigParser()
with open(sys.argv[1]) as f:
    palette.read_file(f)
colors = palette["Dark"]

config = ConfigObj(sys.argv[2], encoding="utf-8", indent_type="  ")
profile = config.setdefault("profiles", {}).setdefault("default", {})
profile.update({
    "background_color": colors["Background"],
    "foreground_color": colors["Foreground"],
    "cursor_bg_color": colors["Cursor"],
    "cursor_fg_color": colors["Background"],
    "cursor_color_default": "False",
    "palette": ":".join(colors[f"Color{i}"] for i in range(16)),
    "use_theme_colors": "False",
    "background_type": "transparent",
    "background_darkness": "0.85",  # same as the Ptyxis opacity
    "use_system_font": "True",  # the desktop's monospace font
    # the bar above each pane: green instead of red, blue and grey
    "title_transmit_fg_color": colors["Background"],
    "title_transmit_bg_color": colors["Cursor"],
    "title_receive_fg_color": colors["Background"],
    "title_receive_bg_color": colors["Color6"],
    "title_inactive_fg_color": colors["Foreground"],
    "title_inactive_bg_color": colors["Background"],
})
config.write()
