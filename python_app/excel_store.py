"""Local Excel-backed storage for the Python IT asset inventory."""
from __future__ import annotations

import os
import shutil
import tempfile
import sys
from datetime import datetime
from pathlib import Path
from typing import Any
from validation import resolve_asset_reference, validate_record

from openpyxl import Workbook, load_workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter

SCHEMA: dict[str, list[str]] = {
    "Assets": ["id", "category", "brand", "model", "serial_number", "status", "office", "employee", "cpu", "ram", "storage", "received_at", "notes", "created_at", "updated_at"],
    "Offices": ["id", "name", "directorate", "department", "location", "notes", "created_at", "updated_at"],
    "Custody": ["id", "asset_id", "asset_serial", "employee", "office", "issued_at", "returned_at", "status", "notes", "created_at"],
    "Maintenance": ["id", "asset_id", "asset_serial", "problem", "action_taken", "technician", "opened_at", "closed_at", "cost", "status", "notes"],
    "Purchases": ["id", "purchase_number", "supplier", "invoice_number", "purchase_date", "total_cost", "warranty_until", "notes"],
    "SpareParts": ["id", "name", "part_number", "quantity", "unit_cost", "location", "notes", "updated_at"],
    "AuditLog": ["timestamp", "username", "action", "sheet", "record_id", "details"],
}

