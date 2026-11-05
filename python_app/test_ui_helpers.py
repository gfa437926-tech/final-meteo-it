import unittest
from main import filter_rows


class FilterRowsTests(unittest.TestCase):
    def test_search_is_case_insensitive_and_checks_all_fields(self):
        rows = [
            {"serial_number": "ABC-123", "office": "الفرع الرئيسي"},
            {"serial_number": "XYZ", "office": "المستودع"},
        ]
        self.assertEqual(filter_rows(rows, "abc"), [rows[0]])
        self.assertEqual(filter_rows(rows, "المستودع"), [rows[1]])

    def test_empty_search_returns_all_rows(self):
        rows = [{"id": "1"}, {"id": "2"}]
        self.assertEqual(filter_rows(rows, "  "), rows)


if __name__ == "__main__":
    unittest.main()
