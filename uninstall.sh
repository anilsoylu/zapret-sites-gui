#!/bin/bash
# Uninstaller for zapret-sites-gui.
set -euo pipefail

PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

[ "$(id -u)" -eq 0 ] || { echo "Root is required. Run 'sudo ./uninstall.sh'." >&2; exit 1; }

systemctl disable --now zapret.service 2>/dev/null || true
systemctl disable --now zapret-dns.service 2>/dev/null || true

rm -f /etc/systemd/system/zapret.service /etc/systemd/system/zapret-dns.service
rm -f /etc/systemd/system/systemd-resolved.service.d/zapret-dns-upholds.conf
rmdir /etc/systemd/system/systemd-resolved.service.d 2>/dev/null || true
systemctl daemon-reload

ip link del zapretdns 2>/dev/null || true

rm -f /usr/local/bin/zapret-sites-gui
rm -f /usr/local/libexec/zapret-gui-helper /usr/local/libexec/zapret-sites-tray
rm -f /usr/local/sbin/zapret-dns-setup.sh /usr/local/sbin/zapret-dns-teardown.sh
rm -f /etc/sudoers.d/zapret-gui

TARGET_USER="${SUDO_USER:-}"
if [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != "root" ]; then
  H="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  rm -f "$H/.local/share/applications/zapret-sites.desktop"
fi

if [ "$PURGE" -eq 1 ]; then
  rm -rf /opt/zapret
  echo "Removed, including /opt/zapret."
else
  echo "Removed. /opt/zapret was kept; to delete it too: sudo ./uninstall.sh --purge"
fi
