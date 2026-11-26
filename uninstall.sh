#!/usr/bin/env bash
# Put back the settings and files that install.sh changed.
set -euo pipefail

DATA=${XDG_DATA_HOME:-$HOME/.local/share}
STATE=$DATA/hackibuntu
[ -f "$STATE/dconf.tsv" ] || { echo "Nothing to undo: $STATE has no install record." >&2; exit 1; }

while IFS=$'\t' read -r key old; do
  if [ -n "$old" ]; then dconf write "$key" "$old"; else dconf reset "$key"; fi
done < "$STATE/dconf.tsv"

while IFS= read -r path; do
  rm -rf -- "$path"
done < "$STATE/created"

while IFS= read -r path; do
  rm -rf -- "$path"
  cp -a "$STATE/orig$path" "$path"
done < "$STATE/replaced"

fc-cache -f >/dev/null 2>&1 || true
rm -rf -- "$STATE/orig" "$STATE/created" "$STATE/replaced" "$STATE/dconf.tsv"
echo "Restored. Log out and back in."
echo "A full copy of your old settings is still in $STATE/dconf-before.ini"
