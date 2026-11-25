#!/usr/bin/python3
"""Lock or unlock Linux virtual-terminal switching for the yaPDP kiosk."""

import fcntl
import os
import sys

VT_LOCKSWITCH = 0x560B
VT_UNLOCKSWITCH = 0x560C
DEVICE = "/dev/tty0"


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 1 or argv[0] not in ("lock", "unlock"):
        print(f"Usage: {sys.argv[0]} lock|unlock", file=sys.stderr)
        return 2

    operation = argv[0]
    request = VT_LOCKSWITCH if operation == "lock" else VT_UNLOCKSWITCH
    try:
        fd = os.open(DEVICE, os.O_RDWR | os.O_NOCTTY)
        try:
            fcntl.ioctl(fd, request, 0)
        finally:
            os.close(fd)
    except OSError as exc:
        print(f"Cannot {operation} virtual-terminal switching: {exc}", file=sys.stderr)
        return 1

    print(f"Virtual-terminal switching {operation}ed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
