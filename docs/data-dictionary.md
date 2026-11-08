# Data dictionary (initial)

## users (authorization fields)
`uid, displayName, email, role, isActive, officeIds[], createdAt, updatedAt`

- `admin`: global administrator; stores an empty `officeIds` list.
- `it_manager`: assigned to 1–20 office IDs. The list is written only by a global administrator.
- A legacy profile without `officeIds` is treated as unassigned until reviewed.

## offices
`id, name, building, directorate, department, room, manager, phone, notes, isActive`

Office reads are restricted to assigned managers; only the global administrator can create or update office catalogue records. Office deletion is disabled.

## assets
`id, assetTag, category, brand, model, modelNumber, serialNumber, status, officeId, officeName, custodianId, receivedAt, purchaseDate, warrantyUntil, notes`

- Every newly created asset must carry an `officeId` referencing an active office.
- Assets without `officeId` are legacy/unassigned and remain visible only to the global administrator.
- An IT manager can update an asset only while authorized for its current and resulting office. Transfers require authorization for both offices.

## computer specifications
`cpuManufacturer, cpuModel, cpuGeneration, cpuCores, cpuThreads, cpuBaseGHz, cpuTurboGHz, ramModules[], storageDevices[], gpu, gpuMemory, operatingSystem, osVersion, macAddresses[]`

## monitor specifications
`displaySizeInches, resolution, panelType, refreshRateHz, ports[]`

## printer specifications
`technology, functions[], colorMode, paperSizes[], ppm, memoryMB, tonerModel, ipAddress, connectivity[]`

## custody_cards
`id, assetId, officeId, assetLabel, employeeName, officeName, assignedAt, status, approvalStatus, approvedBy?, approvedAt?, rejectedBy?, rejectedAt?, rejectionReason?, notes`

New custody cards derive `officeId` from the linked asset. Manager queries must include assigned active `officeId` values; legacy cards without `officeId` remain global-administrator-only.

## movement records
`id, assetId, officeId, fromOfficeId, toOfficeId, fromCustodianId, toCustodianId, movedAt, documentNumber, reason, actorId`

Movement reads/writes are checked against the related office(s). Every movement created by asset, custody, purchase, or maintenance workflows carries the linked asset's `officeId`; transfers additionally validate both source and destination offices.


## maintenance_records
`assetId, officeId, assetLabel, title, description, priority, status, reportedAt, technician, resolution, cost, partsCost, previousAssetStatus, completedAt`

Every maintenance record must reference an existing asset and carry the same `officeId` as that asset. The application derives `officeId` from the linked asset during creation; Firestore rules independently verify the relationship and enforce office-scoped reads and writes. Legacy records without a valid asset/office link are not available to IT managers. Record deletion is disabled.

## spare_parts
`name, sku, officeId, quantity, minimumQuantity, unitCost, supplier, createdAt, updatedAt`

Stock records must carry `officeId` for IT-manager access. Legacy records without it remain admin-only.

## maintenance_parts
`partId, partName, maintenanceId, assetId, quantity, unitCost, totalCost, notes, usedAt`

## purchase_records
`assetId, officeId, assetLabel, supplier, invoiceNumber, purchaseDate, warrantyUntil, totalCost, notes, createdAt`

Every purchase record must reference an existing asset and carry the same `officeId` as that asset. The application derives `officeId` from the linked asset during creation; Firestore rules independently verify the relationship and enforce office-scoped reads and writes. Legacy records without a valid asset/office link are not available to IT managers. Record deletion is disabled.

## asset_movements
`assetId, assetLabel, officeId, fromOfficeId, toOfficeId, movementType, occurredAt, maintenanceId, notes, cost, fromEmployee, toEmployee, fromOffice, toOffice`

Movement records are visible only to the global administrator or managers assigned to the linked office. A transfer write requires access to both `fromOfficeId` and `toOfficeId`.

> Inventory consumption is recorded transactionally: stock is reduced only when the maintenance ticket is still open or in progress and sufficient quantity is available. The issued parts cost is accumulated separately in `maintenance_records.partsCost`; service history displays it separately from repair/labour cost.


## spare_parts/{partId}

- `name`, `sku`, `quantity`, `minimumQuantity`, `unitCost`, `supplier`, `createdAt`, `updatedAt`

## maintenance_parts/{usageId}

Append-only consumption event: `partId`, `partName`, `maintenanceId`, `assetId`, `officeId`, `quantity`, `unitCost`, `totalCost`, `notes`, `usedAt`, `createdBy`. The office must match the part, maintenance ticket, and linked asset; `createdBy` is the authenticated Firebase UID. The event is immutable.


## asset_documents
`assetId, officeId, purchaseRecordId?, fileName, documentType, storagePath, contentType, sizeBytes, uploadedBy, createdAt`

Supported document types: `invoice`, `warranty`, `handover`, `maintenance`, `photo`, and `other`. File bytes are stored in Firebase Storage; the Firestore record stores metadata and a private storage path.


