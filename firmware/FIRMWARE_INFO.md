# Firmware Information & Build Manifest

This document records the firmware version, hardware config, and build parameters compiled and flashed to my **Proxmark3 Easy**.

---

## 1. Build & Git Metadata

| Property | Value |
| :--- | :--- |
| **Compilation Date** | October 23, 2026 |
| **Firmware Branch/Tag** | `Iceman/master/v4.23346-209-gc10930d6e` |
| **Upstream Git Commit** | `c10930d6e` |
| **Upstream Repository** | [RfidResearchGroup/proxmark3](https://github.com/RfidResearchGroup/proxmark3) |
| **ARM Toolchain** | `arm-none-eabi-gcc 13.2.1 20231009` |
| **Host Compiler** | `GCC 13.3.0` (Ubuntu 24.04 on WSL2) |

---

## 2. Configuration Parameters (`Makefile.platform`)

```makefile
PLATFORM=PM3GENERIC
PLATFORM_EXTRAS=FLASH
LED_ORDER=PM3EASY
STANDALONE=LF_SAMYRUN
```

1. **`PLATFORM=PM3GENERIC`**
   - Targets generic Proxmark3 Easy instead of default RDV4 target.
2. **`PLATFORM_EXTRAS=FLASH`**
   - Generic Proxmark3 boards equipped with external SPI flash require this flag to enable the flash driver.
   - Without `FLASH`, commands such as `hf mfu eload` and `hf mfu eview` fail silently (or show blank blocks).
3. **`LED_ORDER=PM3EASY`**
   - The Proxmark3 Easy PCB routes LEDs in a different sequence than the RDV4. `PM3EASY` aligns the firmware LED driver with the silkscreen on the board.
4. **`STANDALONE=LF_SAMYRUN`**
   - Samy Kamkar's HID26 read/clone/sim standalone mode. Fits within the 512KB flash (89% total image).

---

## 3. Hardware Verification

```text
 [ Proxmark3 ]

 [ Client ]
  Iceman/master/v4.23346-209-gc10930d6e-suspect 2026-10-23 00:24:53 544c2b2b1
  Compiler.................. GCC 13.3.0
  Platform.................. Linux / x86_64
  Readline support.......... present
  QT GUI support............ present
  Native BT support......... absent
  Python script support..... present ( 3.12.3 )
  Python SWIG support....... present
  Lua script support........ present ( 5.4.7 )
  Lua SWIG support.......... present

 [ Model ]
  Firmware.................. PM3 GENERIC
  External flash............ present

 [ ARM ]
  Bootrom.... Iceman/master/v4.23346-209-gc10930d6e-suspect 2026-10-23 00:23:44 544c2b2b1
  OS......... Iceman/master/v4.23346-209-gc10930d6e-suspect 2026-10-23 00:24:02 544c2b2b1
  Compiler... GCC 13.2.1 20231009

 [ FPGA ] 
  fpga_pm3_hf.ncd image 2s30vq100 05-11-2025 22:34:27
  fpga_pm3_lf.ncd image 2s30vq100 23-10-2026 00:23:25
  fpga_pm3_felica.ncd image 2s30vq100 23-10-2026 00:23:25
  fpga_pm3_hf_15.ncd image 2s30vq100 05-11-2025 22:34:27

 [ Hardware ]
  --= uC: AT91SAM7S512 Rev A
  --= Embedded Processor: ARM7TDMI
  --= Internal SRAM size: 64K bytes
  --= Architecture identifier: AT91SAM7Sxx Series
  --= Embedded flash memory 512K bytes ( 89% used )
```

### Flash Memory Status (`hw status`)
```text
[#] Flash memory
[#]   Baudrate................ 24 MHz
[#]   Init.................... ok
[#]   Mfr ID / Dev ID......... 85 / 14
[#]   JEDEC Mfr ID / Dev ID... 85 / 6015
[#]   Memory size............. 2048 Kb ( 32 pages * 64k )
[#]   Unique ID (be).......... 0x0739383153325041
```

### Antenna Tuning (`hw tune`)
```text
[=] -------- LF Antenna ----------
[+] 125.00 kHz ........... 25.91 V
[+] 134.83 kHz ........... 17.89 V
[+] 122.45 kHz optimal.... 26.68 V
[+] LF antenna............ ok

[=] -------- HF Antenna ----------
[+] 13.56 MHz............. 16.04 V
[+] HF antenna ( ok )
```

---

## 4. Binary Files

- [`bootrom.elf`](./bootrom.elf) & [`bootrom.bin`](./bootrom.bin): Secondary bootloader image (16 KB)
- [`fullimage.elf`](./fullimage.elf) & [`fullimage.bin`](./fullimage.bin): Full operating system and FPGA bitstreams (~460 KB)
- [`recovery.bin`](./recovery.bin): Combined bootloader + full image recovery binary (~475 KB)
- [`Makefile.platform`](./Makefile.platform): Exact build configuration file used to build these binaries