class ExcelStore:
    def __init__(self, path: str | Path | None = None):
        base = Path(sys.executable).resolve().parent if getattr(sys, 'frozen', False) else Path(__file__).resolve().parent
        self.path = Path(path) if path else base / "data" / "inventory.xlsx"
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock_path = self.path.with_suffix(self.path.suffix + ".lock")
        self._ensure_workbook()

    def _ensure_workbook(self) -> None:
        if self.path.exists():
            return
        wb = Workbook()
        default = wb.active
        wb.remove(default)
        for sheet, headers in SCHEMA.items():
            ws = wb.create_sheet(sheet)
            ws.append(headers)
            self._style_sheet(ws)
        wb.save(self.path)

    @staticmethod
    def _style_sheet(ws) -> None:
        ws.freeze_panes = "A2"
        ws.auto_filter.ref = ws.dimensions
        for cell in ws[1]:
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = PatternFill("solid", fgColor="24476B")
            cell.alignment = Alignment(horizontal="center")
        for idx, col in enumerate(ws.columns, start=1):
            ws.column_dimensions[get_column_letter(idx)].width = min(max(14, max(len(str(c.value or "")) for c in col) + 2), 32)

    def _read_rows(self, sheet: str) -> list[dict[str, Any]]:
        if sheet not in SCHEMA:
            raise ValueError("Unknown worksheet")
        wb = load_workbook(self.path, read_only=True, data_only=True)
        try:
            ws = wb[sheet]
            headers = [c.value for c in ws[1]]
            return [dict(zip(headers, row)) for row in ws.iter_rows(min_row=2, values_only=True) if any(v is not None for v in row)]
        finally:
            wb.close()

    def list_rows(self, sheet: str) -> list[dict[str, Any]]:
        return self._read_rows(sheet)

    def _acquire_lock(self):
        try:
            fd = os.open(self.lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, f"pid={os.getpid()} time={datetime.now().isoformat()}".encode())
            return fd
        except FileExistsError as exc:
            raise RuntimeError("ملف Excel قيد الاستخدام. أغلق النسخة الأخرى ثم أعد المحاولة.") from exc

    def _save_atomic(self, wb) -> None:
        fd, temp_name = tempfile.mkstemp(prefix="inventory_", suffix=".xlsx", dir=self.path.parent)
        os.close(fd)
        try:
            wb.save(temp_name)
            os.replace(temp_name, self.path)
        finally:
            if os.path.exists(temp_name):
                os.unlink(temp_name)

    def _write(self, sheet: str, rows: list[dict[str, Any]]) -> None:
        lock_fd = self._acquire_lock()
        try:
            if self.path.exists():
                stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
                backup_dir = self.path.parent / "backups"
                backup_dir.mkdir(exist_ok=True)
                shutil.copy2(self.path, backup_dir / f"inventory_{stamp}.xlsx")
            wb = load_workbook(self.path)
            ws = wb[sheet]
            ws.delete_rows(2, max(ws.max_row - 1, 1))
            for item in rows:
                ws.append([item.get(col) for col in SCHEMA[sheet]])
            self._style_sheet(ws)
            self._save_atomic(wb)
            wb.close()
        finally:
            os.close(lock_fd)
            try:
                self.lock_path.unlink()
            except FileNotFoundError:
                pass

    def add_row(self, sheet: str, values: dict[str, Any]) -> dict[str, Any]:
        if sheet not in SCHEMA or sheet == "AuditLog":
            raise ValueError("This worksheet is not editable")
        rows = self._read_rows(sheet)
        clean = {key: values.get(key) for key in SCHEMA[sheet]}
        resolve_asset_reference(self, sheet, clean)
        validate_record(sheet, clean)
        clean["id"] = clean.get("id") or f"{sheet.lower()}-{datetime.now().strftime('%Y%m%d%H%M%S%f')}"
        if sheet == "Assets":
            serial = str(clean.get("serial_number") or "").strip().upper()
            if serial and any(str(r.get("serial_number") or "").strip().upper() == serial for r in rows):
                raise ValueError("الرقم التسلسلي مسجل مسبقاً.")
            clean["serial_number"] = serial
        now = datetime.now().isoformat(timespec="seconds")
        if "created_at" in SCHEMA[sheet] and not clean.get("created_at"):
            clean["created_at"] = now
        if "updated_at" in SCHEMA[sheet]:
            clean["updated_at"] = now
        rows.append(clean)
        self._write(sheet, rows)
        self.log("local-user", "إضافة", sheet, clean["id"], str(clean))
        return clean

    def update_row(self, sheet: str, record_id: str, values: dict[str, Any]) -> None:
        rows = self._read_rows(sheet)
        found = False
        for row in rows:
            if str(row.get("id")) == str(record_id):
                updated = {**row, **values}
                resolve_asset_reference(self, sheet, updated)
                validate_record(sheet, updated, require_fields=False)
                if sheet == "Assets":
                    serial = str(updated.get("serial_number") or "").strip().upper()
                    if serial and any(str(r.get("id")) != str(record_id) and str(r.get("serial_number") or "").strip().upper() == serial for r in rows):
                        raise ValueError("الرقم التسلسلي مسجل لأصل آخر.")
                    updated["serial_number"] = serial
                if "updated_at" in SCHEMA[sheet]:
                    updated["updated_at"] = datetime.now().isoformat(timespec="seconds")
                row.update(updated)
                found = True
                break
        if not found:
            raise ValueError("السجل المطلوب غير موجود.")
        self._write(sheet, rows)
        self.log("local-user", "تعديل", sheet, record_id, str(values))

    def delete_row(self, sheet: str, record_id: str) -> None:
        if sheet in ("AuditLog", "Assets"):
            raise ValueError("حذف الأصول معطل لحماية سجل الجرد؛ غيّر الحالة إلى متقاعد.")
        rows = self._read_rows(sheet)
        kept = [r for r in rows if str(r.get("id")) != str(record_id)]
        if len(kept) == len(rows):
            raise ValueError("السجل المطلوب غير موجود.")
        self._write(sheet, kept)
        self.log("local-user", "حذف", sheet, record_id, "حذف سجل")

    def log(self, username: str, action: str, sheet: str, record_id: str, details: str) -> None:
        rows = self._read_rows("AuditLog")
        rows.append({"timestamp": datetime.now().isoformat(timespec="seconds"), "username": username, "action": action, "sheet": sheet, "record_id": record_id, "details": details[:1000]})
        self._write("AuditLog", rows)
