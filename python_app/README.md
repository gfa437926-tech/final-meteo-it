# نسخة Python لإدارة وجرد أصول تقنية المعلومات

تطبيق مستقل عن Flutter. لا يستخدم Firebase أو Docker. يدعم Excel أو PostgreSQL مثبتاً مباشرة على Windows.

## إعداد PostgreSQL المحلي
1. ثبّت PostgreSQL for Windows من https://www.postgresql.org/download/windows/ وثبّت pgAdmin 4.
2. احتفظ بالمنفذ 5432.
3. أنشئ مستخدماً مخصصاً وقاعدة بيانات جديدة باسم meteo_inventory (لا تستخدم أي قاعدة قديمة).
4. افتح Query Tool على قاعدة meteo_inventory ونفّذ محتويات schema_postgres.sql.
5. انسخ .env.example إلى .env، وعدّل كلمة مرور المستخدم في INVENTORY_DATABASE_URL. لا ترفع .env إلى GitHub.
6. شغّل run_windows.bat.

مثال اتصال: postgresql://inventory_user:YOUR_PASSWORD@localhost:5432/meteo_inventory

مثال إنشاء المستخدم والقاعدة من pgAdmin كمسؤول:
```sql
CREATE ROLE inventory_user LOGIN PASSWORD 'CHANGE_THIS_PASSWORD';
CREATE DATABASE meteo_inventory OWNER inventory_user;
```

## التخزين
- PostgreSQL: INVENTORY_STORAGE=postgres.
- Excel: INVENTORY_STORAGE=excel.
- لا يتم نقل بيانات Excel تلقائياً أو حذفها عند التبديل.

## الجداول
assets, offices, custody, maintenance, purchases, spare_parts, audit_logs.
قيد فريد يمنع تكرار الرقم التسلسلي للأصل، وسجل تدقيق للعمليات.

## الاختبارات
```powershell
py -3 -m pip install -r requirements.txt
py -3 -m unittest discover -v
```
اختبارات الاتصال الفعلية تحتاج PostgreSQL محلياً مُعداً. لا تستخدم قاعدة الإنتاج للاختبارات.

## الأمان
استخدم مستخدماً محدود الصلاحيات، وكلمة مرور قوية، واتصالات localhost فقط. احفظ .env خارج GitHub. PostgreSQL المحلي هو محرك PostgreSQL وليس حزمة Supabase الكاملة، ولا يتطلب Docker.
