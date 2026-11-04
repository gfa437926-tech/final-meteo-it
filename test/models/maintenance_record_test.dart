import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_it_assets/models/maintenance_record.dart';

void main() {
  test('maintenance record round-trips status, priority and previous asset status', () {
    final date = DateTime.utc(2026, 11, 5);
    final record = MaintenanceRecord(
      id: 'M-1', assetId: 'A-1', assetLabel: 'Dell OptiPlex',
      title: 'تعطل مزود الطاقة', description: 'لا يعمل الجهاز',
      priority: 'high', status: MaintenanceStatus.open, reportedAt: date,
      technician: 'فني الاختبار', previousAssetStatus: 'assigned',
    );
    final restored = MaintenanceRecord.fromMap('M-1', record.toMap());
    expect(restored.status, MaintenanceStatus.open);
    expect(restored.priority, 'high');
    expect(restored.previousAssetStatus, 'assigned');
    expect(restored.reportedAt.isAtSameMomentAs(date), isTrue);
    expect(restored.technician, 'فني الاختبار');
  });

  test('unknown maintenance status safely falls back to open', () {
    final restored = MaintenanceRecord.fromMap('M-2', {
      'reportedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 5)),
      'status': 'unknown',
    });
    expect(restored.status, MaintenanceStatus.open);
    expect(restored.cost, 0);
  });
}
