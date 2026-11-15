#!/bin/bash
# Runs every test inside the Ubuntu 26.04 test container. From the repo root:
#   docker build -t zapret-sites-gui-test -f tests/Dockerfile tests
#   docker run --rm -v "$PWD":/repo zapret-sites-gui-test bash tests/run-tests.sh
set -uo pipefail
cd "$(dirname "$0")/.."
export FAKE_SYSTEMD_DIR=/tmp/fake-systemd PYTHONDONTWRITEBYTECODE=1
status=0

# Fakes for the parts a container cannot run; the helper itself is the real one.
install -m 755 tests/fakes/sudo tests/fakes/systemctl /usr/local/bin/
install -D -m 755 tests/fakes/zapret-dns-setup.sh /usr/local/sbin/zapret-dns-setup.sh
install -D -m 755 src/zapret-gui-helper /usr/local/libexec/zapret-gui-helper
mkdir -p /opt/zapret/ipset

echo "== unit"; python3 tests/test-domain-logic.py || status=1
echo "== helper"; bash tests/test-helper.sh || status=1

echo "== app flow"
printf 'discord.gg\ndiscord.com\ndiscordapp.com\n' > /opt/zapret/ipset/zapret-hosts-user.txt
rm -rf "$FAKE_SYSTEMD_DIR"
gtk4-broadwayd :5 >/dev/null 2>&1 &
broadway=$!
sleep 1
# Make "systemctl start" slow so the test can prove the UI stays responsive.
FAKE_START_DELAY=1 GDK_BACKEND=broadway BROADWAY_DISPLAY=:5 timeout 60 python3 tests/test-app-flow.py 2>/dev/null || status=1
kill "$broadway" 2>/dev/null

exit $status
