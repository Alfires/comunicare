import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("inventory", Path(__file__).with_name("inventory.py"))
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)


class Tests(unittest.TestCase):
    def test_declarations(self):
        source = '''extends Node
# func fake():
var text = "func fake():"
var doc = """signal fake
func nope():"""
signal changed(value: String)
@rpc("any_peer")
func apply(
    value: Dictionary = {"key": "value"}
) -> bool:
    return true
class Nested:
    func _private(a: int = 2):
        pass
'''
        found = inventory.declarations(source)
        self.assertEqual([item["name"] for item in found], ["changed", "apply", "Nested", "_private"])
        self.assertIn("-> bool", found[1]["signature"])
        self.assertEqual(found[-1]["visibility"], "private")


if __name__ == "__main__": unittest.main()
