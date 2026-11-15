#!/bin/bash
# Remove the split DNS interface; systemd-resolved drops its DNS servers and domains with it.
ip link del zapretdns 2>/dev/null || true
