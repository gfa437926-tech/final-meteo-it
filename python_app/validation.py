"""Shared business validation for inventory records."""
from decimal import Decimal, InvalidOperation

REQUIRED_FIELDS = {
    "Assets": {"category": "فئة الأصل"},
    "Offices": {"name": "اسم المكتب"},
    "Custody": {"asset_serial": "الرقم التسلسلي", "employee": "اسم الموظف"},
    "Maintenance": {"problem": "وصف العطل"},
    "Purchases": {"purchase_number": "رقم الشراء"},
    "SpareParts": {"name": "اسم قطعة الغيار"},
}
DECIMAL_FIELDS = {
    "Maintenance": {"cost": "الكلفة"},
    "Purchases": {"total_cost": "إجمالي الشراء"},
    "SpareParts": {"unit_cost": "سعر الوحدة"},
}
INTEGER_FIELDS = {"SpareParts": {"quantity": "الكمية"}}


def validate_record(sheet: str, values: dict, *, require_fields: bool = True) -> None:
    if require_fields:
        missing = [
            label for key, label in REQUIRED_FIELDS.get(sheet, {}).items()
            if values.get(key) is None or str(values.get(key)).strip() == ""
        ]
        if missing:
            raise ValueError("الحقول الإلزامية غير مكتملة: " + "، ".join(missing))

    for key, label in DECIMAL_FIELDS.get(sheet, {}).items():
        raw = values.get(key)
        if raw in (None, ""):
            continue
        try:
            number = Decimal(str(raw).replace(",", "").strip())
        except (InvalidOperation, ValueError):
            raise ValueError(f"{label}: أدخل رقماً صحيحاً.") from None
        if not number.is_finite() or number < 0:
            raise ValueError(f"{label}: يجب أن تكون القيمة صفراً أو أكبر.")

    for key, label in INTEGER_FIELDS.get(sheet, {}).items():
        raw = values.get(key)
        if raw in (None, ""):
            continue
        try:
            number = Decimal(str(raw).strip())
        except (InvalidOperation, ValueError):
            raise ValueError(f"{label}: أدخل عدداً صحيحاً.") from None
        if not number.is_finite() or number < 0 or number != number.to_integral_value():
            raise ValueError(f"{label}: أدخل عدداً صحيحاً غير سالب.")


def resolve_asset_reference(store, sheet: str, values: dict) -> None:
    """Resolve custody/maintenance links from the selected asset serial."""
    if sheet not in {"Custody", "Maintenance"}:
        return
    serial = str(values.get("asset_serial") or "").strip().casefold()
    if not serial:
        return
    asset = next(
        (row for row in store.list_rows("Assets")
         if str(row.get("serial_number") or "").strip().casefold() == serial),
        None,
    )
    if asset is None:
        raise ValueError("الرقم التسلسلي المختار غير موجود في سجل الأصول.")
    values["asset_id"] = asset.get("id")
