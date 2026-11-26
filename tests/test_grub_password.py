#!/usr/bin/env python3
import re
import unittest

from pathlib import Path
import importlib.util

MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "generate-grub-password.py"
SPEC = importlib.util.spec_from_file_location("generate_grub_password", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
PASSWORD_PATTERN = MODULE.PASSWORD_PATTERN
generate_password = MODULE.generate_password


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
