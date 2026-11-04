#!/usr/bin/env python3
"""Green runner integrity checks; not a federation implementation."""
import importlib.util
from pathlib import Path
import subprocess
import unittest

SPEC = importlib.util.spec_from_file_location("federation_runner", Path(__file__).with_name("run.py"))
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class RunnerTests(unittest.TestCase):
    def test_red_assertions_are_exit_one(self):
        process = subprocess.CompletedProcess([], 1, "FAIL: missing service\nFederation acceptance: 0 passed, 6 failed", "")
        self.assertEqual(RUNNER.result_code(process), 1)

    def test_engine_errors_and_empty_execution_are_not_red_success(self):
        for process in [subprocess.CompletedProcess([], 0, "", ""),
                        subprocess.CompletedProcess([], 1, "Federation acceptance:", "SCRIPT ERROR: bad script"),
                        subprocess.CompletedProcess([], -11, "Federation acceptance:", "")]:
            self.assertEqual(RUNNER.result_code(process), 2)

    def test_success_requires_suite_completion(self):
        self.assertEqual(RUNNER.result_code(subprocess.CompletedProcess([], 0, "Federation acceptance: 1 passed, 0 failed", "")), 0)


if __name__ == "__main__":
    unittest.main()
