#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location("launcher", Path(__file__).with_name("launch.py"))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class LauncherTests(unittest.TestCase):
    def test_clients_never_share_account_or_settings_roots(self):
        a = MODULE.client_environment("/tmp/opencode/fixture", 0, {"DISPLAY": ":0"})
        b = MODULE.client_environment("/tmp/opencode/fixture", 1, {"DISPLAY": ":0"})
        for name in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
            self.assertNotEqual(a[name], b[name])
        self.assertEqual(a["DISPLAY"], ":0")

    def test_real_user_environment_is_not_modified(self):
        original = {"XDG_DATA_HOME": "/real/user", "DISPLAY": ":0"}
        MODULE.client_environment("/tmp/opencode/fixture", 0, original)
        self.assertEqual(original["XDG_DATA_HOME"], "/real/user")


if __name__ == "__main__":
    unittest.main()
