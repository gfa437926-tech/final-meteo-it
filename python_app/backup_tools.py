"""Local, user-initiated backups for Excel and PostgreSQL inventory stores."""
from __future__ import annotations

import os
import shutil
import subprocess
from datetime import datetime
from pathlib import Path


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
    env = os.environ.copy()
    env["PGPASSWORD"] = dsn.split(":", 1)[1].split("@", 1)[0] if "://" in dsn and "@" in dsn else ""
    completed = subprocess.run(
        [executable, "--format=custom", "--no-owner", "--no-acl", "--file", str(target), "--dbname", dsn],
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
