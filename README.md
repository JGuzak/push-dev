# push-dev

A collection of explorations and mods for the [Ableton Push 3 Standalone](https://www.ableton.com/en/push/)

*DISCLAIMER: All of this is under construction. I'm still figuring things out so don't take any of this as fact yet. I'm just taking notes of everything I do in the hopes of helping others once I've sorted specific things out.*

- [push-dev](#push-dev)
	- [SSH Access](#ssh-access)
		- [First Time Setup](#first-time-setup)
	- [General Things](#general-things)
		- [Paths](#paths)
	- [Max4Live](#max4live)
	- [Installing Remote Scripts](#installing-remote-scripts)
	- [Installing Monome SerialOSC](#installing-monome-serialosc)
	- [Resources/Link Tree](#resourceslink-tree)

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

## General Things

Some useful base knowledge of the Push file system/linux distro.

### Paths

| Path                               | Descriptor                |
| ---------------------------------- | ------------------------- |
| `~/.local/share/Ableton`           | Ableton install directory |
| `~/.local/share/Max 8`             | Max 8 root directory      |
| `~/.config/Cycling '74/Max 8/Logs` | Max 8 Log directory       |

## Max4Live

## Installing Remote Scripts

1. SSH onto push
2. Navigate to `~/Music/Ableton/User Library`
3. Run the following commands:

```bash
mkdir "Remote Scripts"
cd Remote\ Scripts/
```

4. Copy your desired remote scripts from your computer onto push with the following command:

`scp -r <path to your User Library>/Remote Scripts/<Your remote script> push:~/Music/Ableton/User\ Library/Remote\ Scripts/`

## Installing Monome SerialOSC

*NOTE: Under construction*

https://monome.org/docs/serialosc/linux/

1. Draw a circle
2. Draw the rest of the owl
3. ???

Follow the remote scripts setup section outlined above and install [Ableton OSC](https://github.com/ideoforms/AbletonOSC) on push

## Resources/Link Tree

A list of links I've found useful while exploring what sort of fun stuff can be added to push 3 standalone.

- [Ableton Forum: Unlock Push 3](https://forum.ableton.com/viewtopic.php?t=248249)
- []()
