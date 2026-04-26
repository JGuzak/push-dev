# Max Environment on Push Standalone

Some useful base knowledge of the Push file system/linux distro.

- [Max Environment on Push Standalone](#max-environment-on-push-standalone)
  - [Paths](#paths)
  - [Logs](#logs)

## Paths

| Path                                                 | Descriptor                | Platform |
| ---------------------------------------------------- | ------------------------- | -------- |
| `C:\ProgramData\Ableton`                             | Ableton install directory | Windows  |
| `~/.local/share/Ableton`                             | Ableton install directory | P3       |
| `~/.local/share/Max 8`                               | Max 8 root directory      | P3       |
| `C:/Users/<username>/AppData/Cycling '74/Max 8/Logs` | Max 8 Log directory       | Windows  |
| `~/Library/Logs/`                                    | Max Log directory         | MacOS    |
| `~/.config/Cycling '74/Max 8/Logs`                   | Max 8 Log directory       | P3       |

## Logs

Super useful when developing or debugging M4L devices on Push. Often M4L devices will work on the computer but break when on P3.
This can happen even when not using externals so being able to tail logs while testing out M4L devices is quite useful.

1. SSH onto push
2. Run `tail -n 100 ~/.config/Cycling '74/Max 8/Logs/Max.log`
