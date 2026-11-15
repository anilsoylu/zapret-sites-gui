#!/bin/bash
# Tests the root helper's list handling inside the test container (runs as root there).
# Run: docker run --rm -v "$PWD":/repo zapret-sites-gui-test bash tests/test-helper.sh
set -uo pipefail
HELPER="$(dirname "$0")/../src/zapret-gui-helper"
LIST=/opt/zapret/ipset/zapret-hosts-user.txt
mkdir -p "$(dirname "$LIST")"
fail=0

check() {
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected [$2] got [$3]"; fail=1; fi
}

printf '  discord.com \r\n\n\tx.com\nlast.net' | bash "$HELPER" set-list >/dev/null 2>&1
check "set-list trims, skips blanks, keeps a last line without newline" \
  "$(printf 'discord.com\nx.com\nlast.net')" "$(cat "$LIST")"

out="$(printf 'ok.com\nbad domain\n' | bash "$HELPER" set-list 2>&1)"; code=$?
check "set-list rejects an invalid domain with exit 2" "2" "$code"
check "set-list names the invalid domain" "Invalid domain: bad domain" "$out"
check "a rejected list leaves the file unchanged" "$(printf 'discord.com\nx.com\nlast.net')" "$(cat "$LIST")"

printf '\n  \n' | bash "$HELPER" set-list >/dev/null 2>&1; code=$?
check "set-list rejects an empty list with exit 2" "2" "$code"

out="$(printf 'a.com\n' | bash "$HELPER" set-list 2>/dev/null)"
check "set-list prints the service status keys" "zapret,dns," "$(printf '%s\n' "$out" | cut -d= -f1 | tr '\n' ',')"

bash "$HELPER" bogus >/dev/null 2>&1; code=$?
check "unknown command exits 1" "1" "$code"

exit $fail
