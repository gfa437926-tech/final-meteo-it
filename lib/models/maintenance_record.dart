import 'package:cloud_firestore/cloud_firestore.dart';

enum MaintenanceStatus { open, inProgress, completed, cancelled }
extension MaintenanceStatusLabel on MaintenanceStatus {
  String get label => switch (this) {
    MaintenanceStatus.open => 'مفتوحة',
    MaintenanceStatus.inProgress => 'قيد التنفيذ',
    MaintenanceStatus.completed => 'مكتملة',
    MaintenanceStatus.cancelled => 'ملغاة',
  };
}

class MaintenanceRecord {
  const MaintenanceRecord({required this.id, required this.assetId, required this.assetLabel, this.officeId = '',
    required this.title, required this.description, required this.priority, required this.status,
    required this.reportedAt, this.technician = '', this.cost = 0, this.resolution = '', this.previousAssetStatus = 'available'});
  final String id, assetId, assetLabel, officeId, title, description, priority, technician, resolution, previousAssetStatus;
  final MaintenanceStatus status;
  final DateTime reportedAt;
  final double cost;

  Map<String, Object?> toMap() => {
    'assetId': assetId, 'assetLabel': assetLabel, 'officeId': officeId, 'title': title.trim(),
    'description': description.trim(), 'priority': priority, 'status': status.name,
    'reportedAt': Timestamp.fromDate(reportedAt), 'technician': technician.trim(),
    'cost': cost, 'resolution': resolution.trim(), 'previousAssetStatus': previousAssetStatus,
  };

  factory MaintenanceRecord.fromMap(String id, Map<String, dynamic> map) => MaintenanceRecord(
    id: id, assetId: map['assetId'] as String? ?? '', assetLabel: map['assetLabel'] as String? ?? '', officeId: map['officeId'] as String? ?? '',
    title: map['title'] as String? ?? '', description: map['description'] as String? ?? '',
    priority: map['priority'] as String? ?? 'normal',
    status: MaintenanceStatus.values.firstWhere((s) => s.name == map['status'], orElse: () => MaintenanceStatus.open),
    reportedAt: (map['reportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    technician: map['technician'] as String? ?? '', cost: (map['cost'] as num?)?.toDouble() ?? 0,
    resolution: map['resolution'] as String? ?? '', previousAssetStatus: map['previousAssetStatus'] as String? ?? 'available',
  );
}
