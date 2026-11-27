#!/usr/bin/env bash
# Install the hackibuntu look into the current user's home. No sudo.
# Usage: ./install.sh [--no-shell]   (--no-shell skips the zsh/Starship prompt)
set -euo pipefail

SHELL_SETUP=1
for arg in "$@"; do
  case $arg in
    --no-shell) SHELL_SETUP=0 ;;
    -h|--help) sed -n '2,3s/^# //p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

REPO=$(cd "$(dirname "$0")" && pwd)
FILES=$REPO/files
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}
STATE=$DATA/hackibuntu
EXT=user-theme@gnome-shell-extensions.gcampax.github.com

say()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; WARNINGS+=("$*"); }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
WARNINGS=()

[ "$(id -u)" -ne 0 ] || die "Run as your normal user, not with sudo."
for c in apt-get dpkg dconf gsettings gnome-shell python3 tar sha256sum fc-list fc-cache; do
  command -v "$c" >/dev/null || die "Missing command: $c"
done
if command -v curl >/dev/null; then fetch() { curl -fsSL -o "$2" "$1"; }
elif command -v wget >/dev/null; then fetch() { wget -qO "$2" "$1"; }
else die "Need curl or wget."; fi

GNOME=$(gnome-shell --version | grep -oE '[0-9]+' | head -1)
[ "$GNOME" = 50 ] || warn "Made on GNOME 50, this is GNOME $GNOME. Parts may look different."
[ -f /usr/share/gnome-shell/theme/Yaru-dark/gnome-shell.css ] ||
  warn "Ubuntu's Yaru-dark shell theme is missing; the top bar style will be incomplete."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ---- bookkeeping so uninstall.sh can put things back -----------------------
mkdir -p "$STATE/orig"
touch "$STATE/created" "$STATE/replaced" "$STATE/dconf.tsv"
[ -f "$STATE/dconf-before.ini" ] || dconf dump / > "$STATE/dconf-before.ini"

known() { grep -qxF -- "$1" "$STATE/created" || grep -qxF -- "$1" "$STATE/replaced"; }

# Remember a path before writing it. Only the first run's original is kept.
track() {
  known "$1" && return 0
  if [ -e "$1" ]; then
    mkdir -p "$STATE/orig$(dirname "$1")"
    cp -a "$1" "$STATE/orig$1"
    echo "$1" >> "$STATE/replaced"
    echo "  saved your existing $1"
  else
    echo "$1" >> "$STATE/created"
  fi
}

put() { # source destination
  cmp -s "$1" "$2" && return 0
  mkdir -p "$(dirname "$2")"
  track "$2"
  cp "$1" "$2"
}

setkey() { # dconf-path gvariant-value
  awk -F'\t' -v k="$1" '$1==k{f=1} END{exit !f}' "$STATE/dconf.tsv" ||
    printf '%s\t%s\n' "$1" "$(dconf read "$1")" >> "$STATE/dconf.tsv"
  dconf write "$1" "$2"
}

# ---- icons and the user-theme extension ------------------------------------
apt_unpack() { # package
  (cd "$TMP" && apt-get download "$1" >/dev/null) ||
    die "Could not download $1. Run 'sudo apt update' and try again."
  dpkg -x "$TMP/$1"_*.deb "$TMP/root"
}

