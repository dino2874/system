#!/usr/bin/env bash
# Move Laptop-Backup-setup on the laptop. Files are moved unchanged.
# Backup copies on the Samsung drive are not read or written.

set -euo pipefail
shopt -s dotglob nullglob

usage() {
  echo "Usage: $0 [Laptop-Backup-setup]" >&2
  echo "Default source: \$HOME/Laptop-Backup-setup" >&2
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

src="${1:-$HOME/Laptop-Backup-setup}"
if [[ ! -d "$src" ]]; then
  echo "No directory at $src" >&2
  exit 1
fi
src="$(cd "$src" && pwd)"

if command -v findmnt >/dev/null 2>&1; then
  mount_target="$(findmnt -T "$src" -no TARGET 2>/dev/null || true)"
  mount_source="$(findmnt -T "$src" -no SOURCE 2>/dev/null || true)"
  model=""
  tran=""
  if [[ -n "$mount_source" ]] && command -v lsblk >/dev/null 2>&1; then
    model="$(lsblk -no MODEL "$mount_source" 2>/dev/null | head -n 1 || true)"
    tran="$(lsblk -no TRAN "$mount_source" 2>/dev/null | head -n 1 || true)"
  fi
  case "$mount_target" in
    /media/*|/mnt/*|/run/media/*)
      echo "Left $src in place. It is on a mounted drive ($mount_target). Samsung backup files stay where they are." >&2
      exit 1
      ;;
  esac
  shopt -s nocasematch
  if [[ "$model" == *samsung* || "$tran" == "usb" ]]; then
    echo "Left $src in place. It is on ${model:-a removable drive}. Samsung backup files stay where they are." >&2
    exit 1
  fi
  shopt -u nocasematch
fi

parent="$(dirname "$src")"
dest="$parent/system"
laptop="$dest/laptop/backup-scripts"
server="$dest/server/backup-scripts"

mkdir -p "$laptop" "$dest/laptop/system-scripts" "$server"

if [[ -n "$(find "$laptop" "$server" -mindepth 1 -print -quit)" ]]; then
  echo "system/laptop/backup-scripts or system/server/backup-scripts already has files. Nothing was moved." >&2
  exit 1
fi

before="$(mktemp)"
after="$(mktemp)"
trap 'rm -f "$before" "$after"' EXIT

if [[ -n "$(find "$src" -type f -print -quit)" ]]; then
  find "$src" -type f -exec sha256sum {} + | awk '{print $1}' | sort > "$before"
else
  : > "$before"
fi

for entry in "$src"/*; do
  name="$(basename "$entry")"
  [[ "$name" == "." || "$name" == ".." ]] && continue
  if [[ "$name" == "server" && -d "$entry" ]]; then
    continue
  fi
  mv -- "$entry" "$laptop/"
done

if [[ -d "$src/server" ]]; then
  for entry in "$src/server"/*; do
    name="$(basename "$entry")"
    [[ "$name" == "." || "$name" == ".." ]] && continue
    mv -- "$entry" "$server/"
  done
fi

if [[ -n "$(find "$laptop" "$server" -type f -print -quit)" ]]; then
  find "$laptop" "$server" -type f -exec sha256sum {} + | awk '{print $1}' | sort > "$after"
else
  : > "$after"
fi

if ! cmp -s "$before" "$after"; then
  echo "Checksums did not match. Moved files are in $dest and what remains is in $src. Nothing was deleted." >&2
  exit 1
fi

rm -rf -- "$src"
echo "Moved scripts into $dest"
echo "Removed $src"
echo "Samsung backup files were not touched."
find "$dest" -maxdepth 3 -print | sort

