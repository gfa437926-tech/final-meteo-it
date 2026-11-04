# Asset CSV import template

Download an inventory sheet from Excel or Google Sheets as CSV, then use **استيراد الأصول** in the application.

## Supported columns

```csv
category,brand,model,serial_number,status,office_id,cpu,ram,storage,received_at
desktop,Dell,OptiPlex,ABC123,available,OFFICE_ID,Core i5,16 GB,512 GB,2026-01-15
```

Required columns:
- `category`: `desktop,laptop,monitor,printer,scanner,network,storage,ups,accessory,other`
- `brand`
- `model`
- `serial_number`

Optional columns:
- `status`: defaults to `available`; accepted values are `available,assigned,maintenance,damaged,retired,returned`. Rows marked `assigned` or `maintenance` are intentionally rejected because an import row cannot create the required linked custody or maintenance record.
- `office_id`: the existing active Firestore office document ID (not the office display name or an unverified code)
- `cpu`, `ram`, `storage`, `received_at` (ISO date)

## Import safeguards

- Maximum file size: 5 MB; maximum batch: 100 data rows.
- A preview identifies invalid rows before any writes are made.
- Required fields, category/status values, dates, active office IDs, existing serials, and duplicate serials within the file are validated.
- Only valid rows are offered for import. The user must explicitly confirm the number of new assets.
- Each asset is created through the normal repository transaction, which reserves the normalized serial number. Existing assets are never overwritten.
- The import is sequential, not a single all-or-nothing batch. If a later write fails, successful earlier rows remain saved and failures are reported by source row number.
- This CSV workflow is a manual bridge from Google Sheets. Direct Sheets OAuth synchronization and scheduled/bidirectional sync are not implemented yet.

Do not import real personal or inventory data into a public repository.
