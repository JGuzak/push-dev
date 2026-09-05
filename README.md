<h1>Push 3 Standalone Development Tools</h1>

A collection of explorations and tools for the [Ableton Push 3 Standalone](https://www.ableton.com/en/push/).

- [Disclaimer](#disclaimer)
- [Abstract](#abstract)
- [Paths](#paths)
- [First Time Setup](#first-time-setup)
  - [SSH Access](#ssh-access)
- [Dev Kernel Modules and Programs](#dev-kernel-modules-and-programs)
- [Preferences.cfg Reverse Engineering](#preferencescfg-reverse-engineering)
  - [Push 3 Standalone Preferences Sideload Check](#push-3-standalone-preferences-sideload-check)
- [References](#references)

## Disclaimer

All of this is under construction. I'm still figuring things out and new releases of AbletonOS and/or Push software can make any of this information obsolete.

I'm taking notes and sharing tools in the hope of helping others navigate and explore what is possible on Push Standalone.

## Abstract

Information is up to date as of `Live 12.4.2` / `Push 2.4.2`.

Reference for various terms used throughout these documents:

| Term              | Abbreviation |
| ----------------- | ------------ |
| Push 3 Standalone | P3SA         |

## Paths

SSH authorized keys path: `/data/settings/ssh/authorized_keys`

- [Toolset](./docs/AbletonOS-toolset.md)
- [Max4Live](./docs/AbletonOS-max-env.md)

## First Time Setup

### SSH Access

This is an essential first step. You will need to ssh onto the Linux machine running on Push to do any of the work outlined in this repo.

1. Generate an SSH key via `ssh-keygen` or similar.
2. Start Push in standalone mode.
3. Ensure your computer and Push are both on the same network.
4. Navigate to `http://push.local/ssh` in your web browser.
5. Copy the content of your SSH public key file to your clipboard.
6. Follow the instructions on the Push SSH webpage.
7. SSH onto Push with `ssh ableton@push.local`.

Recommended SSH config entry:

```ssh
Host push
  HostName push.local
  User ableton
```

## Dev Kernel Modules and Programs

AbletonOS doesn't come with a number of useful tools from the linux kernel. These are modules that were built via the cross-compiler dev container and can be loaded onto Push 3 Standalone.

- [usbmon](docs/modules/usbmon.md)

## Preferences.cfg Reverse Engineering

Using [ImHex](https://imhex.werwolv.net/) to decode binary preferences data.

Vanila config files are saved per version of Live under `/reverse-engineering/preferences-config/` for tracking changes over time.

| Platform          | Path                                                                                 |
| ----------------- | ------------------------------------------------------------------------------------ |
| Windows           | C:\Users\<user name>\AppData\Roaming\Ableton\Live 12.4.3\Preferences\Preferences.cfg |
| Push 3 Standalone | /data/.config/Ableton/Live <version>/Preferences.cfg                                 |
| MacOS             |                                                                                      |

### Push 3 Standalone Preferences Sideload Check

Before editing arbitrary bytes, verify that Push Live will accept a sideloaded
`Preferences.cfg` that was already produced by Live. The helper script defaults
to dry-run discovery:

```powershell
.\scripts\push-preferences-sideload.ps1
```

Install one known-good captured preference file:

```powershell
.\scripts\push-preferences-sideload.ps1 -LocalCfg .\preferences\p3sa\in-m-1-2-enabled.cfg
```

Restart Live or reboot Push, then verify that Live did not rewrite or reject the
file:

```powershell
.\scripts\push-preferences-sideload.ps1 -VerifyOnly -LocalCfg .\preferences\p3sa\in-m-1-2-enabled.cfg
```

If the remote SHA-256 still matches the local SHA-256 after restart, the
sideload path is viable. The script creates a timestamped backup next to the
remote `Preferences.cfg` before replacing it.

If Live rejects a broken file, remove it and power cycle Push so Live regenerates defaults:

```powershell
.\scripts\push-preferences-sideload.ps1 -DeleteRemotePreferences
```

## References

A list of links I've found useful while exploring what sort of work can be done on Push 3 Standalone.

- [Ableton Forum: Unlock Push 3](https://forum.ableton.com/viewtopic.php?t=248249)
- [Yocto Kernel SDK](https://docs.yoctoproject.org/2.1/sdk-manual/sdk-manual.html)
- [Max Docs](https://docs.cycling74.com/)
