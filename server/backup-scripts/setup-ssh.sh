#!/bin/bash
# One-time login from this laptop to root on dgsvr1.
# Run on the laptop:
#   sudo bash server/backup-scripts/setup-ssh.sh
# You type the password for dino on the server, then dino's sudo password.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo "$0" "$@"
fi
if [[ "$(hostname -s)" == "dgsvr1" ]]; then
  echo "Run this on the laptop." >&2
  exit 1
fi
if [[ -z "${SUDO_USER:-}" || "$SUDO_USER" == "root" ]]; then
  echo "Run this with sudo from your normal login, so the server password prompt works." >&2
  exit 1
fi

SERVER="dgsvr1"
SSH_USER="root"
SSH_LOGIN_USER="$SUDO_USER"
SSH_KEY="/root/.ssh/dgsvr1-backup"
KNOWN_HOSTS="/root/.ssh/dgsvr1-backup.known_hosts"
CONF="/etc/dgsvr1-backup.conf"
if [[ -f "$CONF" ]]; then
  conf_owner=$(stat -c '%u' "$CONF")
  conf_mode=$(stat -c '%a' "$CONF")
  if [[ "$conf_owner" != "0" ]] || (( (8#$conf_mode & 8#022) != 0 )); then
    echo "$CONF must be owned by root and not writable by group or others." >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$CONF"
fi

install -d -m 700 /root/.ssh
if [[ ! -f "$SSH_KEY" ]]; then
  ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "dgsvr1-backup@$(hostname -s)"
fi
chmod 600 "$SSH_KEY"
chmod 644 "$SSH_KEY.pub"

tmp=$(mktemp)
cleanup() { rm -f "$tmp"; }
trap cleanup EXIT

found=""
for candidate in "$SERVER" "${SERVER%.local}.local"; do
  [[ -n "$candidate" ]] || continue
  if ssh-keyscan -T 8 -H "$candidate" >"$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
    found="$candidate"
    break
  fi
done
if [[ -z "$found" ]]; then
  echo "This laptop could not find $SERVER on the network." >&2
  echo "If the server answers as dgsvr1.local, set SERVER=dgsvr1.local in $CONF and run this again." >&2
  exit 1
fi
if [[ "$found" != "$SERVER" ]]; then
  echo "Using $found."
  SERVER="$found"
  if [[ -f "$CONF" ]]; then
    sed -i "s/^SERVER=.*/SERVER=${SERVER}/" "$CONF"
  fi
fi
install -m 644 "$tmp" "$KNOWN_HOSTS"

pubkey=$(cat "$SSH_KEY.pub")
if [[ "$pubkey" == *"'"* ]]; then
  echo "The public key has a character this setup cannot pass safely." >&2
  exit 1
fi

echo "Installing the backup key for ${SSH_USER}@${SERVER}."
echo "Type the password for ${SSH_LOGIN_USER}@${SERVER}, then the sudo password on the server."
sudo -u "$SUDO_USER" -H ssh -tt \
  -o StrictHostKeyChecking=accept-new \
  "${SSH_LOGIN_USER}@${SERVER}" \
  "sudo bash -c 'umask 077; mkdir -p /root/.ssh; touch /root/.ssh/authorized_keys; grep -qxF \"$pubkey\" /root/.ssh/authorized_keys || printf \"%s\\n\" \"$pubkey\" >> /root/.ssh/authorized_keys; chmod 700 /root/.ssh; chmod 600 /root/.ssh/authorized_keys'"

echo "Checking that root can log in for the backup."
if ! ssh -i "$SSH_KEY" \
  -o BatchMode=yes \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=yes \
  -o "UserKnownHostsFile=${KNOWN_HOSTS}" \
  -o ConnectTimeout=30 \
  "${SSH_USER}@${SERVER}" 'echo login-ok'; then
  echo "The key is on the server, and root login was refused." >&2
  echo "On dgsvr1, set this in /etc/ssh/sshd_config and reload ssh:" >&2
  echo "  PermitRootLogin prohibit-password" >&2
  echo "  sudo systemctl reload ssh" >&2
  exit 1
fi

echo "Login works. The drive can stay on this laptop."
echo "Start a copy now with: sudo /usr/local/sbin/dgsvr1-backup full"
echo "Or leave it. Tuesday at 12:01 AM starts the full copy."
