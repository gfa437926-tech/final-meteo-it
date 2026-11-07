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
`id, assetId, assetLabel, employeeName, officeName, assignedAt, status, approvalStatus, approvedBy?, approvedAt?, rejectedBy?, rejectedAt?, rejectionReason?, notes`

## movement records
`id, assetId, officeId, fromOfficeId, toOfficeId, fromCustodianId, toCustodianId, movedAt, documentNumber, reason, actorId`

Movement reads/writes are checked against the related office(s).


## maintenance_records
`assetId, assetLabel, title, description, priority, status, reportedAt, technician, resolution, cost, partsCost, previousAssetStatus, completedAt`

## spare_parts
`name, sku, officeId, quantity, minimumQuantity, unitCost, supplier, createdAt, updatedAt`

Stock records must carry `officeId` for IT-manager access. Legacy records without it remain admin-only.

## maintenance_parts
`partId, partName, maintenanceId, assetId, quantity, unitCost, totalCost, notes, usedAt`

## purchase_records
`assetId, assetLabel, supplier, invoiceNumber, purchaseDate, warrantyUntil, totalCost, notes`

## asset_movements
`assetId, assetLabel, officeId, fromOfficeId, toOfficeId, movementType, occurredAt, maintenanceId, notes, cost, fromEmployee, toEmployee, fromOffice, toOffice`

Movement records are visible only to the global administrator or managers assigned to the linked office. A transfer write requires access to both `fromOfficeId` and `toOfficeId`.

> Inventory consumption is recorded transactionally: stock is reduced only when the maintenance ticket is still open or in progress and sufficient quantity is available. The issued parts cost is accumulated separately in `maintenance_records.partsCost`; service history displays it separately from repair/labour cost.


## spare_parts/{partId}

- `name`, `sku`, `quantity`, `minimumQuantity`, `unitCost`, `supplier`, `createdAt`, `updatedAt`

## maintenance_parts/{usageId}

Append-only consumption event: `partId`, `partName`, `maintenanceId`, `assetId`, `quantity`, `unitCost`, `totalCost`, `notes`, `usedAt`.


## asset_documents
`assetId, purchaseRecordId?, fileName, documentType, storagePath, contentType, sizeBytes, uploadedBy, createdAt`

Supported document types: `invoice`, `warranty`, `handover`, `maintenance`, `photo`, and `other`. File bytes are stored in Firebase Storage; the Firestore record stores metadata and a private storage path.


## import_batches

Append-only CSV import audit record: `sourceName, createdBy, createdAt, completedAt, totalRows, attemptedRows, succeededRows, failedRows, skippedInvalidRows, status, rowErrors[]`. Only active admin/IT-manager accounts can create records, the actor UID must match the signed-in user, and clients cannot update or delete a batch record.


## Authorization rollout notes

- `custody_cards`, `asset_documents` metadata, and `maintenance_parts` usage records are authorized through their `assetId` and the linked asset's `officeId`.
- Firebase Storage paths use `asset_documents/{assetId}/{fileName}`; Storage rules resolve the Firestore asset before allowing reads or uploads.
- `maintenance_records` and `purchase_records` do not yet have client rules in this office-scoping phase. They remain unavailable to clients until a reviewed office/asset relationship and tests are added.
