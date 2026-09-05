# usbmon

## Compatibility

The tested Push ran `5.15.48-intel-pk-preempt-rt`. USB core exported
`usb_mon_register` and `usb_mon_deregister`, and all 59 imported usbmon symbols
were found in its export table. The prepared kernel enabled `CONFIG_USB_MON=y`.
Those core hooks must already be compiled in for stock usbmon to work; loading
a standalone module cannot add missing monitoring calls inside USB core.

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

References: [Linux usbmon documentation](https://www.kernel.org/doc/html/latest/usb/usbmon.html),
[Linux 5.15 usbmon source](https://github.com/torvalds/linux/tree/v5.15/drivers/usb/mon).