say "Icons (Papirus with green folders)"
if [ ! -d "$DATA/icons/Papirus" ] || [ ! -d "$DATA/icons/Papirus-Dark" ]; then
  apt_unpack papirus-icon-theme
  mkdir -p "$DATA/icons"
  for t in Papirus Papirus-Dark; do
    [ -d "$DATA/icons/$t" ] && continue
    track "$DATA/icons/$t"
    cp -a "$TMP/root/usr/share/icons/$t" "$DATA/icons/$t"
    find "$DATA/icons/$t" -path '*/places/folder-green*.svg' | while read -r green; do
      name=$(basename "$green")
      plain=$(dirname "$green")/folder${name#folder-green}
      if [ -e "$plain" ] || [ -L "$plain" ]; then ln -sfn "$name" "$plain"; fi
    done
  done
else
  echo "  already there, left as is"
fi

say "User Themes extension"
EXTDIR=$DATA/gnome-shell/extensions/$EXT
if [ ! -d "$EXTDIR" ] && [ ! -d "/usr/share/gnome-shell/extensions/$EXT" ]; then
  apt_unpack gnome-shell-extension-user-theme
  track "$EXTDIR"
  mkdir -p "$(dirname "$EXTDIR")"
  cp -a "$TMP/root/usr/share/gnome-shell/extensions/$EXT" "$EXTDIR"
  mkdir -p "$EXTDIR/schemas"
  cp "$TMP"/root/usr/share/glib-2.0/schemas/*user-theme*.gschema.xml "$EXTDIR/schemas/"
  command -v glib-compile-schemas >/dev/null ||
    die "glib-compile-schemas missing: sudo apt install libglib2.0-bin"
  glib-compile-schemas "$EXTDIR/schemas"
fi
META=$EXTDIR/metadata.json
[ -f "$META" ] || META=/usr/share/gnome-shell/extensions/$EXT/metadata.json
python3 -I -c 'import json,sys; sys.exit(sys.argv[2] not in json.load(open(sys.argv[1]))["shell-version"])' \
  "$META" "$GNOME" || warn "User Themes does not list GNOME $GNOME; the top bar style may not load."

# ---- font ------------------------------------------------------------------
NERD=https://github.com/ryanoasis/nerd-fonts/releases/latest/download
nerd_font() { # family archive dir file-pattern
  if fc-list : family | grep -F -- "$1" >/dev/null; then echo "  $1 already installed"; return 0; fi
  fetch "$NERD/$2" "$TMP/$2"
  fetch "$NERD/SHA-256.txt" "$TMP/SHA-256.txt"
  (cd "$TMP" && grep -E " [ *]?$2\$" SHA-256.txt | sha256sum -c --quiet -) || die "Checksum failed for $2"
  track "$DATA/fonts/$3"
  mkdir -p "$DATA/fonts/$3"
  tar -xJf "$TMP/$2" -C "$DATA/fonts/$3" --wildcards "$4"
  fc-cache -f "$DATA/fonts" >/dev/null
}

say "Fonts"
nerd_font "JetBrainsMono Nerd Font" JetBrainsMono.tar.xz JetBrainsMonoNerd 'JetBrainsMonoNerdFont-*.ttf'

# ---- theme files -----------------------------------------------------------
say "Theme files and wallpaper"
put "$FILES/gtk.css"             "$CONFIG/gtk-4.0/gtk.css"
put "$FILES/gnome-shell.css"     "$HOME/.themes/HackerShell/gnome-shell/gnome-shell.css"
put "$FILES/hacker.palette"      "$DATA/org.gnome.Ptyxis/palettes/hacker.palette"
put "$FILES/hacker-wallpaper.png" "$HOME/Pictures/hacker-wallpaper.png"

say "Matrix icons"
while read -r f; do
  put "$FILES/icons/Hacker/$f" "$DATA/icons/Hacker/$f"
done < <(cd "$FILES/icons/Hacker" && find . -type f -printf '%P\n')

# Apps whose launcher names an icon file or another theme's icon.
for pair in antigravity_antigravity:antigravity Throne:throne \
             telegram-desktop_telegram-desktop:telegram localsend_localsend:localsend \
            dbeaver-ce_dbeaver-ce:dbeaver bitwarden_bitwarden:bitwarden \
            code_code:vscode antigravity-ide-snap_antigravity-ide:antigravity \
            teams-for-linux_teams-for-linux:teams-for-linux dev.zed.Zed-Preview:zed \
            waveterm_waveterm:waveterm termius-app_termius-app:termius; do
  app=${pair%:*}.desktop
  icon=${pair#*:}
  src=$DATA/applications/$app
  [ -f "$src" ] || src=/var/lib/snapd/desktop/applications/$app
  [ -f "$src" ] || src=/usr/share/applications/$app
  [ -f "$src" ] || continue
  sed "s|^Icon=.*|Icon=$icon|" "$src" > "$TMP/$app"
  put "$TMP/$app" "$DATA/applications/$app"
  echo "  $icon"
done

# An earlier run may have made a tile for an app that is now hand-drawn; the PNG would win.
for f in "$FILES"/icons/Hacker/scalable/apps/*.svg; do
  old=$DATA/icons/Hacker/scalable/apps/$(basename "$f" .svg).png
  rm -f -- "$old"
done

# Every other app: its own icon, turned green, on the same code-rain tile.
say "Matrix tiles for the remaining apps"
mkdir -p "$TMP/tiles"
if python3 -I "$REPO/tools/make-app-icons.py" "$TMP/tiles" > "$TMP/overrides"; then
  for f in "$TMP"/tiles/*.png; do
    [ -e "$f" ] || continue
    put "$f" "$DATA/icons/Hacker/scalable/apps/${f##*/}"
  done
  # launchers that name an icon file need to name the tile instead
  while IFS=$'\t' read -r src app icon; do
    sed "s|^Icon=.*|Icon=$icon|" "$src" > "$TMP/$app"
    put "$TMP/$app" "$DATA/applications/$app"
  done < "$TMP/overrides"