## import_batches

Append-only CSV import audit record: `sourceName, createdBy, createdAt, completedAt, totalRows, attemptedRows, succeededRows, failedRows, skippedInvalidRows, status, rowErrors[]`. Only active admin/IT-manager accounts can create records, the actor UID must match the signed-in user, and clients cannot update or delete a batch record.


## Authorization rollout notes

- `custody_cards`, `asset_documents` metadata, and `maintenance_parts` usage records are authorized through their `assetId` and the linked asset's `officeId`.
- `asset_documents` metadata must carry the same `officeId` as its linked asset. Firebase Storage paths use `asset_documents/{assetId}/{fileName}`; Storage rules resolve the Firestore asset and its active office before allowing manager reads or uploads.
- `maintenance_records` and `purchase_records` are office-scoped through their linked asset. Each record must carry an `officeId` matching the asset's current office; clients cannot forge this relationship, and deletes are denied.


## مخزون قطع الغيار وصرفها

- كل سجل في `spare_parts` جديد يجب أن يحمل `officeId` لمكتب نشط، وتُعزل قراءته بحسب المكاتب المسندة إلى مدير المكتب. السجلات القديمة التي لا تحمل `officeId` تبقى متاحة للمدير العام فقط ولا تدخل في الصرف.
- كل سجل صرف في `maintenance_parts` يحمل `partId` و`maintenanceId` و`assetId` و`officeId` و`quantity` و`unitCost` و`totalCost` و`usedAt`. يجب أن تتطابق المكاتب الثلاثة: القطعة وطلب الصيانة والأصل.
- عملية الصرف تنشئ سجل الاستخدام بمعرّف ثابت، وتحدّث رصيد القطعة (`quantity` و`lastUsageId`) وتكلفة القطع في طلب الصيانة (`partsCost` و`lastPartsUsageId`) ضمن معاملة Firestore واحدة. لا يقبل العميل أي تحديث منفرد للمخزون أو التكلفة، ولا تعديل/حذف سجل الاستخدام بعد إنشائه.
- الكمية المصروفة عدد صحيح موجب، وتكلفة الاستخدام تساوي `quantity × unitCost`، ويجب أن يبقى طلب الصيانة مفتوحاً وأن يكون الأصل في حالة الصيانة.


## spare_part_receipts

سجل توريد غير قابل للتعديل أو الحذف: `partId, officeId, quantity, quantityBefore, quantityAfter, unitCost, totalCost, supplier, notes, receivedAt, createdAt, createdBy`. يُنشأ فقط ضمن معاملة واحدة تحدث سجل `spare_parts` المرتبط. `createdBy` هو UID للمستخدم المصادق عليه، و`officeId` يطابق مكتب القطعة. تُحفظ تكلفة شراء الدفعة في الإيصال، ويُحدّث `spare_parts.unitCost` بسعر شراء آخر دفعة. لا يسمح بزيادة الكمية أو تعديل المورد/متوسط التكلفة دون إيصال صحيح.


## سجل حركة مخزون قطع الغيار والتقارير

- تُعرض حركة القطعة بدمج إيصالات التوريد (الوارد) مع سجلات الصرف المرتبطة بطلبات الصيانة، مع ترتيبها زمنياً وعرض الكمية والتكلفة والمورد وطلب الصيانة.
- تقارير القطعة تحسب إجمالي الوارد والمنصرف وتكلفة الشراء وقيمة الصرف والموردين والرصيد الحالي. الرصيد الافتتاحي يُستنتج من الرصيد الحالي مطروحاً منه الوارد ومضافاً إليه المنصرف؛ لا تُنشأ حركات افتتاحية مصطنعة للسجلات التاريخية.
- سجل الصرف يحمل createdBy من جلسة Firebase الموثقة، وتتحقق القواعد من مطابقته للمستخدم المنفذ. إيصالات التوريد تحمل createdBy بالطريقة نفسها.
- الاستعلامات مقيدة بـ partId وofficeId. المدير العام يقرأ جميع المكاتب، ومدير تقنية المعلومات يقرأ سجلات المكاتب النشطة المسندة إليه فقط.
- إيصالات التوريد وسجلات الصرف append-only؛ تمنع قواعد Firestore تحديثها أو حذفها. أي تصحيح لاحق يحتاج مسار تسوية منفصلاً موثقاً ولا يعدّل السجل الأصلي.


## تقارير التوريد والصرف حسب الفترة والمورد والمكتب

- شاشة التقرير تقبل فترة زمنية وتجمع إيصالات `spare_part_receipts` حسب `receivedAt` وسجلات `maintenance_parts` حسب `usedAt`.
- المقارنة حسب المكتب تعرض كميات الوارد وتكلفته مقابل كميات الصرف وقيمته لكل مكتب ضمن الفترة. يمكن تضييق التقرير إلى مكتب واحد.
- تحليل الموردين يقتصر على الوارد، لأن إيصال التوريد وحده يحمل المورد. حركات الصرف لا تُنسب إلى مورد محدد في غياب تتبع الدفعات/التشغيلات، ويظهر ذلك للمستخدم صراحة.
- فلتر المورد يقيّد مؤشرات الوارد وتفصيل المورد، ولا يخفي الصرف المقابل؛ وبذلك تبقى مقارنة الوارد بالمنصرف في المكتب والفترة واضحة.
- لا تُكتب أي بيانات أثناء إنشاء التقرير. جميع الأرقام مشتقة من السجلات الأصلية append-only.


