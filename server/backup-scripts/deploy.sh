#!/bin/bash
# Install the dgsvr1 backup from this git checkout onto the laptop.
# Run on the laptop from anywhere:
#   bash /home/dino/system/server/backup-scripts/deploy.sh
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
if [[ "$(hostname -s)" == "dgsvr1" ]]; then
  echo "Run this on the laptop. The Samsung drive stays plugged into the laptop." >&2
  exit 1
fi

dir="$repo/server/backup-scripts"
install -m 755 "$dir/dgsvr1-backup" /usr/local/sbin/dgsvr1-backup
install -m 755 "$dir/setup-ssh.sh" /usr/local/sbin/dgsvr1-backup-setup-ssh
install -m 644 "$dir/dgsvr1-backup@.service" /etc/systemd/system/dgsvr1-backup@.service
install -m 644 "$dir/dgsvr1-backup-full.timer" /etc/systemd/system/dgsvr1-backup-full.timer
install -m 644 "$dir/dgsvr1-backup-incr.timer" /etc/systemd/system/dgsvr1-backup-incr.timer
if [[ ! -f /etc/dgsvr1-backup.conf ]]; then
  install -m 644 "$dir/dgsvr1-backup.conf" /etc/dgsvr1-backup.conf
fi
systemctl daemon-reload
systemctl enable dgsvr1-backup-full.timer dgsvr1-backup-incr.timer
systemctl restart dgsvr1-backup-full.timer dgsvr1-backup-incr.timer
echo "Installed dgsvr1 backup from $(git -C "$repo" rev-parse --short HEAD)."
systemctl list-timers dgsvr1-backup-full.timer dgsvr1-backup-incr.timer --no-pager
echo "The Samsung drive stays plugged into this laptop."
echo "One-time server login:"
echo "  sudo /usr/local/sbin/dgsvr1-backup-setup-ssh"
echo "To copy the server now, instead of waiting for Tuesday:"
echo "  sudo /usr/local/sbin/dgsvr1-backup full"
echo "Log: /srv/maintenance/reports/backup/dgsvr1-latest.log"
