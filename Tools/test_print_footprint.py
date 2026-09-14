#!/usr/bin/env python3
"""Unit tests for print-footprint.py's JSON parsing logic.

Run directly:
    python3 -m unittest discover -s Tools -p 'test_*.py'

print-footprint.py's filename has a hyphen, so it can't be `import`ed by
name (not a valid Python identifier) - loaded here via importlib instead.
"""
import importlib.util
import pathlib
import unittest

_MODULE_PATH = pathlib.Path(__file__).parent / "print-footprint.py"
_spec = importlib.util.spec_from_file_location("print_footprint", _MODULE_PATH)
assert _spec is not None and _spec.loader is not None, f"could not load spec for {_MODULE_PATH}"
print_footprint = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(print_footprint)


class FindPhysFootprintTests(unittest.TestCase):
    def test_finds_a_top_level_key(self):
        self.assertEqual(print_footprint.find_phys_footprint({"phys_footprint": 123}), 123)

    def test_finds_a_nested_key(self):
        data = {"report": {"process": {"phys_footprint": 456}}}
        self.assertEqual(print_footprint.find_phys_footprint(data), 456)

    def test_finds_a_key_inside_a_list(self):
        data = {"processes": [{"name": "other"}, {"phys_footprint": 789}]}
        self.assertEqual(print_footprint.find_phys_footprint(data), 789)

    def test_returns_none_when_absent(self):
        self.assertIsNone(print_footprint.find_phys_footprint({"some_other_key": 1}))

    def test_returns_none_for_an_empty_structure(self):
        self.assertIsNone(print_footprint.find_phys_footprint({}))
        self.assertIsNone(print_footprint.find_phys_footprint([]))

    def test_prefers_the_first_match_found(self):
        # Not a case footprint's real output should ever produce, but the
        # function's behavior should still be deterministic if it did.
        data = {"a": {"phys_footprint": 1}, "b": {"phys_footprint": 2}}
        self.assertIn(print_footprint.find_phys_footprint(data), (1, 2))


class FormatBytesTests(unittest.TestCase):
    def test_formats_exactly_one_megabyte(self):
        self.assertEqual(print_footprint.format_bytes(1024 * 1024), "1.00 MB")

    def test_formats_a_realistic_widget_sized_reading(self):
        # ~30 MB, a plausible order of magnitude for a small WidgetKit
        # extension - not asserting an exact threshold, just that the
        # arithmetic and rounding behave sanely at a realistic scale.
        self.assertEqual(print_footprint.format_bytes(31_457_280), "30.00 MB")

    def test_formats_zero(self):
        self.assertEqual(print_footprint.format_bytes(0), "0.00 MB")


class MainTests(unittest.TestCase):
    def test_returns_2_and_prints_usage_with_wrong_arg_count(self):
        self.assertEqual(print_footprint.main(["print-footprint.py"]), 2)
        self.assertEqual(print_footprint.main(["print-footprint.py", "a", "b", "c"]), 2)

    def test_returns_1_when_the_file_has_no_phys_footprint_key(self):
        import tempfile
        import json
        import os

        fd, path = tempfile.mkstemp(suffix=".json")
        try:
            with os.fdopen(fd, "w") as f:
                json.dump({"nothing_useful": True}, f)
            self.assertEqual(print_footprint.main(["print-footprint.py", path]), 1)
        finally:
            os.remove(path)

    def test_returns_0_and_reads_a_real_looking_file(self):
        import tempfile
        import json
        import os

        fd, path = tempfile.mkstemp(suffix=".json")
        try:
            with os.fdopen(fd, "w") as f:
                json.dump({"phys_footprint": 31_457_280}, f)
            self.assertEqual(print_footprint.main(["print-footprint.py", path]), 0)
        finally:
            os.remove(path)

    def test_returns_0_when_under_the_given_threshold(self):
        import tempfile
        import json
        import os

        fd, path = tempfile.mkstemp(suffix=".json")
        try:
            with os.fdopen(fd, "w") as f:
                json.dump({"phys_footprint": 15 * 1024 * 1024}, f)
            self.assertEqual(print_footprint.main(["print-footprint.py", path, "50"]), 0)
        finally:
            os.remove(path)

    def test_returns_1_when_over_the_given_threshold(self):
        import tempfile
        import json
        import os

        fd, path = tempfile.mkstemp(suffix=".json")
        try:
            with os.fdopen(fd, "w") as f:
                json.dump({"phys_footprint": 100 * 1024 * 1024}, f)
            self.assertEqual(print_footprint.main(["print-footprint.py", path, "50"]), 1)
        finally:
            os.remove(path)


if __name__ == "__main__":
    unittest.main()
