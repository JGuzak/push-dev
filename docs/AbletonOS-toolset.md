# AbletonOS Toolset Reference

This file records tools and artifacts observed while working against Push
Standalone over SSH for PushBridge. It is not a full AbletonOS inventory; it is
the known-good and known-missing set from prior project work.

Target context observed during collection:

- Device: Ableton Push 3 Standalone
- OS family: AbletonOS x86_64 Intel image
- Kernel: `5.15.48-intel-pk-preempt-rt`
- Remote access used: `ssh root@push` / `scp`

- [AbletonOS Toolset Reference](#abletonos-toolset-reference)
  - [Available Tools](#available-tools)
    - [Remote Access And Shell](#remote-access-and-shell)
    - [Core Inspection Utilities](#core-inspection-utilities)
    - [Kernel And Module Utilities](#kernel-and-module-utilities)
    - [ALSA And Audio Inspection](#alsa-and-audio-inspection)
    - [USB And Hardware Inspection](#usb-and-hardware-inspection)
    - [Debugging Tools](#debugging-tools)
  - [Unavailable Or Absent](#unavailable-or-absent)
    - [Build Toolchain And Kernel Build Artifacts](#build-toolchain-and-kernel-build-artifacts)
    - [Virtual ALSA Shortcut Modules](#virtual-alsa-shortcut-modules)
  - [Known Useful Command Bundles](#known-useful-command-bundles)
    - [Kernel Identity](#kernel-identity)
    - [ALSA Card Visibility](#alsa-card-visibility)
    - [Module Loader Debugging](#module-loader-debugging)
    - [USB Device Inspection](#usb-device-inspection)
  - [Cautions](#cautions)

## Available Tools

### Remote Access And Shell

| Tool         | Status    | Version                                    | Notes                                                                                                             |
| ------------ | --------- | ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| `ssh` server | Available | `OpenSSH_8.9p1, OpenSSL 3.0.17 1 Jul 2025` | OpenSSH server observed via `/usr/sbin/sshd`. Remote root shell access worked through the configured `push` host. |
| `scp` server | Available | `OpenSSH_8.9p1`                            | Served by the same OpenSSH stack as `sshd`. Used to copy modules and test artifacts to Push.                      |
| `rsync`      | Available | `3.2.7` (protocol 31)                      | Installed on Push and usable for remote sync/copy workflows.                                                      |
| `sh`         | Available | `GNU bash 5.1.16(1)-release`               | `/bin/sh` resolved to a bash-based shell on this image.                                                           |
| `test`       | Available | Bash builtin                               | Shell builtin from the installed bash shell.                                                                      |
| `mkdir`      | Available | `GNU coreutils 9.0`                        | Used to create `~/pushbridge-temp`.                                                                               |
| `printf`     | Available | Bash builtin                               | Used for remote `$HOME` resolution.                                                                               |

### Core Inspection Utilities

| Tool             | Status    | Version               | Notes                                                                   |
| ---------------- | --------- | --------------------- | ----------------------------------------------------------------------- |
| `cat`            | Available | `GNU coreutils 9.0`   | Used for `/proc/version`, `/proc/asound/*`, and other proc/sysfs files. |
| `ls`             | Available | `GNU coreutils 9.0`   | Used for `/dev/snd`, `/lib/modules`, and filesystem inspection.         |
| `find`           | Available | `GNU findutils 4.9.0` | Used to search for modules, kernel artifacts, and `Module.symvers`.     |
| `grep` / `egrep` | Available | `GNU grep 3.7`        | Used for filtering `dmesg`, modules, and proc output.                   |
| `awk`            | Available | `GNU Awk 5.1.1`       | Used in installer checksum and ALSA-card-index commands.                |
| `sed`            | Available | `GNU sed 4.8`         | Used during USB descriptor inspection.                                  |
| `head` / `tail`  | Available | `GNU coreutils 9.0`   | Used to bound large command output.                                     |
| `wc`             | Available | `GNU coreutils 9.0`   | Used while comparing `dmesg` output windows.                            |
| `sha256sum`      | Available | `GNU coreutils 9.0`   | Used by the installer to compare local and remote module checksums.     |

### Kernel And Module Utilities

| Tool                                               | Status    | Version             | Notes                                                                             |
| -------------------------------------------------- | --------- | ------------------- | --------------------------------------------------------------------------------- |
| `uname`                                            | Available | `GNU coreutils 9.0` | Used to confirm `5.15.48-intel-pk-preempt-rt`.                                    |
| `dmesg`                                            | Available | `util-linux 2.37.4` | Primary source for `insmod` failures, oops traces, and USB events.                |
| `lsmod`                                            | Available | `kmod 29`           | `lsmod --version` only printed usage, but `/bin/lsmod` is present and functional. |
| `insmod`                                           | Available | `kmod 29`           | `/sbin/insmod` used to load out-of-tree `.ko` files.                              |
| `rmmod`                                            | Available | `kmod 29`           | `/sbin/rmmod` used to unload modules by module name, when refcounts allowed it.   |
| `modinfo`                                          | Available | `kmod 29`           | `/sbin/modinfo` used to inspect shipped and built module metadata.                |
| `/proc/modules`                                    | Available | N/A                 | Used as a loaded-module inventory.                                                |
| `/lib/modules/$(uname -r)/modules.builtin`         | Available | N/A                 | Useful for built-in module inference.                                             |
| `/lib/modules/$(uname -r)/modules.builtin.modinfo` | Available | N/A                 | Useful for built-in module metadata when present.                                 |
| `/lib/modules/$(uname -r)/modules.dep`             | Available | N/A                 | Useful for shipped module dependency inference.                                   |
| `/lib/modules/$(uname -r)/modules.symbols`         | Available | N/A                 | Useful for exported-symbol/provider inference.                                    |

### ALSA And Audio Inspection

| Tool / Path            | Status    | Version            | Notes                                                                                                 |
| ---------------------- | --------- | ------------------ | ----------------------------------------------------------------------------------------------------- |
| `aplay`                | Available | `alsa-utils 1.2.6` | Used with `-l`, `-L`, and `--dump-hw-params`.                                                         |
| `arecord`              | Available | `alsa-utils 1.2.6` | Used with `-l`, `-L`, and `--dump-hw-params`.                                                         |
| `speaker-test`         | Available | `alsa-utils 1.2.6` | Observed from its runtime banner; `--version` was not supported. Used during ALSA plugin smoke tests. |
| `/proc/asound/cards`   | Available | N/A                | Primary card-registration check.                                                                      |
| `/proc/asound/devices` | Available | N/A                | Used to inspect ALSA kernel device state.                                                             |
| `/proc/asound/pcm`     | Available | N/A                | Used to inspect playback/capture PCM registration.                                                    |
| `/proc/asound/modules` | Available | N/A                | Used to map ALSA cards to kernel modules.                                                             |
| `/dev/snd/*`           | Available | N/A                | Used to verify kernel-visible ALSA control and PCM nodes.                                             |

### USB And Hardware Inspection

| Tool       | Status              | Version             | Notes                                                           |
| ---------- | ------------------- | ------------------- | --------------------------------------------------------------- |
| `lsusb`    | Available           | `usbutils 014`      | Used to inspect Digitakt USB IDs and descriptors.               |
| `lsusb -t` | Available           | `usbutils 014`      | Used to inspect USB topology and bound drivers.                 |
| `lsusb -v` | Available           | `usbutils 014`      | Used to inspect class-compliant and Overbridge USB descriptors. |
| `ip`       | Available           | `iproute2-5.17.0`   | Used for network address inspection.                            |
| `hostname` | Partially available | `GNU coreutils 9.0` | Worked, but `hostname -I` was not supported.                    |

### Debugging Tools

| Tool     | Status    | Version | Notes                                                                                                            |
| -------- | --------- | ------- | ---------------------------------------------------------------------------------------------------------------- |
| `strace` | Available | `5.16`  | Used to confirm Push Live opens kernel-visible `/dev/snd/*` nodes rather than relying only on ALSA plugin names. |

## Unavailable Or Absent

### Build Toolchain And Kernel Build Artifacts

| Tool / Artifact                 | Status                         | Notes                                                                                           |
| ------------------------------- | ------------------------------ | ----------------------------------------------------------------------------------------------- |
| `gcc` / native compiler on Push | Not available for this project | Push Standalone was treated as lacking a usable on-device compiler; builds are done externally. |
| Kernel headers/build tree       | Absent                         | `/lib/modules/5.15.48-intel-pk-preempt-rt/build` was not present.                               |
| Kernel source symlink/tree      | Absent                         | `/lib/modules/5.15.48-intel-pk-preempt-rt/source` was not present.                              |
| Target `Module.symvers`         | Not found                      | Searches under `/`, `/lib/modules`, `/usr/src`, `/boot`, `/opt`, and `/data` did not find it.   |
| `/proc/config.gz`               | Absent                         | No live kernel config was exposed there during prior inspection.                                |
| `/boot/config-*`                | Absent/not found               | No matching boot config was available in the expected locations.                                |

### Virtual ALSA Shortcut Modules

| Module      | Status | Notes                                                 |
| ----------- | ------ | ----------------------------------------------------- |
| `snd-aloop` | Absent | Not available as an easy virtual loopback-card route. |
| `snd-dummy` | Absent | Not available as an easy dummy-card route.            |

## Known Useful Command Bundles

### Kernel Identity

```sh
uname -a
cat /proc/version
cat /proc/sys/kernel/osrelease
```

### ALSA Card Visibility

```sh
cat /proc/asound/cards
cat /proc/asound/devices
cat /proc/asound/pcm
cat /proc/asound/modules 2>/dev/null
ls -l /dev/snd
aplay -l 2>/dev/null
arecord -l 2>/dev/null
```

### Module Loader Debugging

```sh
lsmod | grep snd_pushbridge || true
dmesg | grep -iE "pushbridge|module|relocation|vermagic|unknown symbol" | tail -120
modinfo /tmp/some-module.ko
insmod /tmp/some-module.ko index=1
rmmod module_name
```

Use the module name for `rmmod`, not the `.ko` filename. For example:

```sh
rmmod snd_pushbridge_digitakt
```

### USB Device Inspection

```sh
lsusb
lsusb -t
lsusb -v -d 1935:0b2b 2>/dev/null | head -360
lsusb -v -d 1935:102b 2>/dev/null | head -360
```

## Cautions

- `aplay -L` and `arecord -L` show logical PCM names; they do not prove a
  kernel-visible hardware card exists.
- `aplay -l`, `arecord -l`, `/proc/asound/cards`, `/proc/asound/pcm`, and
  `/dev/snd/*` are the better checks for Push Live audio-device visibility.
- A module can load and register an ALSA card but still crash Push when the UI
  starts the PCM runtime. Treat registration as the first gate, not the end of
  validation.
- If `rmmod` reports a PushBridge module is in use after a crash/oops, a reboot
  may be cleaner than trying to force the module state.
- Because the target kernel build tree, source tree, `.config`, and
  `Module.symvers` are absent on-device, external modules must be built from a
  prepared off-device kernel tree and compatible toolchain.
