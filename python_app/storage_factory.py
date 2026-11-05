import os
def create_store():
    backend=os.getenv("INVENTORY_STORAGE","excel").strip().lower()
    if backend=="postgres":
        from postgres_store import PostgresStore
        return PostgresStore()
    if backend=="excel":
        from excel_store import ExcelStore
        return ExcelStore()
    raise RuntimeError("INVENTORY_STORAGE يجب أن يكون excel أو postgres.")
