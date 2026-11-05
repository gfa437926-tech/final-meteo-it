import unittest
from unittest.mock import MagicMock, patch
from postgres_store import PostgresStore

class AtomicAuditTests(unittest.TestCase):
    def make_store(self):
        store=object.__new__(PostgresStore)
        store.dsn="postgresql://test"
        conn=MagicMock()
        conn.__enter__.return_value=conn
        store._connect=lambda: conn
        return store,conn

    def test_add_and_audit_share_one_connection(self):
        store,conn=self.make_store()
        with patch("postgres_store.resolve_asset_reference"), patch("postgres_store.validate_record"):
            row=store.add_row("Assets",{"category":"PC","serial_number":"X-1"})
        self.assertEqual(conn.execute.call_count,2)
        self.assertIn("INSERT INTO \"assets\"",conn.execute.call_args_list[0].args[0])
        self.assertIn("INSERT INTO audit_logs",conn.execute.call_args_list[1].args[0])
        self.assertEqual(row["serial_number"],"X-1")

    def test_update_and_audit_share_one_connection(self):
        store,conn=self.make_store()
        with patch("postgres_store.resolve_asset_reference"), patch("postgres_store.validate_record"):
            store.update_row("Offices","office-1",{"name":"Main"})
        self.assertEqual(conn.execute.call_count,2)
        self.assertIn('UPDATE "offices"',conn.execute.call_args_list[0].args[0])
        self.assertIn("INSERT INTO audit_logs",conn.execute.call_args_list[1].args[0])

    def test_delete_and_audit_share_one_connection(self):
        store,conn=self.make_store()
        store.delete_row("Offices","office-1")
        self.assertEqual(conn.execute.call_count,2)
        self.assertIn('DELETE FROM "offices"',conn.execute.call_args_list[0].args[0])
        self.assertIn("INSERT INTO audit_logs",conn.execute.call_args_list[1].args[0])

if __name__=="__main__":
    unittest.main()
