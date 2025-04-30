# push-dev

A collection of explorations and mods for the [Ableton Push 3 Standalone](https://www.ableton.com/en/push/)

- [push-dev](#push-dev)
	- [Abstract](#abstract)
	- [SSH Access](#ssh-access)
		- [First Time Setup](#first-time-setup)
	- [General Things](#general-things)
		- [Paths](#paths)
		- [Useful Installs](#useful-installs)
	- [Max4Live](#max4live)
		- [Tail Logs](#tail-logs)
	- [Installing Remote Scripts](#installing-remote-scripts)
	- [Installing Monome SerialOSC](#installing-monome-serialosc)
	- [Resources/Link Tree](#resourceslink-tree)

## Abstract

*DISCLAIMER: All of this is under construction. I'm still figuring things out so don't take any of this as fact yet. I'm just taking notes of everything I do in the hopes of helping others once I've sorted specific things out.*

Push Standalone with be referred to as P3 throughout this document.

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

| Path                                                 | Descriptor                | Platform |
| ---------------------------------------------------- | ------------------------- | -------- |
| `C:\ProgramData\Ableton`                             | Ableton install directory | Windows  |
| `~/.local/share/Ableton`                             | Ableton install directory | P3       |
| `~/.local/share/Max 8`                               | Max 8 root directory      | P3       |
| `C:/Users/<username>/AppData/Cycling '74/Max 8/Logs` | Max 8 Log directory       | Windows  |
| `~/Library/Logs/`                                    | Max Log directory         | MacOS    |
| `~/.config/Cycling '74/Max 8/Logs`                   | Max 8 Log directory       | P3       |

### Useful Installs

A list of useful tools to install on P3.

- 

## Max4Live

### Tail Logs

Super useful when developing or debugging M4L devices on Push. Often M4L devices will work on the computer but break when on P3.
This can happen even when not using externals so being able to tail logs while testing out M4L devices is quite useful.

1. SSH onto push
2. Run `tail -n 100 ~/.config/Cycling '74/Max 8/Logs/Max.log`

## Installing Remote Scripts

As someone who isn't super deep on using custom remote scripts, I'm not sure what will and won't work on P3 vs the computer. I assume anything that requires additional python dependencies will need some extra TLC to get them working on P3.

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

Will be making this a simple install script `/scripts/push/install-serialosc.sh` at some point.

https://monome.org/docs/serialosc/linux/

1. Draw a circle
2. Draw the rest of the owl
3. ???

Follow the remote scripts setup section outlined above and install [AbletonOSC remote script](https://github.com/ideoforms/AbletonOSC) on push

## Resources/Link Tree

A list of links I've found useful while exploring what sort of fun stuff can be added to push 3 standalone.

- [Ableton Forum: Unlock Push 3](https://forum.ableton.com/viewtopic.php?t=248249)
- [Max Docs](https://docs.cycling74.com/)
