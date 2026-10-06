#!/usr/bin/env python3
"""Tests for the version scheme (python3 scripts/test_version.py)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import version  # noqa: E402


class VersionSchemeTests(unittest.TestCase):
    def test_android_code_follows_version_build_and_internal(self):
        self.assertEqual(version.android_code("3.0", 0), 3000000)
        self.assertEqual(version.android_code("3.1", 4), 3010400)
        self.assertEqual(version.android_code("3.1", 4, 1), 3010401)

    def test_android_code_always_goes_up(self):
        order = [("3.0", 1, 0), ("3.0", 1, 1), ("3.0", 1, 2), ("3.0", 2, 0), ("3.1", 1, 0), ("4.0", 1, 0)]
        codes = [version.android_code(v, b, i) for v, b, i in order]
        self.assertEqual(codes, sorted(codes))
        self.assertEqual(len(set(codes)), len(codes))
        self.assertGreater(codes[0], 5, "above the last Google Play upload (0.5 (5))")

    def test_names_and_build_text(self):
        self.assertEqual(version.build_text(4), "4")
        self.assertEqual(version.build_text(4, 1), "4.1")
        self.assertEqual(version.android_name("3.1", 4), "3.1 (4)")
        self.assertEqual(version.android_name("3.1", 4, 1), "3.1 (4.1)")

    def test_digits_must_stay_small(self):
        with self.assertRaises(ValueError):
            version.android_code("3.1", 100)

    def test_project_files_agree(self):
        self.assertEqual(version.problems(), [])


if __name__ == "__main__":
    unittest.main()
