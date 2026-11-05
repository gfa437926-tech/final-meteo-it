import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

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

    @patch("backup_tools.subprocess.run")
    @patch("backup_tools.shutil.which", return_value="pg_dump")
    def test_postgres_password_is_not_exposed_in_command_line(self, _which, run):
        run.return_value = SimpleNamespace(returncode=0, stderr="")
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "snapshot.dump"
            create_backup(SimpleNamespace(dsn="postgresql://inventory_app:ab12cd34@localhost:5432/meteo_inventory"), target)
            args, kwargs = run.call_args
            self.assertNotIn("ab12cd34", " ".join(args[0]))
            self.assertEqual(kwargs["env"]["PGPASSWORD"], "ab12cd34")
            self.assertEqual(kwargs["env"]["PGDATABASE"], "meteo_inventory")


if __name__ == "__main__":
    unittest.main()