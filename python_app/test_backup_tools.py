import tempfile
import unittest
from pathlib import Path

from backup_tools import create_backup
from excel_store import ExcelStore


class BackupToolsTests(unittest.TestCase):
    def test_excel_backup_is_a_separate_identical_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            source = ExcelStore(Path(directory) / "inventory.xlsx")
            source.add_row("Assets", {"category": "حاسوب", "serial_number": "BK-10"})
            destination = Path(directory) / "backups" / "snapshot.xlsx"
            create_backup(source, destination)
            self.assertTrue(destination.exists())
            self.assertEqual(destination.read_bytes(), source.path.read_bytes())
            self.assertEqual(source.list_rows("Assets")[0]["serial_number"], "BK-10")


if __name__ == "__main__":
    unittest.main()
