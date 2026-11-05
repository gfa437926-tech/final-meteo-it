from __future__ import annotations

import tkinter as tk
from tkinter import ttk, messagebox
from datetime import datetime

from excel_store import SCHEMA
from dotenv import load_dotenv
from storage_factory import create_store

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
        load_dotenv()
        self.store = create_store()
        self.configure(bg="#eef2f6")
        self._build()

    def _build(self):
        header = tk.Frame(self, bg="#173b5e", height=76)
        header.pack(fill="x")
        tk.Label(header, text="نظام جرد وإدارة أصول تقنية المعلومات", bg="#173b5e", fg="white", font=("Arial", 20, "bold"), anchor="e").pack(fill="x", padx=24, pady=(12, 0))
        tk.Label(header, text="نسخة Python مستقلة — PostgreSQL محلي أو Excel — دون Firebase أو Docker", bg="#173b5e", fg="#d7e7f5", font=("Arial", 10), anchor="e").pack(fill="x", padx=26, pady=(2, 10))
        self.tabs = ttk.Notebook(self)
        self.tabs.pack(fill="both", expand=True, padx=14, pady=14)
        for sheet, (title, fields) in LABELS.items():
            frame = ttk.Frame(self.tabs)
            self.tabs.add(frame, text=title)
            self._build_table(frame, sheet, fields)
        footer = tk.Label(self, text=f"ملف البيانات: {self.store.path}", bg="#eef2f6", fg="#526273", anchor="w")
        footer.pack(fill="x", padx=18, pady=(0, 8))

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
        self._refresh(sheet, tree, fields)

    def _refresh(self, sheet, tree, fields):
        for item in tree.get_children():
            tree.delete(item)
        for row in self.store.list_rows(sheet):
            values = [row.get(key) if row.get(key) is not None else "" for key in fields]
            tree.insert("", "end", iid=str(row.get("id") or row.get("timestamp")), values=values)

    def _selected_id(self, tree):
        selected = tree.selection()
        if not selected:
            messagebox.showinfo("تنبيه", "حدد سجلاً أولاً.")
            return None
        return selected[0]

    def _form(self, title, fields, initial=None):
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
            entry = ttk.Entry(body, justify="right", width=55)
            entry.insert(0, str(initial.get(key) or ""))
            entry.pack(fill="x")
            entries[key] = entry
        return win, entries

    def _add(self, sheet, fields):
        win, entries = self._form("إضافة — " + LABELS[sheet][0], fields)
        def save():
            try:
                self.store.add_row(sheet, {k: e.get().strip() for k, e in entries.items()})
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
        win, entries = self._form("تعديل — " + LABELS[sheet][0], fields, row)
        def save():
            try:
                self.store.update_row(sheet, rid, {k: e.get().strip() for k, e in entries.items()})
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
                return

if __name__ == "__main__":
    try:
        InventoryApp().mainloop()
    except Exception as exc:
        messagebox.showerror("خطأ في تشغيل البرنامج", str(exc))
