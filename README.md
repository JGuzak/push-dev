# push-dev

A collection of explorations and mods for the [Ableton Push 3 Standalone](https://www.ableton.com/en/push/)

- [push-dev](#push-dev)
  - [Abstract](#abstract)
  - [AbletonOS Docs](#abletonos-docs)
  - [First Time Setup](#first-time-setup)
    - [SSH Access](#ssh-access)
  - [Ableton OS Compiler Environment](#ableton-os-compiler-environment)
    - [Build Compiler Container](#build-compiler-container)
    - [Spinning Up Container](#spinning-up-container)
    - [Cross-Compiling](#cross-compiling)
      - [Kernel Modules (Drivers)](#kernel-modules-drivers)
      - [Manual Build (Inside Docker Container)](#manual-build-inside-docker-container)
      - [Programs (Coming Soon)](#programs-coming-soon)
  - [References](#references)

## Abstract

*DISCLAIMER: All of this is under construction. I'm still figuring things out and new releases of AbletonOS and/or Push sw can make any of this informantion obsolite. I'm just taking notes of everything I do in the hopes of helping others navigate and explore what is possible on Push Standalone.*

Information is up to date as of `Live 12.4.x`/`Push 2.x`

Reference for various terms used throught these documents:

| Term              | Abreviation |
| ----------------- | ----------- |
| Push 3 Standalone | P3SA        |

## AbletonOS Docs

- [Toolset](./docs/AbletonOS-toolset.md)
- [Max4Live](./docs/AbletonOS-max-env.md)

## First Time Setup

### SSH Access

This is an essential first step. You will need to ssh onto the linux machine running on Push to do any of the fun stuff outlined in this repo.

1. Generate an SSH key via `ssh-keygen` or similar
2. Start Push in standalone mode
3. Ensure your computer and push are both on the same network
4. Navigate to `http://push.local/ssh` in your web browser
5. Copy the content of your ssh public key file to your clipboard
6. Follow the instructions on the push ssh webpage.
7. SSH onto push with the following command: `ssh ableton@push.local`

Recommended SSH config entry to make life a bit easier when remoting in frequently.

```ssh
Host push
  HostName push.local
  User ableton
```

## Ableton OS Compiler Environment

[ableton-os-compiler](./ableton-os-compiler/) is a reverse engineered and containerized compiler environment targeting C/C++ programs for AbletonOS/Push3 Standalone. Newer OS updates may change things and break compatibility.

```bash
root@push:~# cat /proc/version
Linux version 5.15.48-intel-pk-preempt-rt (ci@abletonos-linux-noble-00) (x86_64-oe-linux-gcc (GCC) 11.5.0, GNU ld (GNU Binutils) 2.38.20220708) #1 SMP Tue Jun 21 16:59:08 UTC 2022
root@push:~# cat /proc/sys/kernel/osrelease
5.15.48-intel-pk-preempt-rt
root@push:~# uname -a
Linux push 5.15.48-intel-pk-preempt-rt #1 SMP Tue Jun 21 16:59:08 UTC 2022 x86_64 x86_64 x86_64 GNU/Linux
```

Add this repo as a submodule to your repo:

```bash
git submodule add <TODO FIX THIS> ./external/push-dev
```

Minimally expected project structure:

```yaml
├───build
├───external
│   └───push-dev
└───src
```

### Build Compiler Container

The Docker image builds a minimal prefixed kernel toolchain from GNU sources
and validates it against the Push kernel tool versions:

```text
x86_64-oe-linux-gcc (GCC) 11.5.0
GNU ld (GNU Binutils) 2.38.20220708
```

```bash
docker-compose -f <path to compose.yaml> build

# eg:
docker-compose -f ./external/push-dev/ableton-os-compiler/compose.yaml build
```

*Build and spin up container all in one command:*

```bash
docker-compose -f <path to compose.yaml> -p <name of your project>-compiler up -d --build
```

### Spinning Up Container

This container mounts a `src` and `build` path based on the location of the `docker-compose` command.

Navigate to the root of your project then When spinning up the container, the path of the executing command is expected t

```bash
docker-compose -f <path to compose.yaml> -p <name of your project>-compiler up -d

# eg:
docker-compose -f ./external/push-dev/ableton-os-compiler/compose.yaml -p test-compiler up -d
```

### Cross-Compiling

Once the container is up and running, it can be used to compile kernel modules or programs from the `src` directory.

#### Kernel Modules (Drivers)

```bash
docker exec <container name> build-kernel-modules

# eg:
docker exec test-compiler build-kernel-modules
```

#### Manual Build (Inside Docker Container)

```bash
docker exec -it <container ID> bash
```

The top-level `src` Makefile can build every driver, one driver by name, or
one driver through `DRIVER`:

```bash
make -C src
make -C src elektron
make -C src m8
make -C src DRIVER=m8
```

#### Programs (Coming Soon)

## References

A list of links I've found useful while exploring what sort of fun stuff can be added to push 3 standalone.

- [Ableton Forum: Unlock Push 3](https://forum.ableton.com/viewtopic.php?t=248249)
- [Yocto Kernel SDK](https://docs.yoctoproject.org/2.1/sdk-manual/sdk-manual.html)
- [Max Docs](https://docs.cycling74.com/)
