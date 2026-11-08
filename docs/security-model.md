# Security model (current implementation)

## Authentication and profiles

- Firebase Authentication uses Email/Password.
- Every authenticated user must have a matching `users/{uid}` Firestore profile with `isActive: true` before accessing inventory data.
- The application currently admits only `admin` and `it_manager` roles.
- A super administrator (`admin`) can create and update profile documents for other Firebase Authentication accounts.
- The application does not create Authentication accounts or passwords. Create accounts through the approved identity-admin process, then register their UID in the application or use the guarded create-only CLI in `scripts/provision-user.mjs`.
- Active users may update only their own `displayName`, `email`, and `updatedAt` profile fields; inactive accounts cannot use self-service profile updates, and users cannot change their own role, active state, or `officeIds`.
- A global administrator profile stores `officeIds: []`; an IT manager profile must have 1–20 office IDs. Legacy profiles without `officeIds` remain readable but have no office access until assigned by a super administrator.
- Only the super administrator can provision users or assign/change their `officeIds`.
- User deletion is disabled from the client.

## Current permission matrix

| Capability | admin | it_manager |
|---|---:|---:|
| Sign in when active | Yes | Yes |
| Read all offices and assets, including legacy unassigned assets | Yes | No |
| Read assigned offices and assets only | Yes | Yes |
| Create/update assets in an assigned active office | Yes | Yes |
| Transfer an asset between offices | Yes | Only when assigned to both source and destination |
| Create/update office catalogue records | Yes | No |
| Read linked custody cards, asset documents, maintenance records, purchase records, maintenance-part usage and movement records | All offices | Only through assigned assets/offices |
| Read/write spare-parts stock | All records | Only records carrying an assigned `officeId` |
| Manage other user profiles and assign offices | Yes | No |
| Disable another account | Yes | No |
| Change own role, active state or office assignments | No | No |

## Data integrity

- Asset creation and serial reservation are committed in the same Firestore transaction.
- Serial values are trimmed and uppercased before indexing and persistence.
- Existing legacy assets are scanned before new reservations; editing a legacy asset can lazily create its missing serial reservation.
- Custody assignment, return, transfer, asset office transfer, retirement, and maintenance state changes use Firestore transactions and write movement history.
- Custody approval requires the authenticated approver UID, a timestamp-valued approval time, an active pending card, and an asset that remains assigned after the transaction.
- Custody rejection requires an active pending card, typed rejection metadata, and atomic release of the assigned asset.
- Custody return requires an active approved card and atomic restoration of the asset to available; transfer requires non-empty employee/office values and a matching post-transaction asset office.
- Maintenance completion reads the persisted ticket and asset state instead of trusting the screen's stale record object.

## Firestore and Storage controls

- Administrative predicates require an authenticated user with an active profile and an allowed role.
- Office and asset reads are office-scoped in Firestore. IT-manager queries are constrained to assigned, active offices before assets are fetched. Deactivating an office revokes manager access to its office record, assets, movements, and Storage attachments. An asset without `officeId` is legacy/unassigned and is visible only to the global administrator.
- Asset creates and updates require a real active office. IT managers must be assigned to that office; an update must be authorized for both the old and new office. The global administrator can move a legacy or inactive-office asset into an active office.
- Office catalogue creation and updates are restricted to the global administrator; office deletion remains disabled.
- Serial indexes, movement records, custody cards, Firestore attachment metadata, maintenance records, purchase records, and maintenance-part usage are linked to the asset office. New custody cards persist the linked asset's `officeId`; manager reads use office-constrained queries, while historical cards without `officeId` remain administrator-only. Maintenance and purchase records must carry the exact `officeId` of their linked asset; rules resolve the asset rather than trusting a client-supplied office. Their office and asset links cannot be changed by record updates, and deletion is denied. Attachment metadata must match the linked asset's office. Storage reads/uploads resolve the asset document and enforce the same active-office check.
- Spare-parts stock is scoped by its own `officeId`; records without an office remain admin-only. Shared lookup catalogues remain available to active users.
- Import batch audit records are actor-bound, schema-validated, bounded to 100 rows, and append-only; this audit area remains role-based rather than office-scoped.
- Emulator tests cover authentication/profile gates, office A/B isolation, scoped queries, dual-office transfer, custody/document metadata, Storage access, role elevation, and import audit validation.

## Release limitations and production gates

This remains a development and controlled pre-pilot baseline, not a production-ready enterprise authorization model.

