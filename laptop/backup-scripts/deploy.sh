#!/bin/bash
# Install the laptop backup scripts from this git checkout.
# Run on the laptop from anywhere:
#   bash /home/dino/system/laptop/backup-scripts/deploy.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(git -C "$here" rev-parse --show-toplevel)"

if [[ "$(id -u)" -ne 0 ]]; then
  git -C "$repo" pull --ff-only origin main
  exec sudo "$0" --installed
fi

if [[ "${1:-}" != "--installed" ]]; then
  echo "Run this as your normal user so git can pull. It will ask for sudo to install." >&2
  exit 1
fi

dir="$repo/laptop/backup-scripts"
install -m 755 "$dir/laptop-backup" /usr/local/sbin/laptop-backup
install -m 755 "$dir/laptop-restore" /usr/local/sbin/laptop-restore
install -m 644 "$dir/laptop-backup@.service" /etc/systemd/system/laptop-backup@.service
install -m 644 "$dir/laptop-backup-full.timer" /etc/systemd/system/laptop-backup-full.timer
install -m 644 "$dir/laptop-backup-incr.timer" /etc/systemd/system/laptop-backup-incr.timer
systemctl daemon-reload
systemctl enable laptop-backup-full.timer laptop-backup-incr.timer
systemctl restart laptop-backup-full.timer laptop-backup-incr.timer
echo "Installed laptop backup scripts from $(git -C "$repo" rev-parse --short HEAD)."
systemctl list-timers laptop-backup-full.timer laptop-backup-incr.timer --no-pager
