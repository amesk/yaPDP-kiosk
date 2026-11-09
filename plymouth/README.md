# yaPDP PDP-11/70 Plymouth theme

A lightweight script-plugin Plymouth theme for the Ubuntu 24.04 museum kiosk. It shows a stylized PDP-11/70 front panel, animated status lamps, and boot-progress indicators.

## Install

From a checkout of this repository:

```bash
sudo bash plymouth/install.sh
```

The installer renders the vector artwork to PNG using `librsvg2-bin`, installs the theme under `/usr/share/plymouth/themes/yapdp-plymouth`, selects it with Ubuntu's `update-alternatives`, and rebuilds initramfs.

This is intentionally a separate step from the kiosk installer: changing initramfs changes the machine's boot splash, so it should be tested on the target hardware/VM before being made part of unattended provisioning.

## Preview

Plymouth takes over the display when showing a splash. The safest preview is a disposable VM or a second virtual terminal. On a test machine, switch to a free TTY (for example Ctrl+Alt+F3), log in, then run:

```bash
sudo plymouthd --no-daemon --debug --tty=$(tty)
sudo plymouth show-splash
```

Switch back to the graphical session to inspect it. To stop the preview:

```bash
sudo plymouth quit
```

A preview from a graphical terminal may not accurately reproduce the early-boot framebuffer/KMS environment.

## Roll back

```bash
sudo bash plymouth/uninstall.sh
```

The installer records the previously selected theme on first installation. The rollback script restores it and rebuilds initramfs. If no previous theme was recorded, select one manually with:

```bash
sudo update-alternatives --config default.plymouth
sudo update-initramfs -u
```

## Notes

- Artwork is authored as SVG and converted to PNG during installation; Plymouth's script plugin consumes the PNG assets.
- The animation is deliberately modest and uses Plymouth's refresh and boot-progress callbacks.
- This theme does not depend on GNOME, Chrome, nginx, or the yaPDP application.
- The theme has not yet been validated on the museum's actual 35-inch display or on a physical boot. Verify resolution, KMS hand-off, and firmware splash behavior on the target machine.
