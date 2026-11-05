import tempfile
import unittest
from pathlib import Path

from excel_store import ExcelStore
from export_tools import export_workbook
from import_tools import import_workbook


class ImportWorkbookTests(unittest.TestCase):
    def test_import_is_append_only_and_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            source_store = ExcelStore(Path(directory) / "source.xlsx")
            source_store.add_row("Assets", {"category": "حاسوب", "serial_number": "IM-100"})
            workbook_path = Path(directory) / "transfer.xlsx"
            export_workbook(source_store, workbook_path)

            target_store = ExcelStore(Path(directory) / "target.xlsx")
            first = import_workbook(target_store, workbook_path)
            second = import_workbook(target_store, workbook_path)

            self.assertEqual(first["imported"], 1)
            self.assertGreaterEqual(first["skipped"], 0)
            self.assertEqual(second["imported"], 0)
            self.assertEqual(len(target_store.list_rows("Assets")), 1)
            self.assertEqual(target_store.list_rows("Assets")[0]["serial_number"], "IM-100")


if __name__ == "__main__":
    unittest.main()
