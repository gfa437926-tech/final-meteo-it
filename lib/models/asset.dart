enum AssetCategory { desktop, laptop, monitor, printer, scanner, network, storage, ups, accessory, other }
enum AssetStatus { available, assigned, maintenance, damaged, retired, returned }

extension AssetCategoryLabel on AssetCategory {
  String get label => switch (this) {
    AssetCategory.desktop => 'كمبيوتر مكتبي', AssetCategory.laptop => 'لابتوب',
    AssetCategory.monitor => 'شاشة', AssetCategory.printer => 'طابعة',
    AssetCategory.scanner => 'ماسح', AssetCategory.network => 'معدات شبكة',
    AssetCategory.storage => 'وحدة تخزين', AssetCategory.ups => 'UPS',
    AssetCategory.accessory => 'ملحق', AssetCategory.other => 'أخرى',
  };
}
extension AssetStatusLabel on AssetStatus {
  String get label => switch (this) {
    AssetStatus.available => 'متوفر', AssetStatus.assigned => 'موزع',
    AssetStatus.maintenance => 'صيانة', AssetStatus.damaged => 'تالف',
    AssetStatus.retired => 'مستبعد', AssetStatus.returned => 'معاد',
  };
}
class Asset {
  const Asset({required this.id, required this.category, required this.brand, required this.model,
    required this.serialNumber, required this.status, this.cpu, this.ram, this.storage,
    this.officeId, this.officeName, this.receivedAt});
  final String id;
  final AssetCategory category;
  final String brand, model, serialNumber;
  final AssetStatus status;
  final String? cpu, ram, storage, officeId, officeName;
  final DateTime? receivedAt;

  Map<String, Object?> toMap() => {
    'id': id, 'category': category.name, 'brand': brand.trim(), 'model': model.trim(),
    'serialNumber': serialNumber.trim(), 'status': status.name, 'cpu': cpu,
    'ram': ram, 'storage': storage, 'officeId': officeId, 'officeName': officeName,
    'receivedAt': receivedAt?.toIso8601String(),
  };

  factory Asset.fromMap(String id, Map<String, dynamic> map) => Asset(
    id: id,
    category: AssetCategory.values.firstWhere((e) => e.name == map['category'], orElse: () => AssetCategory.other),
    brand: map['brand'] as String? ?? '',
    model: map['model'] as String? ?? '',
    serialNumber: map['serialNumber'] as String? ?? '',
    status: AssetStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => AssetStatus.available),
    cpu: map['cpu'] as String?, ram: map['ram'] as String?, storage: map['storage'] as String?,
    officeId: map['officeId'] as String?, officeName: map['officeName'] as String?,
    receivedAt: DateTime.tryParse(map['receivedAt'] as String? ?? ''),
  );
}
