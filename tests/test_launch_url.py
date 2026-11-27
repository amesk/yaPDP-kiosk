"""Integration tests for the launchUrl builder embedded in install/ubuntu-24.04.sh.

The builder is extracted from the installer heredoc, run against a throwaway
config.js, and checked against the expected launchUrl matrix for
IDLE_TIMEOUT, IDLE_REDIRECT, and PDP11_EXTRA_PARAMS.
"""

import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
INSTALLER = REPO_ROOT / "install" / "ubuntu-24.04.sh"
START_MARKER = 'python3 - "$KIOSK_DIR/config.js"'
HEREDOC_OPEN = "<<'PY'\n"
HEREDOC_CLOSE = "\nPY\n"
LAUNCH_LINE = re.compile(r"^[ \t]*launchUrl[ \t]*:[ \t]*(.*),[ \t]*$", re.MULTILINE)
ORIGINAL_CONFIG = 'window.KIOSK_CONFIG = {\n  launchUrl: "/old",\n};\n'


def extract_builder():
    script = INSTALLER.read_text(encoding="utf-8").replace("\r\n", "\n")
    start = script.index(START_MARKER)
    body_start = script.index(HEREDOC_OPEN, start) + len(HEREDOC_OPEN)
    body_end = script.index(HEREDOC_CLOSE, body_start)
    return script[body_start:body_end] + "\n"


class LaunchUrlBuilderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._tmp = tempfile.TemporaryDirectory(prefix="yapdp-launch-url-")
        cls.builder = Path(cls._tmp.name) / "build_launch_url.py"
        cls.builder.write_text(extract_builder(), encoding="utf-8")

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def run_builder(self, timeout, redirect, extra):
        config = Path(self._tmp.name) / "config.js"
        config.write_text(ORIGINAL_CONFIG, encoding="utf-8")
        completed = subprocess.run(
            [sys.executable, str(self.builder), str(config), str(timeout), redirect, extra],
            capture_output=True,
            text=True,
            check=False,
        )
        content = config.read_text(encoding="utf-8")
        return completed, content

    def read_launch_url(self, content):
        match = LAUNCH_LINE.search(content)
        self.assertIsNotNone(match, "launchUrl line is missing from config.js")
        return json.loads(match.group(1))

    def assert_launch_url(self, timeout, redirect, extra, expected):
        completed, content = self.run_builder(timeout, redirect, extra)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(self.read_launch_url(content), expected)
        self.assertIn("Configured yaPDP launch URL: " + expected, completed.stdout)
        return content

    def assert_rejected(self, timeout, redirect, extra):
        completed, content = self.run_builder(timeout, redirect, extra)
        self.assertNotEqual(completed.returncode, 0)
        self.assertTrue(completed.stderr.strip())
        self.assertEqual(content, ORIGINAL_CONFIG, "config.js must stay untouched on error")
        return completed.stderr

    def test_matrix_with_idle_hand_off_and_no_extra(self):
        self.assert_launch_url(
            180, "/", "",
            "/yapdp/pdp11.html?idle-timeout=180&idle-redirect=%2F",
        )

    def test_matrix_with_idle_hand_off_and_extra(self):
        self.assert_launch_url(
            180, "/", "fullscreen-button=off",
            "/yapdp/pdp11.html?idle-timeout=180&idle-redirect=%2F&fullscreen-button=off",
        )

    def test_matrix_without_idle_hand_off_and_no_extra(self):
        self.assert_launch_url(0, "/", "", "/yapdp/pdp11.html")

    def test_matrix_without_idle_hand_off_and_extra(self):
        self.assert_launch_url(
            0, "/", "fullscreen-button=off",
            "/yapdp/pdp11.html?fullscreen-button=off",
        )

    def test_leading_separators_are_stripped(self):
        self.assert_launch_url(
            180, "/", "?&fullscreen-button=off",
            "/yapdp/pdp11.html?idle-timeout=180&idle-redirect=%2F&fullscreen-button=off",
        )

    def test_extra_fragment_is_not_double_encoded(self):
        self.assert_launch_url(
            0, "/", "mode=demo&flag&percent=%2F",
            "/yapdp/pdp11.html?mode=demo&flag&percent=%2F",
        )

    def test_whitespace_around_extra_is_trimmed(self):
        self.assert_launch_url(
            0, "/", "  fullscreen-button=off  ",
            "/yapdp/pdp11.html?fullscreen-button=off",
        )

    def test_absolute_redirect_is_still_encoded(self):
        self.assert_launch_url(
            180, "https://museum.example/welcome?a=1&b=2", "fullscreen-button=off",
            "/yapdp/pdp11.html?idle-timeout=180&idle-redirect=https%3A%2F%2Fmuseum.example%2Fwelcome%3Fa%3D1%26b%3D2&fullscreen-button=off",
        )

    def test_extra_with_space_is_rejected(self):
        self.assert_rejected(180, "/", "a b")

    def test_extra_with_fragment_is_rejected(self):
        self.assert_rejected(180, "/", "a=1#x")

    def test_reserved_keys_are_rejected(self):
        stderr = self.assert_rejected(180, "/", "idle-timeout=5")
        self.assertIn("must not redefine", stderr)

    def test_onboarding_and_redirect_keys_are_rejected(self):
        self.assertIn("must not redefine", self.assert_rejected(0, "/", "onboarding=show"))
        self.assertIn("must not redefine", self.assert_rejected(0, "/", "idle-redirect=/x"))

    def test_overlong_extra_is_rejected(self):
        self.assert_rejected(0, "/", "a=" + "x" * 255)

    def test_malformed_percent_escape_is_rejected(self):
        self.assert_rejected(0, "/", "a=%zz")

    def test_separator_only_extra_sanitizes_to_no_parameters(self):
        self.assert_launch_url(0, "/", "&&", "/yapdp/pdp11.html")

    def test_empty_key_is_rejected(self):
        self.assert_rejected(0, "/", "=")
        self.assert_rejected(0, "/", "=1")

    def test_disallowed_characters_are_rejected(self):
        self.assertIn("URL query characters", self.assert_rejected(0, "/", "a=1|2"))
        self.assertIn("URL query characters", self.assert_rejected(0, "/", 'a=1"2'))


if __name__ == "__main__":
    unittest.main()
