EEPROM Recovery
===============
The boot selector partition (partition 1) contains the following files
prefixed with underscores to prevent the GPU ROM from auto-flashing:

  _recovery.bin_      GPU ROM recovery bootloader
  _pieeprom.bin_      Recovery EEPROM firmware (SIGNED_BOOT disabled)
  _pieeprom.sig_      RSA-signed signature for the recovery EEPROM
  _pieeprom.upd_      Signed EEPROM firmware (SIGNED_BOOT=1 + public key)
  _pieeprom.upd.sig_  Hash-only signature for the signed EEPROM

The GPU ROM checks for recovery.bin before running the EEPROM bootloader.
If found, recovery.bin flashes pieeprom.upd (verified against pieeprom.sig)
into the SPI EEPROM, renames recovery.bin to recovery.000, and reboots.
See: https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#eeprom-boot-flow

IMPORTANT: These procedures only work if the OTP fuses have not been
programmed (PROGRAM_PUBLIC_KEY was not set to 1). Once the public key is
burned into OTP, secure boot is permanently enabled and cannot be disabled.

Use the rpi-secureboot helper script instead of manual steps:
  rpi-secureboot status   - show current secure boot status
  rpi-secureboot enable   - enable secure boot and reboot
  rpi-secureboot disable  - disable secure boot and reboot

Manual Procedure
================

Enable Secure Boot
------------------
1. Copy the signed EEPROM and recovery bootloader into place:
     mount /dev/mmcblk0p1 /mnt
     cp /mnt/_pieeprom.upd_ /mnt/pieeprom.upd
     cp /mnt/_pieeprom.upd.sig_ /mnt/pieeprom.sig
     cp /mnt/_recovery.bin_ /mnt/recovery.bin
     umount /mnt
     reboot

2. The GPU ROM will find recovery.bin, flash the signed EEPROM
   (SIGNED_BOOT=1 with embedded public key), rename recovery.bin
   to recovery.000, and reboot.


Disable Secure Boot
-------------------
Only works if OTP fuses were not programmed (revkey_fuses not burned).

1. Copy the recovery EEPROM and recovery bootloader into place:
     mount /dev/mmcblk0p1 /mnt
     cp /mnt/_pieeprom.bin_ /mnt/pieeprom.upd
     cp /mnt/_pieeprom.sig_ /mnt/pieeprom.sig
     cp /mnt/_recovery.bin_ /mnt/recovery.bin
     umount /mnt
     reboot

2. The GPU ROM will find recovery.bin, flash the recovery EEPROM
   (SIGNED_BOOT disabled), rename recovery.bin to recovery.000,
   and reboot.

