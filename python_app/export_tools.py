"""Export every inventory table to a portable Excel workbook."""
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

from excel_store import SCHEMA


def export_workbook(store, destination: str | Path) -> Path:
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    workbook = Workbook()
    workbook.remove(workbook.active)
    for sheet_name, columns in SCHEMA.items():
        worksheet = workbook.create_sheet(sheet_name)
        worksheet.append(columns)
        for row in store.list_rows(sheet_name):
            worksheet.append([row.get(column) for column in columns])
        worksheet.freeze_panes = "A2"
        worksheet.auto_filter.ref = worksheet.dimensions
        for cell in worksheet[1]:
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = PatternFill("solid", fgColor="24476B")
            cell.alignment = Alignment(horizontal="center")
        for index, column in enumerate(worksheet.columns, start=1):
            width = max((len(str(cell.value or "")) for cell in column), default=12)
            worksheet.column_dimensions[get_column_letter(index)].width = min(max(14, width + 2), 40)
    workbook.save(destination)
    workbook.close()
    return destination
