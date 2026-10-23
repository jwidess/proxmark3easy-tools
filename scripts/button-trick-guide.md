# The "Button Trick" (Bootloader Rescue Mode)

If your Proxmark3 Easy ever fails to communicate, is disconnected in the middle of a flash, or shows incorrect LEDs, you can force the device into its secondary bootloader mode using **the button trick**.

---

## How to Enter Bootloader Mode

1. **Unplug** the Proxmark3 Easy from your USB cable.
2. **Press and hold down the button** on the side of the Proxmark3 Easy board.
3. While continuing to hold the button, **plug the USB cable back into your computer**.
4. Keep holding the button until the LEDs illuminate:
   - On a healthy bootloader, **two LEDs (usually red and orange/green)** will stay permanently illuminated.
   - You can then **release the button**.
   *(Note: If the LEDs turn off when you release the button, your bootloader is very old, in that case, keep holding the button continuously through the flashing process).*
5. The device is now waiting in **Bootloader Mode**.

---

## Flashing from Bootloader Mode

Once in bootloader mode, run the flasher script:

### Via PowerShell:
```powershell
.\flash-firmware.bat
# or
.\scripts\flash-firmware.ps1 -Force
```

### Via WSL Terminal:
```bash
./scripts/flash-firmware.sh --force
```

### Or manually:
```bash
proxmark3 /dev/ttyACM0 --flash --unlock-bootloader --image firmware/bootrom.elf --image firmware/fullimage.elf --force
```

---

## Emergency Jumper / Hardware Recovery (JTAG)
If the button trick does not work (e.g. bootloader was overwritten or corrupted):
- Connect an AT91SAM7S JTAG programmer to the unpopulated JTAG header on the board.
- Flash `firmware/recovery.bin` directly at address `0x00100000`.
