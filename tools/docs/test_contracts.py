from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from contracts import missing


class Tests(unittest.TestCase):
    def test_coverage(self):
        inventory = {"scripts/a.gd": [{"kind": "func", "visibility": "public", "name": "run"},
                                       {"kind": "func", "visibility": "private", "name": "_helper"}]}
        self.assertTrue(missing(inventory, ""))
        self.assertTrue(missing(inventory, "<!-- module: scripts/a.gd -->\n" + "Description " * 20))
        self.assertEqual(missing(inventory, "<!-- module: scripts/a.gd -->\n`run` " + "Contract " * 30), [])


if __name__ == "__main__": unittest.main()
