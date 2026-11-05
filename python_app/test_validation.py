import unittest
from validation import validate_record


class ValidationTests(unittest.TestCase):
    def test_required_fields(self):
        with self.assertRaises(ValueError):
            validate_record("Assets", {"serial_number": "S-1"})

    def test_non_negative_quantity(self):
        validate_record("SpareParts", {"name": "SSD", "quantity": "0"})
        with self.assertRaises(ValueError):
            validate_record("SpareParts", {"name": "SSD", "quantity": "-1"})
        with self.assertRaises(ValueError):
            validate_record("SpareParts", {"name": "SSD", "quantity": "2.5"})

    def test_currency_must_be_numeric(self):
        with self.assertRaises(ValueError):
            validate_record("Purchases", {"purchase_number": "P-1", "total_cost": "abc"})


if __name__ == "__main__":
    unittest.main()