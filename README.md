# push-dev

A collection of explorations and mods for the [Ableton Push 3 Standalone](https://www.ableton.com/en/push/)

- [push-dev](#push-dev)
  - [Abstract](#abstract)
  - [SSH Access](#ssh-access)
    - [First Time Setup](#first-time-setup)
  - [References](#references)

## Abstract

*DISCLAIMER: All of this is under construction. I'm still figuring things out and new releases of AbletonOS and/or Push sw can make any of this informantion obsolite. I'm just taking notes of everything I do in the hopes of helping others navigate and explore what is possible on Push Standalone.*

Reference for various terms used throught these documents:

| Term            | Abreviation |
| --------------- | ----------- |
| Push Standalone | Push SA     |
| AbletonOS       | AOS         |

## SSH Access

This is an essential first step. You will need to ssh onto the linux machine running on Push to do any of the fun stuff outlined in this repo.

### First Time Setup

For a detailed guide, follow the instructions from this Ableton forum post [Unlock Push 3](https://forum.ableton.com/viewtopic.php?t=248249)

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

## References

A list of links I've found useful while exploring what sort of fun stuff can be added to push 3 standalone.

- [Ableton Forum: Unlock Push 3](https://forum.ableton.com/viewtopic.php?t=248249)
- [Yocto Kernel]
- [ALSA Driver API](https://www.kernel.org/doc/html/v5.6/sound/kernel-api/alsa-driver-api.html#management-of-cards-and-devices)
- [Max Docs](https://docs.cycling74.com/)
