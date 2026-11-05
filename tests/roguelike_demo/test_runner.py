"""Check runner failure classification without invoking Godot."""

import subprocess
import unittest

from run import result_code


class RunnerTests(unittest.TestCase):
    def result(self, code=0, stdout="Roguelike foundations: 1 passed, 0 failed", stderr=""):
        return subprocess.CompletedProcess([], code, stdout, stderr)

    def test_success_requires_completion_marker(self):
        self.assertEqual(result_code(self.result()), 0)
        self.assertEqual(result_code(self.result(stdout="")), 2)

    def test_assertion_failure(self):
        self.assertEqual(result_code(self.result(code=1)), 1)

    def test_engine_errors_override_assertion_status(self):
        for code in (0, 1):
            self.assertEqual(result_code(self.result(code=code, stderr="ERROR: broken")), 2)

    def test_crash_is_infrastructure_failure(self):
        self.assertEqual(result_code(self.result(code=-11)), 2)


if __name__ == "__main__":
    unittest.main()
