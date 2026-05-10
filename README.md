# push-dev

A collection of explorations and mods for the [Ableton Push 3 Standalone](https://www.ableton.com/en/push/).

- [push-dev](#push-dev)
  - [Abstract](#abstract)
  - [AbletonOS Docs](#abletonos-docs)
  - [First Time Setup](#first-time-setup)
    - [SSH Access](#ssh-access)
  - [Ableton OS Compiler Environment](#ableton-os-compiler-environment)
    - [Include In A Project](#include-in-a-project)
    - [Start The Compiler](#start-the-compiler)
    - [Build Kernel Modules](#build-kernel-modules)
  - [References](#references)

## Abstract

*DISCLAIMER: All of this is under construction. I'm still figuring things out and new releases of AbletonOS and/or Push software can make any of this information obsolete. I'm taking notes in the hope of helping others navigate and explore what is possible on Push Standalone.*

Information is up to date as of `Live 12.4.x` / `Push 2.x`.

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

## Ableton OS Compiler Environment

[ableton-os-compiler](./ableton-os-compiler/) is a reverse engineered and containerized compiler environment targeting C/C++ programs for AbletonOS / Push 3 Standalone. Newer OS updates may change things and break compatibility.

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

Create a project-root `.env` file that tells the compiler where your module
sources live and where build output should be written:

```dotenv
CONTEXT=./external/push-dev/ableton-os-compiler
SRC=./src
OUT=./build
```

The paths are resolved from the consuming project root, not from the
`push-dev` submodule. This is the same inclusion pattern used by PushBridge.

### Start The Compiler

Run Docker Compose from the consuming project root:

```bash
docker compose \
  --project-directory . \
  --env-file ./.env \
  -p <your-project>-compiler \
  -f ./external/push-dev/ableton-os-compiler/compose.yaml \
  up -d --build ableton-os-compiler
```

The Docker image builds a minimal prefixed kernel toolchain from GNU sources
and validates it against the Push kernel tool versions:

```text
x86_64-oe-linux-gcc (GCC) 11.5.0
GNU ld (GNU Binutils) 2.38.20220708
```

### Build Kernel Modules

Once the container is running, build modules with:

```bash
docker compose \
  --project-directory . \
  --env-file ./.env \
  -p <your-project>-compiler \
  -f ./external/push-dev/ableton-os-compiler/compose.yaml \
  exec ableton-os-compiler build-kernel-modules
```

The module build script copies `SRC` into an internal temporary build directory
before running `make`, then copies `.ko`, `Module.symvers`, and `modules.order`
outputs into `OUT`.

To open a shell inside the compiler:

```bash
docker compose \
  --project-directory . \
  --env-file ./.env \
  -p <your-project>-compiler \
  -f ./external/push-dev/ableton-os-compiler/compose.yaml \
  exec ableton-os-compiler bash
```

## References

A list of links I've found useful while exploring what sort of work can be done on Push 3 Standalone.

- [Ableton Forum: Unlock Push 3](https://forum.ableton.com/viewtopic.php?t=248249)
- [Yocto Kernel SDK](https://docs.yoctoproject.org/2.1/sdk-manual/sdk-manual.html)
- [Max Docs](https://docs.cycling74.com/)
