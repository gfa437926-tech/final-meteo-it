"""PostgreSQL backend compatible with the existing ExcelStore interface."""
from __future__ import annotations
import os
from datetime import datetime
from typing import Any
import psycopg
from psycopg.rows import dict_row
from excel_store import SCHEMA
from validation import resolve_asset_reference, validate_record

TABLES={"Assets":"assets","Offices":"offices","Custody":"custody","Maintenance":"maintenance","Purchases":"purchases","SpareParts":"spare_parts","AuditLog":"audit_logs"}

class PostgresStore:
    def __init__(self, dsn: str | None=None):
        self.dsn=dsn or os.getenv("INVENTORY_DATABASE_URL","").strip()
        if not self.dsn: raise RuntimeError("اضبط INVENTORY_DATABASE_URL في ملف .env أولاً.")
        try:
            with self._connect() as conn: conn.execute("SELECT 1")
        except Exception as exc: raise RuntimeError(f"تعذر الاتصال بقاعدة PostgreSQL المحلية: {exc}") from exc
    def _connect(self): return psycopg.connect(self.dsn,row_factory=dict_row,connect_timeout=5)
    def list_rows(self,sheet: str)->list[dict[str,Any]]:
        if sheet not in TABLES: raise ValueError("Unknown worksheet")
        with self._connect() as conn:
            if sheet=="AuditLog":
                rows=conn.execute("SELECT timestamp::text AS timestamp,username,action,sheet,record_id,details FROM audit_logs ORDER BY log_id DESC LIMIT 5000").fetchall()
            else: rows=conn.execute(f'SELECT * FROM "{TABLES[sheet]}" ORDER BY id').fetchall()
        return [dict(r) for r in rows]
    def add_row(self,sheet: str,values: dict[str,Any])->dict[str,Any]:
        if sheet not in TABLES or sheet=="AuditLog": raise ValueError("This worksheet is not editable")
        clean={k:values.get(k) for k in SCHEMA[sheet]}
        resolve_asset_reference(self,sheet,clean)
        validate_record(sheet,clean)
        clean["id"]=clean.get("id") or f'{sheet.lower()}-{datetime.now().strftime("%Y%m%d%H%M%S%f")}'
        if sheet=="Assets": clean["serial_number"]=str(clean.get("serial_number") or "").strip().upper() or None
        now=datetime.now().astimezone().isoformat(timespec="seconds")
        if "created_at" in SCHEMA[sheet] and not clean.get("created_at"): clean["created_at"]=now
        if "updated_at" in SCHEMA[sheet]: clean["updated_at"]=now
        cols=list(clean); names=", ".join(f'"{c}"' for c in cols); marks=", ".join(["%s"]*len(cols))
        try:
            with self._connect() as conn: conn.execute(f'INSERT INTO "{TABLES[sheet]}" ({names}) VALUES ({marks})',[clean[c] for c in cols])
        except psycopg.errors.UniqueViolation as exc:
            if sheet=="Assets": raise ValueError("الرقم التسلسلي مسجل مسبقاً.") from exc
            raise ValueError("معرّف السجل مستخدم مسبقاً.") from exc
        self.log("local-user","إضافة",sheet,clean["id"],str(clean)); return clean
    def update_row(self,sheet: str,record_id: str,values: dict[str,Any])->None:
        if sheet not in TABLES or sheet=="AuditLog": raise ValueError("This worksheet is not editable")
        updates={k:v for k,v in values.items() if k in SCHEMA[sheet] and k!="id"}
        if not updates: return
        resolve_asset_reference(self,sheet,updates)
        validate_record(sheet,updates,require_fields=False)
        if sheet=="Assets" and "serial_number" in updates: updates["serial_number"]=str(updates["serial_number"] or "").strip().upper() or None
        if "updated_at" in SCHEMA[sheet]: updates["updated_at"]=datetime.now().astimezone().isoformat(timespec="seconds")
        sets=", ".join(f'"{k}" = %s' for k in updates)
        try:
            with self._connect() as conn:
                result=conn.execute(f'UPDATE "{TABLES[sheet]}" SET {sets} WHERE id = %s',[*updates.values(),record_id])
                if result.rowcount==0: raise ValueError("السجل المطلوب غير موجود.")
        except psycopg.errors.UniqueViolation as exc: raise ValueError("الرقم التسلسلي مسجل لأصل آخر.") from exc
        self.log("local-user","تعديل",sheet,record_id,str(values))
    def delete_row(self,sheet: str,record_id: str)->None:
        if sheet not in TABLES or sheet in ("AuditLog","Assets"): raise ValueError("حذف الأصول معطل لحماية سجل الجرد؛ غيّر الحالة إلى متقاعد.")
        with self._connect() as conn:
            result=conn.execute(f'DELETE FROM "{TABLES[sheet]}" WHERE id=%s',(record_id,))
            if result.rowcount==0: raise ValueError("السجل المطلوب غير موجود.")
        self.log("local-user","حذف",sheet,record_id,"حذف سجل")
    def log(self,username: str,action: str,sheet: str,record_id: str,details: str)->None:
        with self._connect() as conn: conn.execute("INSERT INTO audit_logs(username,action,sheet,record_id,details) VALUES (%s,%s,%s,%s,%s)",(username,action,sheet,record_id,details[:1000]))
