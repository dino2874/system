#!/bin/bash
# Install the dgsvr1 backup on the laptop. The Samsung drive stays here.
# The Tuesday, Thursday, and Saturday timers pull the server over SSH.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run: sudo bash $0" >&2
  exit 1
fi
if [[ "$(hostname -s)" == "dgsvr1" ]]; then
  echo "Run this on the laptop. The Samsung drive stays plugged into the laptop." >&2
  exit 1
fi

cd "$(dirname "$0")"
install -m 755 dgsvr1-backup /usr/local/sbin/dgsvr1-backup
install -m 755 setup-ssh.sh /usr/local/sbin/dgsvr1-backup-setup-ssh
install -m 644 dgsvr1-backup@.service /etc/systemd/system/dgsvr1-backup@.service
install -m 644 dgsvr1-backup-full.timer /etc/systemd/system/dgsvr1-backup-full.timer
install -m 644 dgsvr1-backup-incr.timer /etc/systemd/system/dgsvr1-backup-incr.timer
if [[ ! -f /etc/dgsvr1-backup.conf ]]; then
  install -m 644 dgsvr1-backup.conf /etc/dgsvr1-backup.conf
fi
systemctl daemon-reload
systemctl enable dgsvr1-backup-full.timer dgsvr1-backup-incr.timer
systemctl restart dgsvr1-backup-full.timer dgsvr1-backup-incr.timer
echo "Timers:"
systemctl list-timers dgsvr1-backup-full.timer dgsvr1-backup-incr.timer --no-pager
echo "The drive stays on this laptop. One-time server login:"
echo "  sudo /usr/local/sbin/dgsvr1-backup-setup-ssh"
echo "Log, once a backup has run: /srv/maintenance/reports/backup/dgsvr1-latest.log"
