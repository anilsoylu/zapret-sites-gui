#!/bin/bash
# zapret-sites-gui kurulum scripti. Ubuntu/Debian + systemd-resolved icin.
set -euo pipefail

ZAPRET_VER="72.13"
ZAPRET_URL="https://github.com/bol-van/zapret/archive/refs/tags/v${ZAPRET_VER}.tar.gz"
ZAPRET_SHA256="04696a1b6fe766e35cd6426555520c79d5052a759cdf4d7724a1f46eba4670f6"
PREFIX="/opt/zapret"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'Hata: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Root gerekli. 'sudo ./install.sh' calistir."
[ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ] \
  || die "SUDO_USER bulunamadi. Scripti 'sudo ./install.sh' ile calistir."

TARGET_USER="$SUDO_USER"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "$TARGET_USER")"

command -v systemctl >/dev/null || die "systemd bulunamadi."
command -v resolvectl >/dev/null || die "systemd-resolved bulunamadi."

log "Bagimliliklar kuruluyor"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  build-essential libnetfilter-queue-dev libmnl-dev libnfnetlink-dev \
  zlib1g-dev libcap-dev ipset iptables nftables unzip curl ca-certificates \
  python3-gi gir1.2-gtk-4.0 gir1.2-adw-1

log "zapret v${ZAPRET_VER} indiriliyor"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$ZAPRET_URL" -o "$TMP/zapret.tar.gz"
echo "${ZAPRET_SHA256}  $TMP/zapret.tar.gz" | sha256sum -c - >/dev/null \
  || die "Arsiv ozet degeri dogrulanamadi"

tar -xzf "$TMP/zapret.tar.gz" -C "$TMP"
SRC="$TMP/zapret-${ZAPRET_VER}"
[ -d "$SRC" ] || die "Arsiv beklenen dizini icermiyor"

log "zapret derleniyor"
systemctl stop zapret.service 2>/dev/null || true
rm -rf "$PREFIX"
install -d -m 755 "$PREFIX"
cp -a "$SRC"/. "$PREFIX"/
make -C "$PREFIX" -j"$(nproc)" >/dev/null

log "Yapilandirma yaziliyor"
cat >> "$PREFIX/config" <<'EOF'

# --- zapret-sites-gui ---
NFQWS_ENABLE=1
NFQWS_PORTS_TCP=80,443
NFQWS_PORTS_UDP=443,3478,19294-19344,50000-50100
MODE_FILTER=hostlist
DISABLE_IPV6=1
FLOWOFFLOAD=donttouch
NFQWS_OPT="
--filter-tcp=80 --dpi-desync=multisplit --dpi-desync-split-pos=method+2 <HOSTLIST> --new
--filter-tcp=443 --dpi-desync=multisplit --dpi-desync-split-pos=2 <HOSTLIST> --new
--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6 <HOSTLIST> --new
--filter-udp=50000-50100,19294-19344 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6
"
EOF

install -d -m 755 "$PREFIX/ipset"
install -m 644 "$HERE/lists/default-domains.txt" "$PREFIX/ipset/zapret-hosts-user.txt"

log "Dosyalar kuruluyor"
install -d -m 755 /usr/local/libexec /usr/local/sbin /usr/local/bin
install -m 755 "$HERE/src/zapret-gui-helper" /usr/local/libexec/zapret-gui-helper
install -m 755 "$HERE/src/zapret-dns-setup.sh" /usr/local/sbin/zapret-dns-setup.sh
install -m 755 "$HERE/src/zapret-dns-teardown.sh" /usr/local/sbin/zapret-dns-teardown.sh
install -m 755 "$HERE/src/zapret-sites-gui" /usr/local/bin/zapret-sites-gui
install -m 644 "$HERE/src/zapret.service" /etc/systemd/system/zapret.service
install -m 644 "$HERE/src/zapret-dns.service" /etc/systemd/system/zapret-dns.service
install -d -m 755 /etc/systemd/system/systemd-resolved.service.d
install -m 644 "$HERE/src/systemd-resolved-upholds.conf" \
  /etc/systemd/system/systemd-resolved.service.d/zapret-dns-upholds.conf

log "Sudo kurali yaziliyor"
printf '%s ALL=(root) NOPASSWD: /usr/local/libexec/zapret-gui-helper\n' "$TARGET_USER" \
  > /etc/sudoers.d/zapret-gui
chmod 440 /etc/sudoers.d/zapret-gui
if ! visudo -cf /etc/sudoers.d/zapret-gui >/dev/null; then
  rm -f /etc/sudoers.d/zapret-gui
  die "Sudoers kurali gecersiz, dosya silindi."
fi

log "Uygulama kisayolu ekleniyor"
DESKTOP_DIR="$TARGET_HOME/.local/share/applications"
install -d -o "$TARGET_USER" -g "$TARGET_GROUP" "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/zapret-sites.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Site Erişimi
Comment=DPI bypass aç/kapat ve kapsanan siteleri seç
Exec=/usr/local/bin/zapret-sites-gui
Icon=network-vpn
Terminal=false
Categories=Network;Settings;
Keywords=zapret;discord;dpi;bypass;vpn;instagram;roblox;
StartupWMClass=tr.anilsoylu.ZapretSites
EOF
chown "$TARGET_USER:$TARGET_GROUP" "$DESKTOP_DIR/zapret-sites.desktop"
chmod 644 "$DESKTOP_DIR/zapret-sites.desktop"

log "Servisler etkinlestiriliyor"
systemctl daemon-reload
systemctl enable --now zapret-dns.service
systemctl enable --now zapret.service

sleep 1
printf '\nKurulum tamam.\n'
printf 'zapret: %s\n' "$(systemctl is-active zapret.service)"
printf 'zapret-dns: %s\n' "$(systemctl is-active zapret-dns.service)"
printf '\nArayuzu acmak icin: zapret-sites-gui\n'