else
  warn "Could not make tiles for the other apps (needs python3-gi and GTK 3)."
fi

# GNOME Shell only rescans a theme when its top folder changes.
[ ! -d "$DATA/icons/Hacker" ] || touch "$DATA/icons/Hacker"

# ---- settings --------------------------------------------------------------
say "Settings"
I=/org/gnome/desktop/interface
setkey $I/color-scheme "'prefer-dark'"
setkey $I/gtk-theme "'Yaru-olive-dark'"
setkey $I/accent-color "'green'"
setkey $I/icon-theme "'Hacker'"
setkey $I/monospace-font-name "'JetBrainsMono Nerd Font 11'"

D=/org/gnome/shell/extensions/dash-to-dock
setkey $D/dock-position "'BOTTOM'"
setkey $D/extend-height false
setkey $D/dock-fixed true
setkey $D/always-center-icons true
setkey $D/dash-max-icon-size 46
setkey $D/apply-custom-theme false
setkey $D/custom-background-color true
setkey $D/background-color "'#101418'"
setkey $D/transparency-mode "'FIXED'"
setkey $D/background-opacity 0.65
setkey $D/running-indicator-style "'DOTS'"
setkey $D/custom-theme-customize-running-dots true
setkey $D/custom-theme-running-dots-color "'#00ff41'"
setkey $D/custom-theme-running-dots-border-color "'#00ff41'"

B=/org/gnome/desktop/background
setkey $B/picture-uri "'file://$HOME/Pictures/hacker-wallpaper.png'"
setkey $B/picture-uri-dark "'file://$HOME/Pictures/hacker-wallpaper.png'"
setkey $B/picture-options "'zoom'"

enabled=$(gsettings get org.gnome.shell enabled-extensions)
case $enabled in
  *"'$EXT'"*) ;;
  *"[]") setkey /org/gnome/shell/enabled-extensions "['$EXT']" ;;
  *) setkey /org/gnome/shell/enabled-extensions "${enabled%]}, '$EXT']" ;;
esac
setkey /org/gnome/shell/extensions/user-theme/name "'HackerShell'"
[ "$(gsettings get org.gnome.shell disable-user-extensions)" = false ] ||
  warn "Extensions are switched off. Turn them on in the Extensions app."

uuid=$(gsettings get org.gnome.Ptyxis default-profile-uuid 2>/dev/null | tr -d "'" || true)
if [ -n "$uuid" ]; then
  setkey "/org/gnome/Ptyxis/Profiles/$uuid/palette" "'hacker'"
  setkey "/org/gnome/Ptyxis/Profiles/$uuid/opacity" 0.85
else
  warn "Terminal colors and transparency skipped: open Ptyxis once, then run install.sh again."
fi

