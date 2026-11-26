#!/usr/bin/env python3
import re
import unittest

from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from generate_grub_password import PASSWORD_PATTERN, generate_password


class GrubPasswordTests(unittest.TestCase):
    def test_password_has_eight_readable_ascii_characters(self):
        for _ in range(1000):
            password = generate_password()
            self.assertEqual(len(password), 8)
            self.assertRegex(password, re.compile(rf"^{PASSWORD_PATTERN}$"))
            self.assertTrue(password.isascii())
            self.assertTrue(password.isalnum())

    def test_passwords_are_not_constant(self):
        self.assertGreater(len({generate_password() for _ in range(100)}), 95)


if __name__ == "__main__":
    unittest.main()
