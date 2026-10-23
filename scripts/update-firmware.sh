#!/usr/bin/env bash
############################################################
# Proxmark3 Firmware Update & Repo Sync
############################################################
set -e

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FIRMWARE_DIR="$REPO_DIR/firmware"
PM3_SRC="${1:-$HOME/proxmark3}"

echo "=========================================="
echo " Proxmark3 Easy: Update & Compile Firmware"
echo "=========================================="
echo ""
echo "[*] Source directory: $PM3_SRC"
echo "[*] Destination repo: $FIRMWARE_DIR"
echo ""

if [ ! -d "$PM3_SRC" ]; then
    echo "[!] Proxmark3 source repository not found at '$PM3_SRC'."
    echo "[*] The Iceman fork repository is large (~300MB+ download)."
    read -r -p "Would you like to clone it from GitHub now? [y/N]: " CONFIRM < /dev/tty 2>/dev/null || read -r -p "Would you like to clone it from GitHub now? [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "[!] Clone cancelled by user. Update aborted."
        exit 1
    fi
    echo "[*] Cloning Iceman fork to $PM3_SRC..."
    git clone https://github.com/RfidResearchGroup/proxmark3.git "$PM3_SRC"
fi

cd "$PM3_SRC"

# 1. Pull latest Iceman fork changes
echo "[1/5] Pulling latest upstream commits..."
git checkout master
git pull

NEW_COMMIT=$(git rev-parse --short HEAD)
NEW_TAG=$(git describe --tags --always 2>/dev/null || echo "$NEW_COMMIT")
COMMIT_DATE=$(git log -1 --format=%cd --date=short)

echo "  [+] Current upstream version: $NEW_TAG ($NEW_COMMIT) from $COMMIT_DATE"

# 2. Verify Makefile.platform configuration
echo ""
echo "[2/5] Setting up Makefile.platform for Proxmark3 Easy..."
cat << 'EOF' > Makefile.platform
PLATFORM=PM3GENERIC
PLATFORM_EXTRAS=FLASH
LED_ORDER=PM3EASY
STANDALONE=LF_SAMYRUN
EOF

# 3. Clean and build
echo ""
echo "[3/5] Compiling firmware and client (using $(nproc) cores)..."
make clean
make -j"$(nproc)"

echo "[*] Installing client tools to /usr/local/bin..."
sudo make install

# 4. Copy binaries to proxmark3easy-tools
echo ""
echo "[4/5] Copying compiled artifacts to proxmark3easy-tools/firmware/..."
mkdir -p "$FIRMWARE_DIR"

cp -v bootrom/obj/bootrom.elf "$FIRMWARE_DIR/"
cp -v armsrc/obj/fullimage.elf "$FIRMWARE_DIR/"
cp -v recovery/bootrom.bin "$FIRMWARE_DIR/"
cp -v recovery/fullimage.bin "$FIRMWARE_DIR/"
cp -v recovery/recovery.bin "$FIRMWARE_DIR/"
cp -v Makefile.platform "$FIRMWARE_DIR/"

# Update FIRMWARE_INFO.md metadata
INFO_FILE="$FIRMWARE_DIR/FIRMWARE_INFO.md"
TODAY=$(date "+%B %d, %Y")

cat << EOF > "$INFO_FILE"
# Firmware Information & Build Manifest

This document records the firmware version and build parameters compiled and flashed for the **Proxmark3 Easy (512KB)**.

---

## 1. Build & Git Metadata

| Property | Value |
| :--- | :--- |
| **Firmware Branch/Tag** | \`$NEW_TAG\` |
| **Upstream Git Commit** | [\`$NEW_COMMIT\`](https://github.com/RfidResearchGroup/proxmark3/commit/$NEW_COMMIT) |
| **Upstream Repository** | [RfidResearchGroup/proxmark3](https://github.com/RfidResearchGroup/proxmark3) |
| **Compilation Date** | $TODAY |
| **ARM Toolchain** | \`$(arm-none-eabi-gcc --version | head -n 1)\` |
| **Host Compiler** | \`$(gcc --version | head -n 1)\` |

---

## 2. Configuration Parameters (\`Makefile.platform\`)

\`\`\`makefile
PLATFORM=PM3GENERIC
PLATFORM_EXTRAS=FLASH
LED_ORDER=PM3EASY
STANDALONE=LF_SAMYRUN
\`\`\`

- **\`PLATFORM=PM3GENERIC\`**: Targets generic Proxmark3 boards (PM3 Easy).
- **\`PLATFORM_EXTRAS=FLASH\`**: Enables external SPI flash driver (required for \`eload\` and \`eview\`).
- **\`LED_ORDER=PM3EASY\`**: Maps GPIOs to match board silkscreen LEDs.
- **\`STANDALONE=LF_SAMYRUN\`**: Samy Kamkar's HID26 standalone mode.

---

## 3. Included Binary Files

- [\`bootrom.elf\`](./bootrom.elf) & [\`bootrom.bin\`](./bootrom.bin): Bootloader image
- [\`fullimage.elf\`](./fullimage.elf) & [\`fullimage.bin\`](./fullimage.bin): Operating system & FPGA bitstreams
- [\`recovery.bin\`](./recovery.bin): Combined recovery binary
- [\`Makefile.platform\`](./Makefile.platform): Exact build configuration
EOF

echo "  [+] Updated $INFO_FILE"

# 5. Optional flash
echo ""
echo "=========================================="
echo " Compilation and Sync Complete!           "
echo "=========================================="
echo "New Version: $NEW_TAG ($NEW_COMMIT)"
echo ""

PORT=$(ls /dev/pm3* /dev/ttyACM* 2>/dev/null | head -n 1 || true)
if [ -n "$PORT" ]; then
    read -r -p "Proxmark3 detected on $PORT. Flash new firmware now? [y/N]: " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "[*] Flashing device on $PORT..."
        proxmark3 "$PORT" --flash --unlock-bootloader --image "$FIRMWARE_DIR/bootrom.elf" --image "$FIRMWARE_DIR/fullimage.elf"
        echo "[+] Flash complete. Verifying hw version..."
        sleep 3
        udevadm trigger --action=change 2>/dev/null || true
        NEW_PORT=$(ls /dev/pm3* /dev/ttyACM* 2>/dev/null | head -n 1 || true)
        [ -n "$NEW_PORT" ] && proxmark3 "$NEW_PORT" -c "hw version" || true
    fi
else
    echo "[*] Proxmark3 is not currently attached in WSL."
    echo "    To flash later from Windows, run: .\\flash-firmware.bat"
fi
