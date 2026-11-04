# Import template

Use a CSV or Google Sheet with one header row. Suggested columns:

`asset_tag,category,brand,model,model_number,serial_number,cpu,ram,storage,office_code,received_at,status,notes`

Supported category values:
`desktop,laptop,monitor,printer,scanner,network,storage,ups,accessory,other`

Supported status values:
`available,assigned,maintenance,damaged,retired,returned`

Before import:
- Normalize category and status values.
- Validate office codes against the office registry.
- Flag duplicate asset tags and serial numbers.
- Preview rejected rows and reason.
- Confirm import explicitly.
- Preserve source row number and import batch ID for audit.

Do not import real personal or inventory data into a public repository.
