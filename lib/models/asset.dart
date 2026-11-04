enum AssetCategory { desktop, laptop, monitor, printer, scanner, network, storage, ups, accessory, other }
enum AssetStatus { available, assigned, maintenance, damaged, retired, returned }

extension AssetCategoryLabel on AssetCategory {
  String get label => switch (this) {
    AssetCategory.desktop => 'كمبيوتر مكتبي',
    AssetCategory.laptop => 'لابتوب',
    AssetCategory.monitor => 'شاشة',
    AssetCategory.printer => 'طابعة',
    AssetCategory.scanner => 'ماسح',
    AssetCategory.network => 'معدات شبكة',
    AssetCategory.storage => 'وحدة تخزين',
    AssetCategory.ups => 'UPS',
    AssetCategory.accessory => 'ملحق',
    AssetCategory.other => 'أخرى',
  };
}

extension AssetStatusLabel on AssetStatus {
  String get label => switch (this) {
    AssetStatus.available => 'متوفر',
    AssetStatus.assigned => 'موزع',
    AssetStatus.maintenance => 'صيانة',
    AssetStatus.damaged => 'تالف',
    AssetStatus.retired => 'مستبعد',
    AssetStatus.returned => 'معاد',
  };
}

class Asset {
  const Asset({
    required this.id,
    required this.category,
    required this.brand,
    required this.model,
    required this.serialNumber,
    required this.status,
    this.cpu,
    this.ram,
    this.storage,
    this.officeId,
    this.officeName,
    this.receivedAt,
  });

  final String id;
  final AssetCategory category;
  final String brand;
  final String model;
  final String serialNumber;
  final AssetStatus status;
  final String? cpu;
  final String? ram;
  final String? storage;
  final String? officeId;
  final String? officeName;
  final DateTime? receivedAt;

  Map<String, Object?> toMap() => {
    'id': id, 'category': category.name, 'brand': brand, 'model': model,
    'serialNumber': serialNumber, 'status': status.name, 'cpu': cpu,
    'ram': ram, 'storage': storage, 'officeId': officeId,
    'officeName': officeName, 'receivedAt': receivedAt?.toIso8601String(),
  };
}
