"""Explicit restore helpers. Call only after the UI obtains user confirmation."""
from __future__ import annotations
import os, shutil, subprocess
from pathlib import Path
from urllib.parse import unquote, urlsplit

def restore_backup(store, source: str | Path) -> Path:
    backup=Path(source)
    if not backup.is_file(): raise FileNotFoundError("ملف النسخة الاحتياطية غير موجود.")
    if getattr(store,"path",None):
        target=Path(store.path)
        if backup.resolve()==target.resolve(): raise ValueError("لا يمكن استعادة الملف فوق نفسه.")
        # Preserve the current workbook before replacing it.
        shutil.copy2(target,target.with_suffix(target.suffix+".before-restore.bak")) if target.exists() else None
        shutil.copy2(backup,target)
        return target
    dsn=getattr(store,"dsn","")
    parsed=urlsplit(dsn)
    if not parsed.hostname or not parsed.path.lstrip("/"): raise ValueError("عنوان اتصال PostgreSQL غير صالح.")
    candidates=[shutil.which("pg_restore"),str(Path(os.environ.get("ProgramFiles","C:/Program Files"))/"PostgreSQL/17/bin/pg_restore.exe"),str(Path(os.environ.get("ProgramFiles","C:/Program Files"))/"PostgreSQL/16/bin/pg_restore.exe")]
    exe=next((x for x in candidates if x and (Path(x).exists() if os.path.isabs(x) else True)),None)
    if not exe: raise FileNotFoundError("لم يتم العثور على pg_restore.")
    env=os.environ.copy(); env.update(PGPASSWORD=unquote(parsed.password or ""),PGHOST=parsed.hostname,PGPORT=str(parsed.port or 5432),PGUSER=unquote(parsed.username or ""),PGDATABASE=parsed.path.lstrip("/"))
    # Clean restore is intentionally not automatic; pg_restore merges/replaces objects according to flags.
    result=subprocess.run([exe,"--clean","--if-exists","--no-owner","--no-acl","--no-password","--dbname",dsn,str(backup)],env=env,capture_output=True,text=True,timeout=300,check=False)
    if result.returncode: raise RuntimeError((result.stderr or "فشلت استعادة PostgreSQL.")[-2500:])
    return backup
