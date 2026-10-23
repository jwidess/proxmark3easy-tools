#!/usr/bin/env bash
############################################################
# Proxmark3 Firmware Update & Repo Sync
############################################################
set -e

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FIRMWARE_DIR="$REPO_DIR/firmware"
PM3_SRC="${1:-$HOME/proxmark3}"
BUILD_DATE="${2:-$(date "+%B %d, %Y at %I:%M %p")}"

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
    printf "Would you like to clone it from GitHub now? [y/N]: "
    if [ -r /dev/tty ]; then
        read -r CONFIRM < /dev/tty
    else
        read -r CONFIRM
    fi
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "[!] Clone cancelled by user. Update aborted."
        exit 1
    fi
    echo "[*] Cloning Iceman fork to $PM3_SRC..."
    if [[ "$PM3_SRC" == /mnt/* ]]; then
        if ! command -v git.exe >/dev/null 2>&1; then
            echo "[!] Git for Windows (git.exe) is required to clone into a Windows-mounted path."
            echo "    Install Git for Windows or choose a path inside the WSL filesystem."
            exit 1
        fi
        windowsPath=$(wslpath -w "$PM3_SRC")
        git.exe -c core.autocrlf=false -c core.filemode=false clone https://github.com/RfidResearchGroup/proxmark3.git "$windowsPath"
        git -C "$PM3_SRC" config core.autocrlf false
        git -C "$PM3_SRC" config core.filemode false
    else
        git clone https://github.com/RfidResearchGroup/proxmark3.git "$PM3_SRC"
    fi
fi

cd "$PM3_SRC"

if [[ "$PM3_SRC" == /mnt/* ]]; then
    if ! git config --global --get-all safe.directory 2>/dev/null | grep -Fxq "$PM3_SRC"; then
        git config --global --add safe.directory "$PM3_SRC"
    fi
fi

# 1. Pull latest Iceman fork changes
echo "[1/5] Pulling latest upstream commits..."
git checkout -q master
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
| **Compilation Date** | $BUILD_DATE |
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
    printf "Proxmark3 detected on %s. Flash new firmware now? [y/N]: " "$PORT"
    if [ -r /dev/tty ]; then
        read -r CONFIRM < /dev/tty
    else
        read -r CONFIRM
    fi
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "[*] Flashing device on $PORT..."
        proxmark3 "$PORT" --flash --unlock-bootloader --image "$FIRMWARE_DIR/bootrom.elf" --image "$FIRMWARE_DIR/fullimage.elf"
        echo "[+] Flash complete. Waiting for device to re-enumerate..."
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
            echo "[*] Device is still re-enumerating. Check 'hw version' shortly."
        fi
    fi
else
    echo "[*] Proxmark3 is not currently attached in WSL."
    echo "    To flash later from Windows, run: .\\flash-firmware.bat"
fi
