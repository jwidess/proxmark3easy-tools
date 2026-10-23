#!/usr/bin/env bash
set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FIRMWARE_DIR="$SCRIPT_DIR/../firmware"

if [ -n "$1" ] && [ -d "$1" ]; then
    FIRMWARE_DIR="$1"
    shift
fi

BOOTROM="$FIRMWARE_DIR/bootrom.elf"
FULLIMAGE="$FIRMWARE_DIR/fullimage.elf"

echo "=========================================="
echo " Proxmark3 Easy - Firmware Flasher        "
echo "=========================================="
echo ""
echo "[*] Firmware Directory: $FIRMWARE_DIR"

if [ ! -f "$BOOTROM" ]; then
    echo "[!] Error: bootrom.elf not found at $BOOTROM"
    exit 1
fi

if [ ! -f "$FULLIMAGE" ]; then
    echo "[!] Error: fullimage.elf not found at $FULLIMAGE"
    exit 1
fi

echo "[+] Found bootrom.elf:   $BOOTROM"
echo "[+] Found fullimage.elf: $FULLIMAGE"
echo ""

PORT=$(ls /dev/pm3* /dev/ttyACM* 2>/dev/null | head -n 1 || true)
if [ -z "$PORT" ]; then
    echo "[!] No Proxmark3 port detected in WSL (/dev/pm3* or /dev/ttyACM*)."
    echo "    Make sure the device is attached via usbipd."
    exit 1
fi

echo "[*] Target serial port: $PORT"
echo "[*] Flashing bootrom and fullimage..."
echo "    (Device will restart into bootloader and re-enumerate)"
echo ""

proxmark3 "$PORT" --flash --unlock-bootloader --image "$BOOTROM" --image "$FULLIMAGE" "$@"

echo ""
echo "[+] Flashing completed successfully!"
echo "[*] Waiting for device to re-enumerate..."

NEW_PORT=""
for i in $(seq 1 8); do
    sleep 1
    udevadm trigger --action=change 2>/dev/null || true
    for p in /dev/pm3* /dev/ttyACM*; do
        if [ -c "$p" ]; then
            NEW_PORT="$p"
            break 2
        fi
    done
done

if [ -n "$NEW_PORT" ]; then
    sleep 1
    echo "[*] Verifying hardware version on $NEW_PORT..."
    if ! proxmark3 "$NEW_PORT" -c "hw version"; then
        sleep 2
        proxmark3 "$NEW_PORT" -c "hw version" || true
    fi
else
    echo "[*] Flashing succeeded. Device has not re-enumerated yet."
    echo "    Run 'check-hardware.bat' shortly to verify."
fi

echo ""
echo "[+] Done."
