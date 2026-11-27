#!/usr/bin/env bash
# Matrix wallpaper and green accent on the login screen. System-wide, needs sudo.
# Usage: sudo ./install-login.sh [--undo]
set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
# the login screen cannot read your home folder, so the picture goes here
PICDIR=/usr/local/share/backgrounds/hackibuntu
PIC=$PICDIR/hacker-wallpaper.png
# our own file, so Ubuntu's /etc/gdm3/greeter.dconf-defaults stays untouched
CONF=/usr/share/gdm/dconf/95-hackibuntu
APPLY=/usr/share/gdm/generate-config

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
case ${1-} in
  ''|--undo) ;;
  -h|--help) sed -n '2,3s/^# //p' "$0"; exit 0 ;;
  *) die "Unknown option: $1" ;;
esac
[ "$(id -u)" -eq 0 ] || die "Run with sudo: sudo $0 ${1-}"
[ -x "$APPLY" ] && [ -d "${CONF%/*}" ] || die "This needs Ubuntu's GDM; $APPLY is missing."

if [ "${1-}" = --undo ]; then
  rm -f -- "$CONF" "$PIC"
  [ ! -d "$PICDIR" ] || rmdir --ignore-fail-on-non-empty "$PICDIR"
  "$APPLY"
  echo "Login screen restored. Log out to see it."
  exit 0
fi

[ -f /usr/share/glib-2.0/schemas/com.ubuntu.login-screen.gschema.xml ] ||
  grep -qs 'com\.ubuntu\.login-screen' /usr/share/glib-2.0/schemas/*.xml ||
  die "This GNOME has no login background setting."

install -d -m 755 "$PICDIR"
install -m 644 "$REPO/files/hacker-wallpaper.png" "$PIC"
cat > "$CONF" <<CONFIG
[com/ubuntu/login-screen]
background-picture-uri='file://$PIC'
background-size='cover'
background-color='#030603'

[org/gnome/desktop/interface]
accent-color='green'
CONFIG
chmod 644 "$CONF"
# only recompiles the settings; restarting GDM would end your session
"$APPLY"

echo "Done. Log out to see it. Undo with: sudo ./install-login.sh --undo"
