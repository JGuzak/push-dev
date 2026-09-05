KDIR ?= /kernel
ARCH ?= x86_64
CROSS_COMPILE ?=
PUSH_DEV_KCFLAGS ?= -fno-stack-protector
USBMON_WORK_DIR ?=

.PHONY: all modules prepare

all: modules

# The build script supplies a fresh temporary directory. Keep upstream sources
# and Kbuild intact rather than maintaining a second copy of usbmon here.
prepare:
	@test -n "$(USBMON_WORK_DIR)" || { echo 'Use ./scripts/build.sh from the repo root' >&2; exit 1; }
	mkdir -p "$(USBMON_WORK_DIR)"
	cp "$(KDIR)/drivers/usb/mon/"*.c "$(KDIR)/drivers/usb/mon/"*.h "$(KDIR)/drivers/usb/mon/Makefile" "$(USBMON_WORK_DIR)/"

modules: prepare
	$(MAKE) -C "$(KDIR)" M="$(USBMON_WORK_DIR)" ARCH="$(ARCH)" CROSS_COMPILE="$(CROSS_COMPILE)" CONFIG_USB_MON=m KCFLAGS="$(KCFLAGS) $(PUSH_DEV_KCFLAGS)" modules
