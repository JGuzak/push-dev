# usbmon on AbletonOS

This project builds stock Linux usbmon for diagnostic work on Ableton Push 3.
Build ownership moved here from Pushbridge; audio drivers and Overbridge-specific
experiments stay in Pushbridge. The build does not install or load anything.

**Experimental: repeated load/unload is not validated.** Binary capture worked
on Push, but subsequent reloads produced sysfs duplicate-name warnings. Do not
reload in an affected boot. See the lifecycle findings below before device use.

## Layout

```text
push-dev/
  .clang-format
  .devcontainer/
    compose.yaml
    devcontainer.json
    Dockerfile
  ableton-os-devcontainer/   existing shared toolchain and kernel image
  src/
    Makefile
  scripts/
    build.sh
    payload/
      install.sh
      uninstall.sh
      module-common.sh
  test/
    test_payload.py
  docs/
    modules/
      usbmon.md
  build/
    payload/
    package/
```

The source Makefile stages `/kernel/drivers/usb/mon` C files, headers, and its
upstream Kbuild into a temporary `build/.module-build.*/usbmon/` directory. It
selects `CONFIG_USB_MON=m` for that external build without editing the prepared
kernel configuration. There is no forked or reformatted copy of stock usbmon
in this repository. Project-owned C/H files under `src/`, when present, use the
same `.clang-format` as Pushbridge; upstream staged files are left unchanged.

## Build

From the push-dev root in Windows PowerShell, prepare the shared base image
if it is not already available:

```powershell
docker compose -f ableton-os-devcontainer\compose.yaml build ableton-os-devcontainer
```

Then build the diagnostic package:

```powershell
docker compose -f .devcontainer\compose.yaml run --rm push-dev-devcontainer bash -lc "cd /workspace && ./scripts/build.sh -v local"
```

VS Code's root `.devcontainer/devcontainer.json` builds the shared image during
initialization. Inside that container, use `./scripts/build.sh -v local`.
Do not use the host kernel or a WSL kernel for this build.

| Setting | Default / Meaning |
| --- | --- |
| `-v`, `--version` | `local`; package filename label, not a kernel release |
| `KDIR` | `/kernel` in the devcontainer; prepared full kernel source required |
| `ARCH`, `CROSS_COMPILE` | Supplied by the existing AbletonOS devcontainer |
| `PUSH_DEV_KCFLAGS` | `-fno-stack-protector`, preserving the extracted build behavior |

The old Pushbridge usbmon opt-in is no longer needed; this build always builds
usbmon. Invalid arguments or missing prerequisites fail before prior output is
replaced. Build warnings remain visible, including missing `Module.symvers`.

| Artifact | Contents |
| --- | --- |
| `build/payload/usbmon.ko` | Stock diagnostic module |
| `build/payload/modinfo.txt` | Module metadata and vermagic |
| `build/payload/kernel-provenance.txt` | Kernel commit/release, flags, configuration/source hashes |
| `build/payload/checksums.txt` | Payload checksums |
| `build/payload/*.sh` | Install, uninstall, and shared lifecycle helpers |
| `build/package/push-dev-local.tar.gz` | Module, metadata, provenance, scripts, and checksums |
| `build/package/checksums.txt` | Checksum for the most recently built tarball |

The successful build replaces `build/payload` and the requested version's
tarball. Other version tarballs are retained. Temporary sources are removed on
exit. The lifecycle scripts are executable and covered by the payload manifest.
No Live preference changes, templates, or boot hooks are included.
Preserve diagnostic artifacts before replacing them with another build.

## Install and Uninstall

On Push, from an extracted package directory, run as root:

```bash
bash ./install.sh
bash ./uninstall.sh
```

Both commands accept `-p <package-directory>` (also `-path` or `--path`);
the default is the script's directory. They select only the `*.ko` files in
that directory and identify modules using `modinfo`, not filenames.

| Operation | Behavior |
| --- | --- |
| Install | Validate checksums and kernel release for all selected modules, report running state/use counts/dependent modules, then load missing modules with `insmod` |
| Repeated install | Leave loaded modules unchanged; their running binary is not verified against the package |
| Install with `--reload` | Unload selected modules first, then load replacements; rejected before any unload if usbmon is already loaded |
| Uninstall | Unload selected modules in reverse filename order; retain package files and configuration |
| Busy module | Retry removal at most five times, one second apart; report failure without forced removal or killing readers |

Modules load in filename order; dependencies must already be available. The
scripts do not resolve dependencies, stop Live, create device nodes, or configure
automatic boot loading. Uninstall intentionally does not require matching
checksums or kernel release, so those checks cannot prevent recovery.
Failures return nonzero; already completed loads/unloads are not rolled back.

For usbmon, a fresh load is blocked when known residual sysfs paths exist.
After removal, residual paths also make uninstall return failure even if the
module itself unloaded. Do not reload in that boot. These guards cover the
observed failure, not every possible ABI or lifecycle defect. They do not repair
sysfs or make this experimental module safe; inspect kernel logs after device use.

### Script Validation

Run inside the root devcontainer:

