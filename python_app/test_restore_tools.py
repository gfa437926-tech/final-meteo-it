import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from restore_tools import restore_backup

class RestoreToolsTests(unittest.TestCase):
    def test_excel_restore_preserves_current_copy(self):
        with tempfile.TemporaryDirectory() as d:
            target=Path(d)/"inventory.xlsx"; source=Path(d)/"backup.xlsx"
            target.write_bytes(b"current"); source.write_bytes(b"backup")
            result=restore_backup(SimpleNamespace(path=target),source)
            self.assertEqual(result,target)
            self.assertEqual(target.read_bytes(),b"backup")
            self.assertEqual(target.with_suffix(".xlsx.before-restore.bak").read_bytes(),b"current")

    def test_postgres_password_not_in_restore_command(self):
        with tempfile.TemporaryDirectory() as d:
            source=Path(d)/"backup.dump"; source.write_bytes(b"dump")
            with patch("restore_tools.shutil.which",return_value="pg_restore"), patch("restore_tools.subprocess.run") as run:
                run.return_value=SimpleNamespace(returncode=0,stderr="")
                restore_backup(SimpleNamespace(dsn="postgresql://inventory_app:secret123@localhost:5432/meteo_inventory"),source)
                args,kwargs=run.call_args
                self.assertNotIn("secret123"," ".join(args[0]))
                self.assertEqual(kwargs["env"]["PGPASSWORD"],"secret123")
                self.assertNotIn("secret123",args[0])

if __name__=="__main__": unittest.main()
