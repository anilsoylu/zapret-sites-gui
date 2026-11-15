#!/bin/bash
# Test double for the split DNS script: records how it was called.
echo "dns-setup ${1:-full}" >> "${FAKE_SYSTEMD_DIR:-/tmp/fake-systemd}/calls.log"