1. **Firebase project and web app:** create/select a dedicated Firebase project for this IT inventory app, register its Web app, and set the six documented GitHub Actions repository Variables. The Pages workflow currently builds and deploys a deliberate setup screen when these values are absent; a successful Pages deployment does not prove Firebase connectivity.
2. **Rules deployment:** review the selected Firebase project ID, run the emulator suite, then deploy Firestore and Storage rules only to the dedicated inventory project. No production rules have been deployed by this repository workflow.
3. **Authorization completion:** this branch implements office scoping for offices, assets, serial indexes, movements, linked custody/document/maintenance-part records, maintenance records, purchase records, spare-parts records with `officeId`, and Storage attachments. Do not deploy until CI passes, the PR is reviewed, and the dedicated Firebase project is confirmed. Legacy IT-manager profiles must be assigned offices by the super administrator before access is restored. A trusted create-only profile provisioning CLI remains available; Authentication account creation is a separate identity-admin operation.
4. **App Check and privileged sign-in:** configure and verify App Check per supported platform, enforce MFA for privileged accounts where supported, and test all production clients before enforcement.
5. **Data operations:** complete the serial reservation backfill, configure scheduled backups, and perform a documented restore drill before bulk import.
6. **Operational validation:** configure monitoring/alerts and verify Android, Windows, and Web builds on real target devices.

Never reuse or deploy to a meteorological production Firebase project. Never put service-account JSON, private keys, or Admin SDK credentials in the Flutter client, GitHub Variables, or repository.

## GitHub Pages web configuration

The Pages workflow reads these repository Actions Variables:

- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_STORAGE_BUCKET`

Set them under repository Settings → Secrets and variables → Actions → Variables using the Web app configuration from the dedicated inventory Firebase project. These are client configuration identifiers, not Admin SDK credentials.

Until all six values are configured, the deployed site intentionally shows a Firebase setup screen. Native Android/Windows builds require their own FlutterFire platform configuration. This setup does not create a Firebase project, enable services, provision users, or deploy security rules.


## ضوابط مخزون قطع الغيار

- المخزون مملوك لمكتب محدد عبر `officeId`؛ مدير المكتب لا يقرأ ولا يضيف ولا يصرف من مخزون مكتب آخر. المدير العام يحتفظ بالوصول الشامل.
- السجلات التاريخية التي لا تحتوي `officeId` تبقى للمدير العام فقط ولا يسمح باستخدامها في عملية صرف.
- الصرف عملية مترابطة غير قابلة للتجزئة: يجب أن تنقص كمية القطعة، وترتفع `partsCost` في طلب الصيانة، ويُنشأ سجل `maintenance_parts` واحد يحمل `lastUsageId` نفسه على القطعة والطلب.
- قواعد Firestore تستخدم حالة ما بعد المعاملة للتحقق من تطابق القطعة وطلب الصيانة والأصل والمكتب، ومن أن الكمية انخفضت بمقدار المصروف وأن تكلفة القطع زادت بالقيمة الدقيقة نفسها.
- لا يسمح بتعديل/حذف سجل الصرف، ولا بتعديل رصيد المخزون أو `partsCost` منفرداً. إعادة التوريد/التصحيح تحتاج مساراً إدارياً مستقلاً ومراجعة أمنية قبل إتاحته.


**Maintenance query boundary:** `maintenance_records.officeId` is the queryable tenant boundary for manager reads. All client creation and update paths still verify that the referenced asset belongs to that office; records without `officeId` remain administrator-only. Manager UI filters open statuses after the office-scoped query to avoid combining multiple Firestore `in` filters beyond the 30-disjunction limit.


## إعادة توريد مخزون قطع الغيار

- كل إعادة توريد تنشئ سجلاً append-only في `spare_part_receipts` يحمل القطعة والمكتب والكمية قبل وبعد التوريد وتكلفة الشراء للوحدة والإجمالي والمورد والملاحظات وتاريخ الاستلام ووقت التسجيل وهوية المنفذ من جلسة Firebase الموثقة.
- يجب أن يُنشأ إيصال التوريد وتُحدّث كمية القطعة والمورد وتكلفة الوحدة الحالية في معاملة Firestore واحدة. قواعد Firestore تتحقق من تطابق المكتب والقطعة والمنفذ ومعرّف الإيصال ومن معادلة الكمية والتكلفة.
- يحتفظ الإيصال بتكلفة الشراء الفعلية للدفعة، ويعكس حقل `unitCost` في سجل القطعة تكلفة آخر دفعة مورّدة. لا يُعاد احتساب متوسط مرجح على العميل.
- لا يسمح بزيادة الرصيد أو تغيير المورد أو متوسط التكلفة دون إيصال مطابق، ولا يسمح بتعديل أو حذف إيصالات التوريد. السجلات مقروءة ضمن نطاق المكتب، والمدير العام يملك القراءة الشاملة.


## سجل حركة المخزون والتقارير المالية

- شاشة مخزون قطع الغيار تعرض سجل حركة لكل قطعة، ويجمع إيصالات التوريد غير القابلة للتعديل مع حركات الصرف المرتبطة بطلبات الصيانة.
- يُسجل منفذ الصرف في maintenance_parts.createdBy من Firebase Auth، وتفرض القواعد تطابقه مع request.auth.uid. إيصالات التوريد تتبع الضابط نفسه.
- قراءة سجل الصرف تعتمد على officeId المثبت عند الإنشاء بعد التحقق من تطابق القطعة وطلب الصيانة والأصل؛ السجلات غير قابلة للتعديل أو الحذف، والاستعلامات تتطلب نطاق المكتب والقطعة.
- التقرير يعرض الرصيد الافتتاحي المحسوب، الوارد والمنصرف، الرصيد الحالي، تكلفة التوريد، قيمة الصرف، وأسماء الموردين. لا يُنشأ سجل افتتاحي وهمي للبيانات القديمة.
- لا توجد تسوية أو حذف أو تعديل مالي من واجهة العميل. أي تصحيح مستقبلي يجب أن يكون حركة عكسية/تسوية جديدة بمراجعة أمنية، مع إبقاء السجل الأصلي محفوظاً.


## حدود تقارير حركة المخزون

- تقارير الفترة تقرأ إيصالات التوريد وسجلات الصرف الموجودة فقط، وتُقيّد الاستعلامات أولاً بـ `officeId` للمكاتب النشطة المصرح بها. لا يتيح التقرير استعلاماً عاماً لمدير المكتب.
- المدير العام يقرأ جميع المكاتب، ومدير تقنية المعلومات يقرأ مكاتبه النشطة المسندة إليه فقط. اختيار مكتب خارج نطاق الصلاحية يُرفض داخل repository قبل القراءة.
- التقرير read-only؛ لا يكتب أو يحدّث أو يحذف إيصالاً أو حركة صرف. اختيار المورد يفلتر الوارد فقط لأن سجلات الصرف الحالية لا تحفظ مصدر الدفعة، ولا يجوز استنتاج المورد من آخر مورد للقطعة.
- بيانات المورد في التقرير تمثل مورد إيصال التوريد، ولا تُستخدم لإسناد تكلفة الصرف إلى المورد دون تطبيق تتبع دفعات/تشغيلات مستقل.


## فهارس وتقسيم قراءة تقارير المخزون

- تقييد استعلامات التقرير بالفترة الزمنية داخل Firestore قبل جلب النتائج، مع pagination باستخدام cursor وحد 500 سجل للصفحة.
- للمكاتب المسندة، ينفذ التقرير استعلاماً لكل مكتب نشط بدلاً من قائمة `whereIn` غير محدودة؛ ويُجزّأ التحقق من المكاتب إلى دفعات من 30 معرفاً.
- فهارس مركبة: `spare_part_receipts(officeId ASC, receivedAt ASC)` و`maintenance_parts(officeId ASC, usedAt ASC)`. يجب نشرها في بيئة Firebase بعد الموافقة المنفصلة، ولم يتم نشرها هنا.
- تصدير XLSX يتم على البيانات التي اجتازت فحوص الصلاحية والفترة والمرشحات فقط، ولا يمنح الملف صلاحيات وصول إضافية إلى قاعدة البيانات.


- تعرض التقارير مقارنة شهرية وسنوية مشتقة من حركات الفترة والمكتب المصرح بهما. فلتر المورد يقيّد التوريد فقط ولا يحذف الصرف من المقارنة.
- يحتوي XLSX على تفاصيل الحركات ومجاميع شهرية وسنوية؛ لا يضيف صلاحية أو مسار كتابة إلى السجل المالي.


## ضوابط تتبع دفعات قطع الغيار

- التوريد ينشئ إيصالاً ودفعة ثابتة ورصيد دفعة في معاملة واحدة. قواعد Firestore تربط معرف الإيصال والدفعة والقطعة والمكتب والمنفذ والكمية والتكلفة باستخدام حالة ما بعد المعاملة.
- بيانات الدفعة والإيصال والتخصيصات append-only. أرصدة الدفعات وحدها قابلة للتخفيض ضمن صرف صحيح، ويجب أن يطابق التخفيض سطر التخصيص نفسه؛ لا يمكن رفع رصيد دفعة أو حذفه من العميل.
- سجل التخصيص `spare_part_allocations/{usageId}` وثيق الصلة بسجل `maintenance_parts/{usageId}` ويحمل خطوط FIFO. القواعد تتحقق من تطابق مجموع كميات الخطوط وتكاليفها مع سجل الصرف، وتربط كل دفعة برصيدها وإيصالها ومكتبها.
- الرصيد التاريخي غير المنسوب يستهلك قبل الدفعات الجديدة. لا يحمل مورداً أو تكلفة مفترضة؛ يسجل `costAttributionComplete=false` عندما يدخل في الصرف. ويُحتسب الجزء غير المنسوب بتكلفة صفر موثقة بدلاً من نسبة سعر آخر توريد إليه.
- كل قراءة وكتابة للمجموعات الجديدة محكومة بـ `officeId`: المدير العام شامل، ومدير المكتب يقتصر على المكاتب النشطة المسندة إليه. معرف المنفذ يستمد من جلسة Firebase Auth.
- تقتصر حركة الصرف الواحدة على سطرين تخصيص بسبب حدود تقييم قواعد Firestore؛ يجب تقسيم الحركة التي تتطلب مصادر أكثر إلى حركات أصغر. لا يؤثر هذا الحد على كمية الرصيد الإجمالية ولا يسمح بتجاوز المتاح.
- فهرس FIFO أضيف إلى `firestore.indexes.json` ولم يُنشر. نشر القواعد أو الفهارس إلى Firebase production ليس جزءاً من CI ولا يتم دون موافقة مستقلة.
