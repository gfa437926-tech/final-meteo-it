# نسخة Python لإدارة وجرد أصول تقنية المعلومات

تطبيق Windows مستقل عن Flutter. لا يستخدم Firebase أو Docker. التخزين الافتراضي PostgreSQL محلي، مع خيار Excel.

## التثبيت والتحويل إلى EXE تلقائياً

1. نزّل المستودع كاملاً من GitHub عبر **Code → Download ZIP** ثم فك الضغط.
2. انقر نقراً مزدوجاً على الملف `ابدأ_التثبيت.bat` الموجود في المجلد الرئيسي للمشروع (أو `python_app/install_and_setup.bat`). بعد اكتمال الإعداد سيُنشأ اختصار **نظام جرد الأصول** على سطح المكتب، ويُفتح التطبيق تلقائياً.
3. وافق على صلاحيات مسؤول Windows.
4. إذا كان PostgreSQL مثبتاً مسبقاً، أدخل كلمة مرور مستخدم `postgres` الحالية.

المثبّت يثبت PostgreSQL 17 وPython 3.12 عند الحاجة، ينشئ قاعدة `meteo_inventory` ومستخدم التطبيق، يطبق مخطط الجداول، ينشئ بيئة Python ويثبت المتطلبات، ثم يبني التطبيق إلى **EXE على الجهاز نفسه** باستخدام PyInstaller ويشغله.

**ملف التشغيل الناتج:**
`python_app\dist\InventoryManager\InventoryManager.exe`

يُبنى التطبيق على الجهاز المستهدف نفسه، لذلك يطابق معمارية Windows/Python المثبتة عليه. نستخدم وضع مجلد مستقل (onedir) بدلاً من ملف واحد ضخـم لتحسين توافق مكتبات PostgreSQL وتقليل مشكلات التشغيل. انقل مجلد `InventoryManager` كاملاً، لا تنقل EXE منفرداً.

## إعادة بناء EXE لاحقاً

انقر `python_app\build_exe.bat`. ينتج التطبيق داخل `dist\InventoryManager`. لا يلزم تثبيت Python لتشغيل EXE بعد بنائه، لكن يلزم وجود خدمة PostgreSQL المحلية كي يعمل مخزن PostgreSQL.

## التشغيل اليومي

شغّل `dist\InventoryManager\InventoryManager.exe`. يمكن أيضاً استخدام `run_windows.bat` لتشغيل نسخة Python أثناء التطوير.

## التخزين وقاعدة البيانات

- PostgreSQL: `INVENTORY_STORAGE=postgres`.
- Excel: `INVENTORY_STORAGE=excel`.
- إعداد الاتصال المحلي موجود في `.env` بجانب EXE الناتج.
- لا يستورد المثبّت بيانات Excel تلقائياً ولا يعدّل أي قاعدة قديمة.

هذه قاعدة PostgreSQL محلية وليست حزمة Supabase الكاملة؛ لا Docker ولا Firebase ولا مشروع سحابي.

## الجداول

`assets`, `offices`, `custody`, `maintenance`, `purchases`, `spare_parts`, `audit_logs`.

## الاختبارات

```powershell
py -3 -m pip install -r requirements.txt
py -3 -m unittest discover -v
```

اختبارات الاتصال الفعلية تتطلب PostgreSQL محلياً.

## الأمان

- كلمة مرور مستخدم التطبيق تُولّد عشوائياً وتُحفظ محلياً في `.env`.
- لا تفتح منفذ PostgreSQL للشبكة؛ الاتصال الافتراضي localhost.
- احتفظ بنسخ احتياطية دورية باستخدام `pg_dump`.
- احفظ مجلد EXE وملفاته المرافقة كاملاً؛ لا تشارك ملف `.env` أو ترفعه إلى GitHub.
