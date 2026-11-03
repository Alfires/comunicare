import unittest
from privacy import violations


class Tests(unittest.TestCase):
    def test_runtime_and_key_detection(self):
        marker = b"-----BEGIN " + b"PRIVATE KEY-----"
        self.assertTrue(violations("sample.txt", marker + b"\nsecret"))
        self.assertTrue(violations("user.key", b"bytes"))
        self.assertTrue(violations("asset_cache/blobs/a", b"bytes"))
        self.assertEqual(violations("docs/example.md", b"Use a public key"), [])
        self.assertEqual(violations("tests/profile/fixture.gd", b"Crypto.new().generate_rsa(2048)"), [])
        self.assertEqual(violations("tests/asset_cache/run.py", b"fixture"), [])


if __name__ == "__main__": unittest.main()
