#!/usr/bin/env bash
############################################################
# Proxmark3 Client Launcher
############################################################

echo "=========================================="
echo " Proxmark3 Client Session                 "
echo "=========================================="
echo ""

# Ensure udev has registered any recent devices
udevadm trigger --action=change 2>/dev/null || true

# Try launching pm3 from PATH, or fallback to local clone
if command -v pm3 >/dev/null 2>&1; then
    pm3 "$@"
elif [ -f "$HOME/proxmark3/pm3" ]; then
    cd "$HOME/proxmark3" && ./pm3 "$@"
elif [ -f "$HOME/proxmark3/client/proxmark3" ]; then
    "$HOME/proxmark3/client/proxmark3" "$@"
else
    echo "[!] Could not locate 'pm3' executable in PATH or in ~/proxmark3/."
    echo "    Please run setup-wsl-environment or compile proxmark3 in WSL."
fi

echo ""
echo "Session finished. Press [Enter] to close..."
read -r
