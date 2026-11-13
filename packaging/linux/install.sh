#!/bin/sh
# puts the kryfo next to this script in ~/.local/opt/kryfo for this user,
# with a menu entry, the icon and kryfo: links. no root.
#   ./install.sh            install or update
#   ./install.sh --remove   take the app away (messages stay, see below)
# the messages, keys and settings live in ~/.local/share/kryfo, which neither
# install nor remove touches
set -eu
here=$(cd "$(dirname "$0")" && pwd)
share=${XDG_DATA_HOME:-$HOME/.local/share}
dest=$HOME/.local/opt/kryfo
entry=$share/applications/app.kryfo.Kryfo.desktop
icons=$share/icons/hicolor
autostart=${XDG_CONFIG_HOME:-$HOME/.config}/autostart/app.kryfo.Kryfo.desktop

refresh() {
  update-desktop-database "$share/applications" 2>/dev/null || true
  gtk-update-icon-cache -q -t "$icons" 2>/dev/null || true
}

# every size the bundle has, as share/icons/hicolor/<size>/apps/app.kryfo.Kryfo.*
icon_files() {
  for s in 16x16 22x22 24x24 32x32 48x48 64x64 128x128 256x256 512x512; do
    echo "$icons/$s/apps/app.kryfo.Kryfo.png"
  done
  echo "$icons/scalable/apps/app.kryfo.Kryfo.svg"
}

if [ "${1:-}" = "--remove" ]; then
  rm -rf "$dest" "$entry" "$autostart"
  icon_files | while read -r f; do rm -f "$f"; done
  refresh
  echo "Kryfo is removed. Your messages are still in $share/kryfo"
  exit 0
fi

[ -x "$here/kryfo" ] && [ -d "$here/lib" ] && [ -d "$here/data" ] || {
  echo "run install.sh from the unpacked kryfo folder" >&2
  exit 1
}
if pgrep -u "$(id -u)" -x kryfo >/dev/null 2>&1; then
  echo "quit Kryfo first (tray menu, Quit Kryfo)" >&2
  exit 1
fi
mkdir -p "$HOME/.local/opt" "$(dirname "$entry")"
rm -rf "$dest.new"
mkdir "$dest.new"
cp -a "$here/kryfo" "$here/lib" "$here/data" "$dest.new/"
rm -rf "$dest"
mv "$dest.new" "$dest"
icon_files | while read -r f; do
  rel=${f#"$icons"/}
  mkdir -p "$(dirname "$f")"
  cp "$here/data/icons/hicolor/$rel" "$f"
done
sed "s|^Exec=kryfo %u$|Exec=\"$dest/kryfo\" %u|" "$here/app.kryfo.Kryfo.desktop" >"$entry"
grep -q "^Exec=\"$dest/kryfo\" %u$" "$entry" || {
  echo "the menu entry was not written" >&2
  exit 1
}
refresh
echo "Kryfo is in $dest. Start it from the app menu or with $dest/kryfo"