if command -v terminator >/dev/null; then
  term=$CONFIG/terminator/config
  : > "$TMP/terminator"
  [ ! -f "$term" ] || cp "$term" "$TMP/terminator"
  if python3 -I "$REPO/tools/set-terminator-theme.py" "$FILES/hacker.palette" "$TMP/terminator"; then
    put "$TMP/terminator" "$term"
  else
    warn "Terminator colors and transparency skipped: could not edit $term."
  fi
fi

# ---- zsh prompt ------------------------------------------------------------
clone_once() { # url destination
  [ -d "$2" ] && return 0
  track "$2"
  git clone -q --depth 1 "$1" "$2"
}

setup_shell() {
  say "Terminal prompt (Oh My Zsh + Starship)"
  if ! command -v zsh >/dev/null || ! command -v git >/dev/null; then
    warn "Prompt skipped: run 'sudo apt install zsh git', then install.sh again."
    return 0
  fi

  nerd_font "Symbols Nerd Font Mono" NerdFontsSymbolsOnly.tar.xz NerdSymbols '*.ttf'
  put "$FILES/10-nerd-symbols.conf" "$CONFIG/fontconfig/conf.d/10-nerd-symbols.conf"

  local omz=$HOME/.oh-my-zsh
  clone_once https://github.com/ohmyzsh/ohmyzsh.git "$omz"
  for p in zsh-autosuggestions zsh-syntax-highlighting; do
    clone_once "https://github.com/zsh-users/$p" "$omz/custom/plugins/$p"
  done

  if ! command -v starship >/dev/null && [ ! -x "$HOME/.local/bin/starship" ]; then
    local file url
    file=starship-$(uname -m)-unknown-linux-musl.tar.gz
    url=https://github.com/starship/starship/releases/latest/download/$file
    fetch "$url" "$TMP/$file"
    fetch "$url.sha256" "$TMP/$file.sha256"
    echo "$(awk '{print $1}' "$TMP/$file.sha256")  $TMP/$file" | sha256sum -c --quiet - ||
      die "Checksum failed for Starship"
    track "$HOME/.local/bin/starship"
    mkdir -p "$HOME/.local/bin"
    tar -xzf "$TMP/$file" -C "$HOME/.local/bin" starship
  fi
  put "$FILES/starship.toml" "$CONFIG/starship.toml"

  # Edit a copy of .zshrc, keeping whatever else is already in it.
  local rc=$HOME/.zshrc new=$TMP/zshrc
  if [ -f "$rc" ]; then cp "$rc" "$new"; else cp "$omz/templates/zshrc.zsh-template" "$new"; fi
  if ! grep -q 'oh-my-zsh\.sh' "$new"; then
    printf '\nexport ZSH="$HOME/.oh-my-zsh"\nZSH_THEME=""\nplugins=(git)\nsource $ZSH/oh-my-zsh.sh\n' >> "$new"
  fi
  sed -i 's|^ZSH_THEME=.*|ZSH_THEME=""  # Starship draws the prompt|' "$new"
  if grep -qE '^plugins=\([^)]*\)' "$new"; then
    for p in zsh-autosuggestions zsh-syntax-highlighting; do
      grep -qE "^plugins=\(([^)]* )?$p( [^)]*)?\)" "$new" ||
        sed -i -E "s/^plugins=\(([^)]*)\)/plugins=(\1 $p)/" "$new"
    done
  else
    warn "Add zsh-autosuggestions and zsh-syntax-highlighting to plugins= in ~/.zshrc yourself."
  fi
  grep -q 'starship init zsh' "$new" ||
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n\n# Starship prompt\neval "$(starship init zsh)"\n' >> "$new"
  put "$new" "$rc"

  [ "$(getent passwd "$(id -un)" | cut -d: -f7)" = "$(command -v zsh)" ] ||
    warn "To make zsh your default shell, run: chsh -s $(command -v zsh)"
}

if [ "$SHELL_SETUP" = 1 ]; then setup_shell; fi

say "Done. Log out and back in to see the top bar, dock and icons."
echo "Undo any time with ./uninstall.sh"
for w in ${WARNINGS[@]+"${WARNINGS[@]}"}; do printf ' ! %s\n' "$w"; done
