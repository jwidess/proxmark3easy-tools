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

sudo service udev restart
sudo udevadm trigger --action=change || true

echo ""
echo "[4/4] Checking Proxmark3 repo in ~/proxmark3..."
if [ ! -d "$HOME/proxmark3" ]; then
    echo "[*] Cloning Iceman proxmark3 repo to ~/proxmark3..."
    git clone https://github.com/RfidResearchGroup/proxmark3.git "$HOME/proxmark3"
fi

cd "$HOME/proxmark3"

# Configure Makefile.platform
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

echo ""
echo "=========================================="
echo " WSL Environment Setup Complete!          "
echo "=========================================="
echo "You can now run 'pm3' from any shell."
