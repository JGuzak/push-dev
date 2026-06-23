# push-dev

A collection of explorations and mods for the [Ableton Push 3 Standalone](https://www.ableton.com/en/push/).

- [push-dev](#push-dev)
  - [Abstract](#abstract)
  - [AbletonOS Docs](#abletonos-docs)
  - [First Time Setup](#first-time-setup)
    - [SSH Access](#ssh-access)
  - [Ableton OS Devcontainer](#ableton-os-devcontainer)
    - [Include In A Project](#include-in-a-project)
    - [Start The Devcontainer](#start-the-devcontainer)
    - [Build Kernel Modules](#build-kernel-modules)
  - [References](#references)

## Abstract

*DISCLAIMER: All of this is under construction. I'm still figuring things out and new releases of AbletonOS and/or Push software can make any of this information obsolete. I'm taking notes in the hope of helping others navigate and explore what is possible on Push Standalone.*

Information is up to date as of `Live 12.4.2` / `Push 2.4.2`.

Reference for various terms used throughout these documents:

| Term              | Abbreviation |
| ----------------- | ------------ |
| Push 3 Standalone | P3SA         |

## AbletonOS Docs

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

## Ableton OS Devcontainer

[ableton-os-devcontainer](./ableton-os-devcontainer/) is a reverse engineered devcontainer targeting C/C++ programs and kernel modules for AbletonOS / Push 3 Standalone. Newer OS updates may change things and break compatibility, make sure to use the appropriate release tag for this project to ensure compatibility. If the latest tag doesn't match the latest AbletonOS version, please check [issues]() and if one does not exist for the target version, please create a new issue.

```bash
root@push:~# cat /proc/version
Linux version 5.15.48-intel-pk-preempt-rt (ci@abletonos-linux-noble-00) (x86_64-oe-linux-gcc (GCC) 11.5.0, GNU ld (GNU Binutils) 2.38.20220708) #1 SMP Tue Jun 21 16:59:08 UTC 2022
root@push:~# cat /proc/sys/kernel/osrelease
5.15.48-intel-pk-preempt-rt
root@push:~# uname -a
Linux push 5.15.48-intel-pk-preempt-rt #1 SMP Tue Jun 21 16:59:08 UTC 2022 x86_64 x86_64 x86_64 GNU/Linux
```

### Include In A Project

Add this repo as a submodule to your project:

```bash
git submodule add <push-dev repo url> ./external/push-dev
```

Use this project structure:

```text
.
|-- .env
|-- build/
|-- external/
|   -- push-dev/
|-- src/
```

See [project devcontainer template](./ableton-os-devcontainer/project-devcontainer-template/) to include and use this dev container base image in your projects. Key takeaways:

- The paths are resolved from the consuming project root, not from the
`push-dev` submodule.
- The reusable devcontainer config lives at `push-dev/ableton-os-devcontainer/.devcontainer/devcontainer.json` and should follow the pattern outlined in the [template project devcontainer file](./ableton-os-devcontainer/project-devcontainer-template/devcontainer.json).
- Consuming projects can either reference that config from their own `.devcontainer/devcontainer.json`, or run the compose file directly for one-off usage.

### Start The Devcontainer

In VS Code, use the command pallette to spin up the dev container from the project folder.

Or run Docker Compose from the consuming project root:

```bash
docker compose 
```

The Docker image builds a minimal prefixed kernel toolchain from GNU sources
and validates it against the Push kernel tool versions:

```text
x86_64-oe-linux-gcc (GCC) 11.5.0
GNU ld (GNU Binutils) 2.38.20220708
```

### Build Kernel Modules

Once the container is running, enter the dev container and follow the build proccess outlined in your project. Typically this would be a bash script, makefile, or similar mechanism.

## References

A list of links I've found useful while exploring what sort of work can be done on Push 3 Standalone.

- [Ableton Forum: Unlock Push 3](https://forum.ableton.com/viewtopic.php?t=248249)
- [Yocto Kernel SDK](https://docs.yoctoproject.org/2.1/sdk-manual/sdk-manual.html)
- [Max Docs](https://docs.cycling74.com/)
