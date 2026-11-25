import importlib.util
import pathlib
import unittest
from unittest.mock import patch

HELPER = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "vt-switch-lock.py"
SPEC = importlib.util.spec_from_file_location("vt_switch_lock", HELPER)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class VirtualTerminalLockTests(unittest.TestCase):
    @patch.object(MODULE.os, "close")
    @patch.object(MODULE.fcntl, "ioctl")
    @patch.object(MODULE.os, "open", return_value=17)
    def test_lock_uses_vt_lockswitch(self, open_device, ioctl, close_device):
        self.assertEqual(MODULE.main(["lock"]), 0)
        open_device.assert_called_once_with(MODULE.DEVICE, MODULE.os.O_RDWR | MODULE.os.O_NOCTTY)
        ioctl.assert_called_once_with(17, MODULE.VT_LOCKSWITCH, 0)
        close_device.assert_called_once_with(17)

    @patch.object(MODULE.os, "close")
    @patch.object(MODULE.fcntl, "ioctl")
    @patch.object(MODULE.os, "open", return_value=17)
    def test_unlock_uses_vt_unlockswitch(self, open_device, ioctl, close_device):
        self.assertEqual(MODULE.main(["unlock"]), 0)
        ioctl.assert_called_once_with(17, MODULE.VT_UNLOCKSWITCH, 0)
        close_device.assert_called_once_with(17)

    @patch.object(MODULE.os, "open")
    def test_invalid_action_does_not_open_console(self, open_device):
        self.assertEqual(MODULE.main(["invalid"]), 2)
        open_device.assert_not_called()

    @patch.object(MODULE.os, "open", side_effect=PermissionError("denied"))
    def test_device_errors_are_reported(self, open_device):
        self.assertEqual(MODULE.main(["lock"]), 1)


if __name__ == "__main__":
    unittest.main()
