# Firmware Information & Build Manifest

This document records the firmware version and build parameters compiled and flashed for the **Proxmark3 Easy (512KB)**.

---

## 1. Build & Git Metadata

| Property | Value |
| :--- | :--- |
| **Firmware Branch/Tag** | `v4.23346-211-g6ce4ec49c` |
| **Upstream Git Commit** | [`6ce4ec49c`](https://github.com/RfidResearchGroup/proxmark3/commit/6ce4ec49c) |
| **Upstream Repository** | [RfidResearchGroup/proxmark3](https://github.com/RfidResearchGroup/proxmark3) |
| **Compilation Date** | October 23, 2026 at 02:44 PM |
| **ARM Toolchain** | `arm-none-eabi-gcc (15:14.2.rel1-1) 14.2.1 20241119` |
| **Host Compiler** | `gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0` |

---

## 2. Configuration Parameters (`Makefile.platform`)

```makefile
PLATFORM=PM3GENERIC
PLATFORM_EXTRAS=FLASH
LED_ORDER=PM3EASY
STANDALONE=LF_SAMYRUN
```

- **`PLATFORM=PM3GENERIC`**: Targets generic Proxmark3 boards (PM3 Easy).
- **`PLATFORM_EXTRAS=FLASH`**: Enables external SPI flash driver (required for `eload` and `eview`).
- **`LED_ORDER=PM3EASY`**: Maps GPIOs to match board silkscreen LEDs.
- **`STANDALONE=LF_SAMYRUN`**: Samy Kamkar's HID26 standalone mode.

---

## 3. Included Binary Files

- [`bootrom.elf`](./bootrom.elf) & [`bootrom.bin`](./bootrom.bin): Bootloader image
- [`fullimage.elf`](./fullimage.elf) & [`fullimage.bin`](./fullimage.bin): Operating system & FPGA bitstreams
- [`recovery.bin`](./recovery.bin): Combined recovery binary
- [`Makefile.platform`](./Makefile.platform): Exact build configuration
