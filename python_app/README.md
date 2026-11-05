# نسخة Python لإدارة وجرد أصول تقنية المعلومات

تطبيق Windows مستقل عن Flutter. لا يستخدم Firebase أو Docker. يدعم Excel أو PostgreSQL محلياً.

## التثبيت الآلي

1. نزّل المستودع كاملاً من GitHub باستخدام **Code → Download ZIP** ثم فك الضغط.
2. انقر نقراً مزدوجاً على `python_app/install_and_setup.bat`.
3. وافق على صلاحيات مسؤول Windows.
4. إذا كان PostgreSQL مثبتاً مسبقاً، أدخل كلمة مرور المستخدم `postgres` الحالية عند الطلب.

يحاول المثبّت تثبيت PostgreSQL 17 وPython 3.12 تلقائياً عبر winget عند عدم وجودهما، ثم ينشئ قاعدة `meteo_inventory` ومستخدم التطبيق `inventory_app`، ويطبق الجداول، وينشئ بيئة Python، ويثبت المكتبات، ويختبر الاتصال، ثم يشغل البرنامج. يلزم Windows 10/11، اتصال إنترنت أثناء التثبيت، وwinget (App Installer). قد تتطلب بعض الأجهزة إعادة تشغيل بعد تثبيت Python.

**مهم:** هذه قاعدة PostgreSQL محلية وليست حزمة Supabase الكاملة؛ لا Docker ولا Firebase ولا مشروع سحابي. لا يتصل المثبّت بأي قواعد قديمة، ولا يستورد بيانات Excel تلقائياً.

## التشغيل بعد التثبيت

انقر `run_windows.bat`. إعداد الاتصال محفوظ محلياً في `.env` ولا ترفعه إلى GitHub.

## التخزين

- PostgreSQL: `INVENTORY_STORAGE=postgres`.
- Excel: `INVENTORY_STORAGE=excel`.
- ملفات Excel القديمة تبقى دون تعديل عند التبديل.

## الجداول

`assets`, `offices`, `custody`, `maintenance`, `purchases`, `spare_parts`, `audit_logs`.

## الاختبارات

```powershell
py -3 -m pip install -r requirements.txt
py -3 -m unittest discover -v
```

اختبارات الاتصال الفعلية تحتاج PostgreSQL محلياً. استخدم قاعدة اختبار منفصلة قبل أي بيانات حقيقية.

## الأمان

- كلمة مرور مستخدم التطبيق تُولّد عشوائياً وتُحفظ في `.env` المحلي.
- لا تفتح منفذ PostgreSQL للشبكة؛ الاتصال مضبوط على localhost.
- احتفظ بنسخ احتياطية دورية باستخدام `pg_dump`.
