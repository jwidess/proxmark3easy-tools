#!/usr/bin/env bash
set -e

PORT=$(ls /dev/pm3* /dev/ttyACM* 2>/dev/null | head -n 1 || true)
if [ -z "$PORT" ]; then
    echo "[!] No Proxmark3 serial device found in WSL (/dev/pm3* or /dev/ttyACM*)."
    echo "    Make sure the device is attached via usbipd."
    exit 1
fi

echo "[+] Connected to Proxmark3 on $PORT"
echo ""

echo "=========================================="
echo " 1. HARDWARE VERSION                      "
echo "=========================================="
proxmark3 "$PORT" -c "hw version"
echo ""

echo "=========================================="
echo " 2. HARDWARE STATUS & SPI FLASH           "
echo "=========================================="
proxmark3 "$PORT" -c "hw status; mem spiffs info"
echo ""

echo "=========================================="
echo " 3. PING & ANTENNA TUNE                   "
echo "=========================================="
proxmark3 "$PORT" -c "hw ping; hw tune"
echo ""
echo "[+] All checks complete!"
