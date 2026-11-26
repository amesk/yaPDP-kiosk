import importlib.util
import json
import pathlib
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "configure-gdm-boot-mode.py"
SPEC = importlib.util.spec_from_file_location("gdm_boot_mode", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class GdmBootModeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.config = self.root / "boot-mode.json"
        self.gdm = self.root / "custom.conf"
        self.config.write_text(json.dumps({"kiosk_user": "yapdp-kiosk"}), encoding="utf-8")
        self.gdm.write_text(
            "[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=yapdp-kiosk\n"
            "TimedLoginEnable=False\n\n[security]\nDisallowTCP=true\n",
            encoding="utf-8",
        )

    def tearDown(self):
        self.temp.cleanup()

    def test_service_boot_disables_automatic_login(self):
        service = MODULE.configure_gdm(self.config, self.gdm, "quiet splash yapdp.service_mode=1")
        content = self.gdm.read_text(encoding="utf-8")
        self.assertTrue(service)
        self.assertIn("AutomaticLoginEnable=False", content)
        self.assertIn("AutomaticLogin=", content)
        self.assertIn("[security]\nDisallowTCP=true", content)

    def test_next_normal_boot_restores_kiosk_auto_login(self):
        MODULE.configure_gdm(self.config, self.gdm, "quiet splash yapdp.service_mode=1")
        service = MODULE.configure_gdm(self.config, self.gdm, "quiet splash")
        content = self.gdm.read_text(encoding="utf-8")
        self.assertFalse(service)
        self.assertIn("AutomaticLoginEnable=True", content)
        self.assertIn("AutomaticLogin=yapdp-kiosk", content)

    def test_repeated_normal_boot_configuration_is_idempotent(self):
        MODULE.configure_gdm(self.config, self.gdm, "quiet splash")
        first = self.gdm.read_text(encoding="utf-8")
        MODULE.configure_gdm(self.config, self.gdm, "quiet splash")
        self.assertEqual(self.gdm.read_text(encoding="utf-8"), first)


if __name__ == "__main__":
    unittest.main()
