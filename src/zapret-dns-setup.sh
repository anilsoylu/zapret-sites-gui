#!/bin/bash
# Split DNS for the listed domains: only these resolve through Cloudflare DNS-over-TLS.
# Usage: zapret-dns-setup.sh           full setup (zapret-dns.service)
#        zapret-dns-setup.sh domains   re-apply routing domains after a list change
set -e
IFACE=zapretdns
LIST=/opt/zapret/ipset/zapret-hosts-user.txt

apply_domains() {
    local args=() d
    while IFS= read -r d || [ -n "$d" ]; do
        d="${d//$'\r'/}"
        d="${d#"${d%%[![:space:]]*}"}"
        d="${d%"${d##*[![:space:]]}"}"
        [ -n "$d" ] && args+=("~$d")
    done < "$LIST"
    [ ${#args[@]} -gt 0 ] || args=("~discord.com")
    # Replaces the link's previous domain list.
    resolvectl domain "$IFACE" "${args[@]}"
    # Drop answers cached before a domain was routed here (they may be the ISP's fake address).
    resolvectl flush-caches
}

if [ "${1:-}" = domains ]; then
    apply_domains
    exit 0
fi

modprobe dummy 2>/dev/null || true
ip link show "$IFACE" >/dev/null 2>&1 || ip link add "$IFACE" type dummy
ip addr replace 10.53.53.1/32 dev "$IFACE"
ip link set "$IFACE" up

for _ in $(seq 1 40); do
    resolvectl status "$IFACE" >/dev/null 2>&1 && break
    sleep 0.25
done

resolvectl dns "$IFACE" "1.1.1.1#cloudflare-dns.com" "1.0.0.1#cloudflare-dns.com"
resolvectl dnsovertls "$IFACE" yes
apply_domains
