#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
install -m 755 laptop-backup /usr/local/sbin/laptop-backup
install -m 644 laptop-backup@.service /etc/systemd/system/laptop-backup@.service
install -m 644 laptop-backup-full.timer /etc/systemd/system/laptop-backup-full.timer
install -m 644 laptop-backup-incr.timer /etc/systemd/system/laptop-backup-incr.timer
systemctl daemon-reload
systemctl enable laptop-backup-full.timer laptop-backup-incr.timer
systemctl restart laptop-backup-full.timer laptop-backup-incr.timer
systemctl start --no-block laptop-backup@full.service
echo "Timers:"
systemctl list-timers laptop-backup-full.timer laptop-backup-incr.timer --no-pager
echo "Full backup started. Log: /srv/maintenance/reports/backup/latest.log"
