import unittest
from obj_to_worldmesh import convert


class ConversionTests(unittest.TestCase):
    def test_triangle_winding_and_uv(self):
        mesh = convert("v 0 0 0\nv 1 0 0\nv 0 1 0\nvt 0 0\nvt 1 0\nvt 0 1\nf 1/1 2/2 3/3")
        self.assertEqual(mesh["indices"], [0, 2, 1])
        self.assertEqual(len(mesh["uv"]), 3)

    def test_invalid_indices_fail(self):
        with self.assertRaises(ValueError):
            convert("v 0 0 0\nf 1 2 999")

    def test_negative_indices(self):
        self.assertEqual(convert("v 0 0 0\nv 1 0 0\nv 0 1 0\nf -3 -2 -1")["indices"], [0, 2, 1])

    def test_forbidden_coordinate(self):
        with self.assertRaises(ValueError):
            convert("v nan 0 0")


if __name__ == "__main__":
    unittest.main()
