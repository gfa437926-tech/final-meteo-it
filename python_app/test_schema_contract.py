import unittest
from pathlib import Path


class PostgresSchemaContractTests(unittest.TestCase):
    def test_custody_and_maintenance_reference_existing_assets(self):
        sql = (Path(__file__).parent / "schema_postgres.sql").read_text(encoding="utf-8")
        self.assertIn("fk_custody_asset", sql)
        self.assertIn("fk_maintenance_asset", sql)
        self.assertGreaterEqual(sql.count("REFERENCES assets(id) ON DELETE RESTRICT NOT VALID"), 2)

    def test_asset_serial_has_case_insensitive_unique_index(self):
        sql = (Path(__file__).parent / "schema_postgres.sql").read_text(encoding="utf-8")
        self.assertIn("upper(trim(serial_number))", sql)


if __name__ == "__main__":
    unittest.main()