## تحسين أداء تقارير المخزون والتصدير

- تُفلتر إيصالات التوريد بتاريخ `receivedAt` وسجلات الصرف بتاريخ `usedAt` داخل Firestore قبل القراءة، بدلاً من تحميل تاريخ المكتب كاملاً ثم ترشيحه في الذاكرة.
- تستخدم القراءة صفحات متتابعة بحد أقصى 500 سجل لكل صفحة، مرتبة زمنياً، وتنفذ استعلاماً منفصلاً لكل مكتب مفوض لتجنب حد disjunction في `whereIn`.
- أضيف `firestore.indexes.json` وفُعّل مرجعه في `firebase.json` لفهارس المكتب/التاريخ لإيصالات التوريد وسجلات الصرف. إضافة الملف لا تنشر الفهارس إلى Firebase تلقائياً.
- يمكن تصدير نتيجة التقرير المرشحة إلى XLSX، وتشمل التاريخ والمكتب ونوع الحركة والقطعة والكمية والتكلفة والمورد وطلب الصيانة والمنفذ ومعرف السجل.
- التصدير نسخة تقريرية فقط؛ لا يغير السجلات الأصلية ولا يحذفها.


- يضيف التقرير مقارنتين تجميعيّتين شهرية وسنوية ضمن الفترة المختارة، ويطبق فلتر المورد على الوارد فقط مع إبقاء الصرف المقابل ظاهراً.
- يتضمن ملف XLSX ورقتين إضافيتين للمقارنة الشهرية والسنوية إلى جانب ورقة تفاصيل الحركات، مع نفس فلاتر المكتب والمورد والفترة.


## تتبع دفعات قطع الغيار FIFO

- عند إنشاء قطعة جديدة، تكون كمية البداية في `untrackedQuantity` لأنها لا تستند إلى إيصال يمكن التحقق منه. القطع التاريخية التي لا تحمل الحقل تعامل بالطريقة نفسها: كامل رصيدها الحالي غير منسوب حتى يبدأ الصرف.
- كل توريد جديد ينشئ إيصالاً في `spare_part_receipts` ودفعة ثابتة في `spare_part_lots` ورصيداً تشغيلياً في `spare_part_lot_balances` ضمن معاملة واحدة. معرف الدفعة هو معرف الإيصال.
- `spare_part_lots` تحفظ المورد وتكلفة الشراء والكمية الأصلية وتاريخ الاستلام، وهي غير قابلة للتعديل أو الحذف.
- `spare_part_lot_balances` تحفظ الكمية المتبقية للدفعة. لا تتغير إلا ضمن معاملة صرف مرتبطة بتخصيص موثق، ولا يمكن حذفها.
- `spare_part_allocations/{usageId}` سجل append-only واحد لكل حركة صرف، ويحمل `lines[]` لتوزيع الكمية على الرصيد التاريخي والدفعات. كل سطر يحدد `sourceType` والدفعة/الإيصال والمورد والكمية والتكلفة عند توفرها.
- الرصيد `legacy_untracked` يستهلك أولاً ولا يحمل مورداً أو تكلفة مفترضة. يسجل الصرف `legacyQuantity` و`costAttributionComplete` في `maintenance_parts`. قيمة التكلفة المنسوبة لهذا الجزء صفر لأنها غير موثقة، ولا تُستنتج من سعر آخر توريد.
- بعد نفاد الرصيد التاريخي، يوزع الصرف FIFO حسب `receivedAt` ثم `createdAt`. يجب أن تطابق كميات خطوط التخصيص كمية الصرف، وتطابق تكلفتها قيمة الصرف.
- لضبط ميزانية تحقق Firestore Rules، تحتوي حركة الصرف الواحدة على سطرين تخصيص كحد أقصى. إذا احتاجت الحركة أكثر من اثنين مصادر، يرفض الصرف برسالة واضحة ويجب تقسيمه إلى حركات أصغر على طلب الصيانة نفسه.
- التقرير والتصدير يقرآن خطوط التخصيص لعرض المورد الفعلي وتكلفة كل مصدر. اختيار المورد في التقرير يفلتر أيضاً جزء الصرف المنسوب إلى ذلك المورد، ولا ينسب الرصيد التاريخي إلى أي مورد.
- فهرس FIFO المركب: `spare_part_lots(officeId ASC, partId ASC, receivedAt ASC, createdAt ASC)`. يضاف إلى ملف الفهارس فقط؛ لا يعني ذلك نشره إلى Firebase.
