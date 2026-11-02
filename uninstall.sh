#!/bin/bash
# zapret-sites-gui kaldirma scripti.
set -euo pipefail

PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

[ "$(id -u)" -eq 0 ] || { echo "Root gerekli. 'sudo ./uninstall.sh' calistir." >&2; exit 1; }

systemctl disable --now zapret.service 2>/dev/null || true
systemctl disable --now zapret-dns.service 2>/dev/null || true

rm -f /etc/systemd/system/zapret.service /etc/systemd/system/zapret-dns.service
systemctl daemon-reload

ip link del zapretdns 2>/dev/null || true

rm -f /usr/local/bin/zapret-sites-gui
rm -f /usr/local/libexec/zapret-gui-helper
rm -f /usr/local/sbin/zapret-dns-setup.sh /usr/local/sbin/zapret-dns-teardown.sh
rm -f /etc/sudoers.d/zapret-gui

TARGET_USER="${SUDO_USER:-}"
if [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != "root" ]; then
  H="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  rm -f "$H/.local/share/applications/zapret-sites.desktop"
fi

if [ "$PURGE" -eq 1 ]; then
  rm -rf /opt/zapret
  echo "Kaldirildi, /opt/zapret dahil."
else
  echo "Kaldirildi. /opt/zapret korundu, tamamen silmek icin: sudo ./uninstall.sh --purge"
fi
