from __future__ import annotations

import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from datetime import datetime
from pathlib import Path
import sys

from excel_store import SCHEMA
from dotenv import load_dotenv
from storage_factory import create_store
from export_tools import export_workbook
from import_tools import import_workbook
from backup_tools import create_backup, suggested_backup_name
from validation import validate_record

def filter_rows(rows, query: str):
    """Return rows containing the case-insensitive query in any field."""
    needle = (query or "").strip().casefold()
    if not needle:
        return rows
    return [row for row in rows if needle in " ".join(str(v or "") for v in row.values()).casefold()]


LABELS = {
    "Assets": ("الأصول", {"category":"الفئة", "brand":"الشركة", "model":"الطراز", "serial_number":"الرقم التسلسلي", "status":"الحالة", "office":"المكتب", "employee":"المستلم", "cpu":"المعالج", "ram":"الذاكرة", "storage":"التخزين", "received_at":"تاريخ الاستلام", "notes":"ملاحظات"}),
    "Offices": ("المكاتب", {"name":"اسم المكتب", "directorate":"المديرية", "department":"القسم", "location":"الموقع", "notes":"ملاحظات"}),
    "Custody": ("العهد", {"asset_id":"معرّف الأصل", "asset_serial":"الرقم التسلسلي", "employee":"الموظف", "office":"المكتب", "issued_at":"تاريخ التسليم", "returned_at":"تاريخ الإرجاع", "status":"الحالة", "notes":"ملاحظات"}),
    "Maintenance": ("الصيانة", {"asset_id":"معرّف الأصل", "asset_serial":"الرقم التسلسلي", "problem":"العطل", "action_taken":"الإجراء", "technician":"الفني", "opened_at":"تاريخ الفتح", "closed_at":"تاريخ الإغلاق", "cost":"الكلفة", "status":"الحالة", "notes":"ملاحظات"}),
    "Purchases": ("المشتريات", {"purchase_number":"رقم الشراء", "supplier":"المورد", "invoice_number":"رقم الفاتورة", "purchase_date":"تاريخ الشراء", "total_cost":"الإجمالي", "warranty_until":"انتهاء الضمان", "notes":"ملاحظات"}),
    "SpareParts": ("قطع الغيار", {"name":"اسم القطعة", "part_number":"رقم القطعة", "quantity":"الكمية", "unit_cost":"سعر الوحدة", "location":"الموقع", "notes":"ملاحظات"}),
    "AuditLog": ("سجل العمليات", {"timestamp":"الوقت", "username":"المستخدم", "action":"العملية", "sheet":"القسم", "record_id":"معرّف السجل", "details":"التفاصيل"}),
}

class InventoryApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("نظام جرد وإدارة أصول تقنية المعلومات — Python")
        self.geometry("1280x780")
        self.minsize(980, 620)
        app_dir = Path(sys.executable).resolve().parent if getattr(sys, 'frozen', False) else Path(__file__).resolve().parent
        load_dotenv(app_dir / '.env')
        self.store = create_store()
        self.search_vars = {}
        self.configure(bg="#eef2f6")
        self._build()

    def _build(self):
        header = tk.Frame(self, bg="#173b5e", height=76)
        header.pack(fill="x")
        tk.Label(header, text="نظام جرد وإدارة أصول تقنية المعلومات", bg="#173b5e", fg="white", font=("Arial", 20, "bold"), anchor="e").pack(fill="x", padx=24, pady=(12, 0))
        tk.Label(header, text="نسخة Python مستقلة — PostgreSQL محلي أو Excel — دون Firebase أو Docker", bg="#173b5e", fg="#d7e7f5", font=("Arial", 10), anchor="e").pack(fill="x", padx=26, pady=(2, 10))
        self.tabs = ttk.Notebook(self)
        self.tabs.pack(fill="both", expand=True, padx=14, pady=14)
        self.dashboard_labels = {}
        dashboard = ttk.Frame(self.tabs, padding=24)
        self.tabs.add(dashboard, text="لوحة المعلومات")
        self._build_dashboard(dashboard)
        for sheet, (title, fields) in LABELS.items():
            frame = ttk.Frame(self.tabs)
            self.tabs.add(frame, text=title)
            self._build_table(frame, sheet, fields)
        self._refresh_dashboard()
        storage_info = getattr(self.store, "path", "PostgreSQL — localhost / meteo_inventory")
        footer = tk.Label(self, text=f"مصدر البيانات المحلي: {storage_info}", bg="#eef2f6", fg="#526273", anchor="w")
        footer.pack(fill="x", padx=18, pady=(0, 8))

    def _build_dashboard(self, parent):
        ttk.Label(parent, text="ملخص نظام جرد الأصول", font=("Arial", 20, "bold"), anchor="e").pack(fill="x", pady=(8, 18))
        ttk.Label(parent, text="إحصاءات مباشرة من قاعدة البيانات المحلية", anchor="e").pack(fill="x", pady=(0, 16))
        cards = ttk.Frame(parent)
        cards.pack(fill="x", pady=8)
        sections = [("Assets", "الأصول"), ("Offices", "المكاتب"), ("Custody", "العهد"), ("Maintenance", "عمليات الصيانة"), ("Purchases", "المشتريات"), ("SpareParts", "قطع الغيار")]
        for index, (sheet, title) in enumerate(sections):
            card = ttk.LabelFrame(cards, text=title, padding=18)
            card.grid(row=index // 3, column=index % 3, padx=8, pady=8, sticky="nsew")
            value = ttk.Label(card, text="—", font=("Arial", 22, "bold"))
            value.pack()
            self.dashboard_labels[sheet] = value
        for col in range(3):
            cards.columnconfigure(col, weight=1)
        actions = ttk.Frame(parent)
        actions.pack(fill="x", pady=18)
        ttk.Button(actions, text="تحديث الإحصاءات", command=self._refresh_dashboard).pack(side="right", padx=5)
        ttk.Button(actions, text="تصدير نسخة Excel", command=self._export_excel).pack(side="right", padx=5)
        ttk.Button(actions, text="استيراد من Excel", command=self._import_excel).pack(side="right", padx=5)
        ttk.Button(actions, text="نسخة احتياطية", command=self._backup_database).pack(side="right", padx=5)

    def _refresh_dashboard(self):
        for sheet, label in self.dashboard_labels.items():
            try:
                label.config(text=f"{len(self.store.list_rows(sheet)):,}")
            except Exception:
                label.config(text="—")

    def _export_excel(self):
        destination = filedialog.asksaveasfilename(
            title="حفظ نسخة Excel من بيانات الجرد",
            defaultextension=".xlsx",
            filetypes=[("Excel Workbook", "*.xlsx")],
            initialfile="نسخة_جرد_الأصول.xlsx",
        )
        if not destination:
            return
        try:
            export_workbook(self.store, destination)
            messagebox.showinfo("اكتمل التصدير", f"تم تصدير جميع الأقسام إلى:\n{destination}")
        except Exception as exc:
            messagebox.showerror("فشل التصدير", str(exc))

    def _backup_database(self):
        is_excel = getattr(self.store, "path", None) is not None
        extension = ".xlsx" if is_excel else ".dump"
        destination = filedialog.asksaveasfilename(
            title="حفظ نسخة احتياطية من قاعدة البيانات",
            defaultextension=extension,
            filetypes=[("Excel Backup", "*.xlsx")] if is_excel else [("PostgreSQL Backup", "*.dump")],
            initialfile=suggested_backup_name(extension),
        )
        if not destination:
            return
        try:
            backup_path = create_backup(self.store, destination)
            messagebox.showinfo("اكتملت النسخة الاحتياطية", f"تم حفظ النسخة في:\n{backup_path}")
        except Exception as exc:
            messagebox.showerror("فشل النسخ الاحتياطي", str(exc))

    def _import_excel(self):
        source = filedialog.askopenfilename(
            title="اختيار ملف Excel للاستيراد",
            filetypes=[("Excel Workbook", "*.xlsx")],
        )
        if not source:
            return
        if not messagebox.askyesno(
            "تأكيد الاستيراد",
            "سيتم إضافة السجلات الجديدة فقط. لن تُستبدل السجلات الموجودة، وسيتم تجاهل المكرر وسجل العمليات. هل تريد المتابعة؟",
        ):
            return
        try:
            result = import_workbook(self.store, source)
            self._refresh_dashboard()
            self._reload_current()
            messagebox.showinfo(
                "اكتمل الاستيراد",
                f"السجلات المضافة: {result['imported']}\nالسجلات المتجاوزة/المكررة: {result['skipped']}",
            )
        except Exception as exc:
            messagebox.showerror("فشل الاستيراد", str(exc))

    def _build_table(self, parent, sheet, fields):
        bar = ttk.Frame(parent, padding=8)
        bar.pack(fill="x")
        if sheet != "AuditLog":
            ttk.Button(bar, text="إضافة سجل", command=lambda: self._add(sheet, fields)).pack(side="right", padx=4)
            ttk.Button(bar, text="تعديل المحدد", command=lambda: self._edit(sheet, fields, tree)).pack(side="right", padx=4)
            if sheet != "Assets":
                ttk.Button(bar, text="حذف المحدد", command=lambda: self._delete(sheet, tree)).pack(side="right", padx=4)
        ttk.Button(bar, text="تحديث", command=lambda: self._refresh(sheet, tree, fields)).pack(side="left", padx=4)
        cols = list(fields.keys())
        search_var = tk.StringVar()
        self.search_vars[sheet] = search_var
        search_box = ttk.Entry(bar, textvariable=search_var, justify="right", width=30)
        search_box.pack(side="right", padx=(16, 4))
        ttk.Label(bar, text="بحث في السجلات:").pack(side="right")
        tree = ttk.Treeview(parent, columns=cols, show="headings", height=22)
        for key in cols:
            tree.heading(key, text=fields[key], anchor="e")
            tree.column(key, width=145, minwidth=90, anchor="e")
        yscroll = ttk.Scrollbar(parent, orient="vertical", command=tree.yview)
        xscroll = ttk.Scrollbar(parent, orient="horizontal", command=tree.xview)
        tree.configure(yscrollcommand=yscroll.set, xscrollcommand=xscroll.set)
        tree.pack(fill="both", expand=True, side="top")
        xscroll.pack(fill="x")
        yscroll.place(relx=0.985, rely=0.13, relheight=0.78)
        search_var.trace_add("write", lambda *_: self._refresh(sheet, tree, fields))
        self._refresh(sheet, tree, fields)

    def _refresh(self, sheet, tree, fields):
        for item in tree.get_children():
            tree.delete(item)
        rows = filter_rows(self.store.list_rows(sheet), self.search_vars[sheet].get())
        for index, row in enumerate(rows):
            values = [row.get(key) if row.get(key) is not None else "" for key in fields]
            row_id = row.get("id") or row.get("timestamp") or f"row-{index}"
            tree.insert("", "end", iid=str(row_id), values=values)

    def _selected_id(self, tree):
        selected = tree.selection()
        if not selected:
            messagebox.showinfo("تنبيه", "حدد سجلاً أولاً.")
            return None
        return selected[0]

    def _form(self, title, fields, initial=None, sheet=None):
        initial = initial or {}
        win = tk.Toplevel(self)
        win.title(title)
        win.geometry("520x650")
        win.transient(self)
        win.grab_set()
        canvas = tk.Canvas(win, highlightthickness=0)
        scroll = ttk.Scrollbar(win, orient="vertical", command=canvas.yview)
        body = ttk.Frame(canvas, padding=14)
        body.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=body, anchor="nw")
        canvas.configure(yscrollcommand=scroll.set)
        canvas.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")
        entries = {}
        for key, label in fields.items():
            ttk.Label(body, text=label, anchor="e").pack(fill="x", pady=(7, 2))
            if key == "status":
                choices = {
                    "Assets": ["متاح", "بعهدة موظف", "قيد الصيانة", "متقاعد", "مفقود"],
                    "Custody": ["مسلّمة", "مُعادة", "قيد الإرجاع"],
                    "Maintenance": ["مفتوحة", "قيد التنفيذ", "مغلقة"],
                }.get(sheet, ["نشط", "غير نشط", "مكتمل", "قيد التنفيذ"])
                entry = ttk.Combobox(body, values=choices, state="readonly", justify="right", width=52)
                if initial.get(key):
                    entry.set(str(initial.get(key)))
            else:
                entry = ttk.Entry(body, justify="right", width=55)
                entry.insert(0, str(initial.get(key) or ""))
            entry.pack(fill="x")
            entries[key] = entry
        return win, entries

    def _collect_form(self, sheet, entries):
        values = {key: widget.get().strip() for key, widget in entries.items()}
        validate_record(sheet, values)
        return values

    def _add(self, sheet, fields):
        win, entries = self._form("إضافة — " + LABELS[sheet][0], fields, sheet=sheet)
        def save():
            try:
                self.store.add_row(sheet, self._collect_form(sheet, entries))
                win.destroy()
                self._reload_current()
                messagebox.showinfo("تم", "تم حفظ السجل في قاعدة البيانات المحلية.")
            except Exception as exc:
                messagebox.showerror("تعذر الحفظ", str(exc))
        ttk.Button(win, text="حفظ", command=save).pack(pady=12)

    def _edit(self, sheet, fields, tree):
        rid = self._selected_id(tree)
        if rid is None: return
        row = next((r for r in self.store.list_rows(sheet) if str(r.get("id")) == rid), None)
        if row is None: return
        win, entries = self._form("تعديل — " + LABELS[sheet][0], fields, row, sheet=sheet)
        def save():
            try:
                self.store.update_row(sheet, rid, self._collect_form(sheet, entries))
                win.destroy()
                self._reload_current()
                messagebox.showinfo("تم", "تم تحديث السجل.")
            except Exception as exc:
                messagebox.showerror("تعذر الحفظ", str(exc))
        ttk.Button(win, text="حفظ التعديلات", command=save).pack(pady=12)

    def _delete(self, sheet, tree):
        rid = self._selected_id(tree)
        if rid is None: return
        if not messagebox.askyesno("تأكيد", "هل تريد حذف السجل المحدد؟"): return
        try:
            self.store.delete_row(sheet, rid)
            self._reload_current()
        except Exception as exc:
            messagebox.showerror("تعذر الحذف", str(exc))

    def _reload_current(self):
        tab_index = self.tabs.index(self.tabs.select())
        frame = self.tabs.nametowidget(self.tabs.tabs()[tab_index])
        # Refresh the tree belonging to the selected tab.
        for child in frame.winfo_children():
            if isinstance(child, ttk.Treeview):
                sheet = next((s for s, (title, _) in LABELS.items() if title == self.tabs.tab(tab_index, "text")), None)
                if sheet:
                    self._refresh(sheet, child, LABELS[sheet][1])
                self._refresh_dashboard()
                return

if __name__ == "__main__":
    try:
        InventoryApp().mainloop()
    except Exception as exc:
        messagebox.showerror("خطأ في تشغيل البرنامج", str(exc))
