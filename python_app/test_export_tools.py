import tempfile
import unittest
from pathlib import Path

from openpyxl import load_workbook

from excel_store import ExcelStore
from export_tools import export_workbook


class ExportWorkbookTests(unittest.TestCase):
    def test_exports_all_sheets_and_saved_records(self):
        with tempfile.TemporaryDirectory() as directory:
            store = ExcelStore(Path(directory) / "source.xlsx")
            store.add_row("Assets", {"category": "حاسوب", "serial_number": "EX-100"})
            target = Path(directory) / "backup.xlsx"
            export_workbook(store, target)
            workbook = load_workbook(target, read_only=True, data_only=True)
            try:
                self.assertIn("Assets", workbook.sheetnames)
                self.assertIn("AuditLog", workbook.sheetnames)
                self.assertEqual(workbook["Assets"]["B2"].value, "حاسوب")
                self.assertEqual(workbook["Assets"]["E2"].value, "EX-100")
            finally:
                workbook.close()


if __name__ == "__main__":
    unittest.main()
