"""Local, user-initiated backups for Excel and PostgreSQL inventory stores."""
from __future__ import annotations

import os
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from urllib.parse import unquote, urlsplit


def create_backup(store, destination: str | Path) -> Path:
    target = Path(destination)
    target.parent.mkdir(parents=True, exist_ok=True)
    if getattr(store, "path", None):
        source = Path(store.path)
        if not source.exists():
            raise FileNotFoundError("ملف قاعدة Excel غير موجود.")
        if source.resolve() == target.resolve():
            raise ValueError("اختر مساراً مختلفاً عن ملف قاعدة البيانات الحالي.")
        shutil.copy2(source, target)
        return target

    dsn = getattr(store, "dsn", "")
    if not dsn:
        raise RuntimeError("نوع مخزن البيانات غير معروف.")
    candidates = [
        shutil.which("pg_dump"),
        str(Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "PostgreSQL/17/bin/pg_dump.exe"),
        str(Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "PostgreSQL/16/bin/pg_dump.exe"),
        str(Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "PostgreSQL/15/bin/pg_dump.exe"),
    ]
    executable = next((item for item in candidates if item and (Path(item).exists() if os.path.isabs(item) else True)), None)
    if not executable:
        raise FileNotFoundError("لم يتم العثور على pg_dump. تأكد من تثبيت أدوات PostgreSQL.")
    parsed = urlsplit(dsn)
    if not parsed.hostname or not parsed.path.lstrip("/"):
        raise ValueError("عنوان اتصال PostgreSQL غير صالح.")
    env = os.environ.copy()
    env["PGPASSWORD"] = unquote(parsed.password or "")
    env["PGHOST"] = parsed.hostname
    env["PGPORT"] = str(parsed.port or 5432)
    env["PGUSER"] = unquote(parsed.username or "")
    env["PGDATABASE"] = unquote(parsed.path.lstrip("/"))
    completed = subprocess.run(
        [executable, "--format=custom", "--no-owner", "--no-acl", "--no-password", "--file", str(target)],
        env=env,
        capture_output=True,
        text=True,
        timeout=180,
        check=False,
    )
    if completed.returncode != 0:
        target.unlink(missing_ok=True)
        raise RuntimeError((completed.stderr or "فشل إنشاء النسخة الاحتياطية.")[-2000:])
    return target


def suggested_backup_name(extension: str) -> str:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"inventory_backup_{stamp}{extension}"