```bash
python3 -m unittest discover -s test -v
```

The tests use mocked module commands and a temporary sysfs model, never real
kernel module operations. Coverage includes idempotence, root/argument checks,
checksum coverage, kernel mismatch, module names, load/unload order, bounded
busy retries, load failures, and usbmon reload/residue guards. Device lifecycle
validation remains outstanding; the scripts were not deployed to Push for these
tests.

Validation on 2026-09-05: all 15 mocked tests and Bash syntax checks passed.
The supported devcontainer build completed; payload and archive checksums,
packaged script help, and executable permissions were verified. The build still
reports the known missing-`Module.symvers` warnings described below.

## Compatibility

The tested Push ran `5.15.48-intel-pk-preempt-rt`. USB core exported
`usb_mon_register` and `usb_mon_deregister`, and all 59 imported usbmon symbols
were found in its export table. The prepared kernel enabled `CONFIG_USB_MON=y`.
Those core hooks must already be compiled in for stock usbmon to work; loading
a standalone module cannot add missing monitoring calls inside USB core.

The exact Ableton configuration and `Module.symvers` were unavailable during
these tests. Matching vermagic and exported symbol names are not proof of
structure-layout or runtime ABI compatibility. This extraction does not change
the kernel configuration, fix the lifecycle issue, or establish runtime safety.

## Capture and Overhead

usbmon provides host-side URB submission/completion events, statuses, lengths,
and payload data. These are not device ADC/DAC timestamps. The text interface
in the tested kernel captures at most 32 payload bytes per event. Binary
`MON_IOCX_GETX` can copy enough data to inspect headers beyond that prefix.

Readers enable monitoring for a USB bus. Filtering in userspace does not avoid
copying other devices' traffic on that bus. Use bounded captures and check ring
drop counts, kernel-captured length, and userspace copy length separately. ISO
records carry descriptor data before audio; captured bytes are not all audio.
Keep experimental period kprobes disabled when pairing this with Pushbridge's
performance monitor. Payload capture can include private audio or MIDI data.

## Recorded Device Validation

### Extraction Build Checks: 2026-09-05

- [x] Root devcontainer built and `./scripts/build.sh -v local` completed.
- [x] Bash syntax, payload checksums, and package checksum verified.
- [x] Tarball contains only usbmon, metadata, provenance, and checksums.
- [x] Vermagic matches `5.15.48-intel-pk-preempt-rt SMP mod_unload`.
- [x] Invalid version, missing version argument, and missing kernel sources
  rejected; the prior successful package remained unchanged.
- [x] Pushbridge rebuilt with the usbmon branch removed; its package excludes usbmon.
- [ ] Runtime lifecycle compatibility resolved. No deployment or device test
  was performed during extraction; the historical reload warning still applies.

The build emitted expected missing-`Module.symvers`/unresolved-symbol warnings
from the approximate kernel tree, plus Windows bind-mount clock-skew warnings.
These were left visible, not treated as evidence of runtime compatibility.

### Original Capture Tests

The original 2026-09-04 Pushbridge experiments found:

- A ten-second built-in-audio capture read 44,498 binary events, zero reported
  ring drops, and approximately 1,000 audio completions/s per direction.
- A ten-second Overbridge capture read 55,506 bus events, zero reported drops,
  approximately 285.7 audio completions/s per direction, and every header in
  each 24-block transfer. Per-block sample counters were continuous.
- The one-shot Python readers used about 6.8% and 7.9% of one CPU core. This
  excludes work charged to other kernel execution contexts and is not a total
  overhead measurement or a production-reader benchmark.

### Reload Lifecycle Failure

The first module removal cleared `/sys/module/usbmon` and debugfs entries, but
left device-parent directories under `/sys/devices/virtual/usbmon` and
`/sys/devices/pci0000:00/0000:00:14.0/usbmon`. Later loads emitted duplicate-name
call traces (`-EEXIST`) for these paths. `/sys/class/usbmon/usbmon1/dev` was absent.
A temporary root-only character node using the registered `/proc/devices` major
and bus-number minor allowed binary reading, but did not fix that lifecycle.

No further loads were attempted after identifying the warnings. The diagnostic
module and temporary node were removed, with residual sysfs state still present.
Reboot before further experiments and investigate configuration/ABI compatibility
and teardown before treating reload as safe. Do not remove sysfs objects by hand
or automate repeated load/unload as a workaround. Kernel taint persists after
unloading an unsigned out-of-tree module.

Historical evidence remains in the Pushbridge checkout under `logs/`:
`20260904-162733-pushbridge-log.tar.gz` (first smoke test),
`20260904-164316-pushbridge-log.tar.gz` (aborted reload attempt), and
`20260904-164423-pushbridge-log.tar.gz` (Overbridge capture and reload warnings).
The Overbridge-specific one-shot collectors are test artifacts, not portable
push-dev tools, and were not moved into this build.

References: [Linux usbmon documentation](https://www.kernel.org/doc/html/latest/usb/usbmon.html),
[Linux 5.15 usbmon source](https://github.com/torvalds/linux/tree/v5.15/drivers/usb/mon).
