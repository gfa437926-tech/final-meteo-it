# Data dictionary (initial)

## offices
`id, name, building, directorate, department, room, manager, active, createdAt`

## assets
`id, assetTag, category, brand, model, modelNumber, serialNumber, status, officeId, custodianId, receivedAt, purchaseDate, warrantyUntil, notes`

## computer specifications
`cpuManufacturer, cpuModel, cpuGeneration, cpuCores, cpuThreads, cpuBaseGHz, cpuTurboGHz, ramModules[], storageDevices[], gpu, gpuMemory, operatingSystem, osVersion, macAddresses[]`

## monitor specifications
`displaySizeInches, resolution, panelType, refreshRateHz, ports[]`

## printer specifications
`technology, functions[], colorMode, paperSizes[], ppm, memoryMB, tonerModel, ipAddress, connectivity[]`

## custody_cards
`id, cardNumber, officeId, custodianId, openedAt, status, notes`

## movement records
`id, assetId, fromOfficeId, toOfficeId, fromCustodianId, toCustodianId, movedAt, documentNumber, reason, actorId`


## maintenance_records
`assetId, assetLabel, title, description, priority, status, reportedAt, technician, resolution, cost, partsCost, previousAssetStatus, completedAt`

## spare_parts
`name, sku, quantity, minimumQuantity, unitCost, supplier, createdAt, updatedAt`

## maintenance_parts
`partId, partName, maintenanceId, assetId, quantity, unitCost, totalCost, notes, usedAt`

## purchase_records
`assetId, assetLabel, supplier, invoiceNumber, purchaseDate, warrantyUntil, totalCost, notes`

## asset_movements
`assetId, assetLabel, movementType, occurredAt, maintenanceId, notes, cost, fromEmployee, toEmployee, fromOffice, toOffice`

> Inventory consumption is recorded transactionally: stock is reduced only when the maintenance ticket is still open or in progress and sufficient quantity is available. The issued parts cost is accumulated separately in `maintenance_records.partsCost`; service history displays it separately from repair/labour cost.


## spare_parts/{partId}

- `name`, `sku`, `quantity`, `minimumQuantity`, `unitCost`, `supplier`, `createdAt`, `updatedAt`

## maintenance_parts/{usageId}

Append-only consumption event: `partId`, `partName`, `maintenanceId`, `assetId`, `quantity`, `unitCost`, `totalCost`, `notes`, `usedAt`.
