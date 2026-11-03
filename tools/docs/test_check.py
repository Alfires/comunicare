import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("checker", Path(__file__).with_name("check.py"))
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class Tests(unittest.TestCase):
    def test_anchors(self):
        self.assertEqual(checker.anchors("# Hi!\n# Hi!\n```\n# hidden\n```"), {"hi", "hi-1"})

    def test_local_links(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as directory:
            page = Path(directory) / "page.md"
            page.write_text("# Here\n[valid](#here)\n[external](https://invalid.example/)\n")
            self.assertEqual(checker.check_file(page), [])
            page.write_text("# Here\n[broken](missing.md)\n[anchor](#missing)\n")
            self.assertEqual(len(checker.check_file(page)), 2)


if __name__ == "__main__": unittest.main()
