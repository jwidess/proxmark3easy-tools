#!/usr/bin/env bash
set -e

echo "=========================================="
echo " Proxmark3 Easy - WSL Environment Setup  "
echo "=========================================="
echo ""

echo "[1/4] Updating package index and installing dependencies..."
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    git ca-certificates build-essential pkg-config \
    libreadline-dev gcc-arm-none-eabi libnewlib-dev \
    libbz2-dev liblz4-dev libpython3-dev qtbase5-dev \
    libssl-dev libgd-dev udev

echo ""
echo "[2/4] Adding user '$USER' to dialout group..."
sudo usermod -aG dialout "$USER"

echo ""
echo "[3/4] Installing Proxmark3 udev rules..."
sudo tee /etc/udev/rules.d/77-pm3-usb-device-blacklist.rules > /dev/null << 'EOF'
ACTION!="add|change", GOTO="pm3_usb_device_blacklist_end"
SUBSYSTEM!="tty", GOTO="pm3_ignore"

# Proxmark3 VID:PIDs
ATTRS{idVendor}=="9ac4", ATTRS{idProduct}=="4b8f", SYMLINK+="pm3-%n", MODE="0660", GROUP="dialout"
ATTRS{idVendor}=="502d", ATTRS{idProduct}=="502d", SYMLINK+="pm3-%n", MODE="0660", GROUP="dialout"
ATTRS{idVendor}=="2d2d", ATTRS{idProduct}=="504d", SYMLINK+="pm3-%n", MODE="0660", GROUP="dialout"

LABEL="pm3_ignore"
LABEL="pm3_usb_device_blacklist_end"
EOF

if sudo service udev restart 2>/dev/null; then
    echo "[+] udev service restarted."
else
    echo "[*] udev.service is not available in this WSL instance; refreshing device rules directly."
fi
sudo udevadm trigger --action=change || true

echo ""
PM3_SRC="${1:-$HOME/proxmark3}"
echo "[4/4] Checking Proxmark3 repo in $PM3_SRC..."
if [ ! -d "$PM3_SRC" ]; then
    echo "[!] Proxmark3 repository not found in $PM3_SRC."
    echo "[*] The Iceman fork repository is large (~300MB+ download)."
    printf "Would you like to download, clone, and compile it now? [y/N]: "
    if [ -r /dev/tty ]; then
        read -r CONFIRM < /dev/tty
    else
        read -r CONFIRM
    fi
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "[*] Cloning Iceman proxmark3 repo to $PM3_SRC..."
        if [[ "$PM3_SRC" == /mnt/* ]]; then
            if ! command -v git.exe >/dev/null 2>&1; then
                echo "[!] Git for Windows (git.exe) is required to clone into a Windows-mounted path."
                echo "    Install Git for Windows or choose a path inside the WSL filesystem."
                exit 1
            fi
            windowsPath=$(wslpath -w "$PM3_SRC")
            git.exe -c core.autocrlf=false -c core.filemode=false clone https://github.com/RfidResearchGroup/proxmark3.git "$windowsPath"
            git config --global --add safe.directory "$PM3_SRC"
            git -C "$PM3_SRC" config core.autocrlf false
            git -C "$PM3_SRC" config core.filemode false
        else
            git clone https://github.com/RfidResearchGroup/proxmark3.git "$PM3_SRC"
        fi
        cd "$PM3_SRC"
        cat << 'EOF' > Makefile.platform
PLATFORM=PM3GENERIC
PLATFORM_EXTRAS=FLASH
LED_ORDER=PM3EASY
STANDALONE=LF_SAMYRUN
EOF
        echo "[*] Compiling Proxmark3 client and firmware..."
        make clean
        make -j"$(nproc)"
        echo "[*] Installing client and tools to /usr/local/bin..."
        sudo make install
    else
        echo "[*] Clone and compile skipped. You can flash the precompiled binaries anytime using .\\flash-firmware.bat."
    fi
elif [ ! -d "$PM3_SRC/.git" ]; then
    echo "[!] The directory $PM3_SRC exists but is not a Git repository."
    echo "    Remove or choose another directory, then run setup again."
    exit 1
else
    echo "[+] Found existing Proxmark3 repo in $PM3_SRC."
    if [[ "$PM3_SRC" == /mnt/* ]]; then
        if ! git config --global --get-all safe.directory 2>/dev/null | grep -Fxq "$PM3_SRC"; then
            git config --global --add safe.directory "$PM3_SRC"
        fi
        git -C "$PM3_SRC" config core.autocrlf false 2>/dev/null || true
        git -C "$PM3_SRC" config core.filemode false 2>/dev/null || true
    fi
fi

echo ""
echo "=========================================="
echo " WSL Environment Setup Complete!          "
echo "=========================================="
