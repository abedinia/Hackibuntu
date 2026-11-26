# Task: give this Ubuntu PC a "hacker" look (keep GNOME)

> Reference notes from the first setup. To install, use `./install.sh` (see README.md).

Restyle only. Do not change the desktop environment or remove extensions. This was done on Ubuntu 26.04, GNOME Shell 50, Wayland, arm64. Check this PC's versions first and adapt.

## Rules
1. Before any change, back up: `dconf dump / > ~/ubuntu-look-backup-$(date +%F).ini`
2. Write an undo script that resets every key you change, reloads the backup, and removes only the files you created.
3. Don't overwrite existing files (gtk.css, user .desktop files) without showing me.
4. No sudo is needed.

## 1. Icons and shell extension (into the home folder)
- `apt-get download papirus-icon-theme gnome-shell-extension-user-theme`, unpack with `dpkg -x` in a temp folder.
- Copy `Papirus` and `Papirus-Dark` to `~/.local/share/icons/`.
- Green folders: in both copies, for each `*/places/folder-green*.svg`, replace the matching `folder*.svg` with a symlink to the green one.
- Copy the `user-theme@gnome-shell-extensions.gcampax.github.com` folder to `~/.local/share/gnome-shell/extensions/`, put its schema XML in its `schemas/` folder, run `glib-compile-schemas` there. Check metadata.json supports this GNOME version.
- Append that UUID to `org.gnome.shell enabled-extensions` (keep the existing entries), and set `org.gnome.shell.extensions.user-theme name` to `HackerShell` (use `--schemadir`).
- Snap apps with a hard-coded icon path (Telegram, LocalSend, DBeaver, Bitwarden, if installed): copy their .desktop file to `~/.local/share/applications/` and set `Icon=` to `telegram`, `localsend`, `dbeaver`, `bitwarden`.

## 2. Settings
`org.gnome.desktop.interface`: color-scheme `prefer-dark`, gtk-theme `Yaru-olive-dark`, accent-color `green`, icon-theme `Hacker` (copy `files/icons/Hacker/` to `~/.local/share/icons/`; it inherits Papirus-Dark), monospace-font-name `JetBrainsMono Nerd Font 11` (install that font in `~/.local/share/fonts` if missing).

`org.gnome.shell.extensions.dash-to-dock` (floating bottom dock):
dock-position `BOTTOM`, extend-height `false`, dock-fixed `true`, always-center-icons `true`, dash-max-icon-size `46`, apply-custom-theme `false`, custom-background-color `true`, background-color `#101418`, transparency-mode `FIXED`, background-opacity `0.65`, running-indicator-style `DOTS`, custom-theme-customize-running-dots `true`, custom-theme-running-dots-color and -border-color `#00ff41`.

## 3. Files

### ~/.config/gtk-4.0/gtk.css
```
@define-color accent_color #00ff41;
@define-color accent_bg_color #00a32a;
@define-color accent_fg_color #000000;
@define-color window_bg_color #0a0f0a;
@define-color view_bg_color #0d140d;
@define-color headerbar_bg_color #070b07;
@define-color sidebar_bg_color #0c120c;
@define-color card_bg_color #111a11;
@define-color popover_bg_color #0f170f;
@define-color dialog_bg_color #0f170f;
:root {
  --accent-color: #00ff41;
  --accent-bg-color: #00a32a;
  --accent-fg-color: #000000;
  --window-bg-color: #0a0f0a;
  --view-bg-color: #0d140d;
  --headerbar-bg-color: #070b07;
  --sidebar-bg-color: #0c120c;
  --card-bg-color: #111a11;
  --popover-bg-color: #0f170f;
  --dialog-bg-color: #0f170f;
}
```

### ~/.themes/HackerShell/gnome-shell/gnome-shell.css
```
@import url("file:///usr/share/gnome-shell/theme/Yaru-dark/gnome-shell.css");
#panel { background-color: #050806; border-bottom: 1px solid #00a32a; font-family: "JetBrainsMono Nerd Font"; }
#panel .panel-button, #panel .panel-button StIcon { color: #00ff41; }
.popup-menu-content, .quick-settings, .datemenu-popover { background-color: #0a0f0a; border: 1px solid #00a32a; color: #c8ffd4; }
#dashtodockContainer .dash-background { border: 1px solid rgba(0,255,65,0.35); border-radius: 24px; margin-bottom: 8px; padding: 4px; }
```

### ~/.local/share/org.gnome.Ptyxis/palettes/hacker.palette
```
[Palette]
Name=Hacker

[Light]
Background=#0a0f0a
Foreground=#33ff66
Cursor=#00ff41
Color0=#0a0f0a
Color1=#ff5555
Color2=#00d936
Color3=#d7ff5f
Color4=#2fbf9f
Color5=#b48ead
Color6=#3ee6c1
Color7=#b8e6c0
Color8=#3b5240
Color9=#ff7777
Color10=#00ff41
Color11=#eaff8f
Color12=#5fe0c0
Color13=#d0aaca
Color14=#7fffe0
Color15=#eaffee

[Dark]
Background=#0a0f0a
Foreground=#33ff66
Cursor=#00ff41
Color0=#0a0f0a
Color1=#ff5555
Color2=#00d936
Color3=#d7ff5f
Color4=#2fbf9f
Color5=#b48ead
Color6=#3ee6c1
Color7=#b8e6c0
Color8=#3b5240
Color9=#ff7777
Color10=#00ff41
Color11=#eaff8f
Color12=#5fe0c0
Color13=#d0aaca
Color14=#7fffe0
Color15=#eaffee
```

Then, if the terminal is Ptyxis, set `palette` to `hacker` and `opacity` to `0.85` on the default profile (schema `org.gnome.Ptyxis.Profile`, path `/org/gnome/Ptyxis/Profiles/<default-profile-uuid>/`).

## 4. Wallpaper
If I copied `hacker-wallpaper.png` over, use it. Otherwise generate one with Python PIL: "Matrix" code rain, size matched to this screen, background RGB(5,9,6), JetBrains Mono 26px, columns every 34px, 1-3 falling streams per column, 6-28 characters each, fading to brighter green with a pale green last character. Save to `~/Pictures/` and set both `picture-uri` and `picture-uri-dark`.

## 5. Finish
Verify each setting with `gsettings get`. Tell me to log out and back in (needed on Wayland for the top bar and rounded dock).
