import tempfile
import unittest
from pathlib import Path

from excel_store import ExcelStore

class ExcelStoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = ExcelStore(Path(self.temp.name) / "test.xlsx")

    def tearDown(self):
        self.temp.cleanup()

    def test_workbook_has_expected_sheets(self):
        self.assertEqual(set(self.store.list_rows("Assets")), set())

    def test_add_and_list_asset(self):
        row = self.store.add_row("Assets", {"category": "حاسوب", "serial_number": " ab-123 ", "status": "متاح"})
        self.assertEqual(row["serial_number"], "AB-123")
        self.assertEqual(self.store.list_rows("Assets")[0]["category"], "حاسوب")

    def test_duplicate_serial_is_rejected(self):
        self.store.add_row("Assets", {"category": "حاسوب", "serial_number": "SN-1"})
        with self.assertRaises(ValueError):
            self.store.add_row("Assets", {"category": "حاسوب", "serial_number": " sn-1 "})

    def test_asset_delete_is_disabled(self):
        row = self.store.add_row("Assets", {"category": "حاسوب", "serial_number": "SN-2"})
        with self.assertRaises(ValueError):
            self.store.delete_row("Assets", row["id"])


    def test_required_asset_category_is_enforced(self):
        with self.assertRaisesRegex(ValueError, "فئة الأصل"):
            self.store.add_row("Assets", {"serial_number": "SN-3"})

if __name__ == "__main__":
    unittest.main()
