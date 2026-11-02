#!/bin/bash
# Site listesindeki alan adlari icin ayrik (split) DNS: sadece bu domainler Cloudflare DoT ile cozulur.
set -e
IFACE=zapretdns
LIST=/opt/zapret/ipset/zapret-hosts-user.txt

modprobe dummy 2>/dev/null || true
ip link show "$IFACE" >/dev/null 2>&1 || ip link add "$IFACE" type dummy
ip addr replace 10.53.53.1/32 dev "$IFACE"
ip link set "$IFACE" up

for i in $(seq 1 40); do
    resolvectl status "$IFACE" >/dev/null 2>&1 && break
    sleep 0.25
done

resolvectl dns "$IFACE" "1.1.1.1#cloudflare-dns.com" "1.0.0.1#cloudflare-dns.com"
resolvectl dnsovertls "$IFACE" yes

ARGS=()
while IFS= read -r d; do
    d="$(echo "$d" | tr -d '\r' | xargs)"
    [ -z "$d" ] && continue
    ARGS+=("~$d")
done < "$LIST"

if [ ${#ARGS[@]} -eq 0 ]; then
    ARGS=("~discord.com")
fi
resolvectl domain "$IFACE" "${ARGS[@]}"
