"""Safe append-only import from an Excel workbook into the selected inventory store."""
from datetime import date, datetime, time
from pathlib import Path

from openpyxl import load_workbook

from excel_store import SCHEMA


def _cell_value(value):
    if isinstance(value, (datetime, date, time)):
        return value.isoformat()
    if value is None:
        return None
    return str(value).strip()


def import_workbook(store, source: str | Path) -> dict[str, int]:
    source = Path(source).resolve()
    active_path = getattr(store, "path", None)
    if active_path and Path(active_path).resolve() == source:
        raise ValueError("لا يمكن استيراد الملف نفسه الذي يستخدمه مخزن Excel الحالي.")
    workbook = load_workbook(source, read_only=True, data_only=True)
    imported = 0
    skipped = 0
    try:
        for sheet in SCHEMA:
            if sheet == "AuditLog" or sheet not in workbook.sheetnames:
                continue
            worksheet = workbook[sheet]
            headers = [str(cell.value).strip() if cell.value is not None else "" for cell in worksheet[1]]
            if not headers or not any(headers):
                continue
            existing = store.list_rows(sheet)
            known_ids = {str(row.get("id")) for row in existing if row.get("id")}
            known_serials = {
                str(row.get("serial_number") or "").strip().upper()
                for row in existing if row.get("serial_number")
            } if sheet == "Assets" else set()
            for values in worksheet.iter_rows(min_row=2, values_only=True):
                record = {headers[i]: _cell_value(value) for i, value in enumerate(values) if i < len(headers) and headers[i] in SCHEMA[sheet]}
                if not any(value not in (None, "") for value in record.values()):
                    continue
                record = {key: record.get(key) for key in SCHEMA[sheet]}
                record_id = record.get("id")
                serial = str(record.get("serial_number") or "").strip().upper() if sheet == "Assets" else ""
                if record_id and str(record_id) in known_ids:
                    skipped += 1
                    continue
                if serial and serial in known_serials:
                    skipped += 1
                    continue
                try:
                    store.add_row(sheet, record)
                    imported += 1
                    if record_id:
                        known_ids.add(str(record_id))
                    if serial:
                        known_serials.add(serial)
                except (ValueError, KeyError):
                    skipped += 1
    finally:
        workbook.close()
    return {"imported": imported, "skipped": skipped}
