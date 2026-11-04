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
