#!/usr/bin/env python3
"""Generate short, pronounceable GRUB service passwords.

The fixed CVCV-D-CVC shape keeps the credential easy to read aloud while
secrets.choice supplies independent cryptographic randomness at every slot.
"""

from __future__ import annotations

import secrets

CONSONANTS = "BCDFGHJKLMNPRSTVWZ"
VOWELS = "AEUY"
DIGITS = "234679"
PASSWORD_PATTERN = (
    f"[{CONSONANTS}][{VOWELS}][{CONSONANTS}][{VOWELS}]"
    f"[{DIGITS}][{CONSONANTS}][{VOWELS}][{CONSONANTS}]"
)


def generate_password() -> str:
    """Return an eight-character CVCV-D-CVC password."""
    pools = (CONSONANTS, VOWELS, CONSONANTS, VOWELS,
             DIGITS, CONSONANTS, VOWELS, CONSONANTS)
    return "".join(secrets.choice(pool) for pool in pools)


if __name__ == "__main__":
    print(generate_password())
