import 'package:flutter_test/flutter_test.dart';
import 'package:metra_it_assets/services/custody_repository.dart';

void main() {
  test('custody record serializes normalized employee and office names', () {
    final assignedAt = DateTime.utc(2026, 11, 5, 10);
    const record = CustodyRecord(
      id: 'custody-1',
      assetId: 'asset-1',
      assetLabel: 'Dell OptiPlex',
      employeeName: '  أحمد محمد  ',
      officeName: '  قسم الشبكات  ',
      assignedAt: DateTime.utc(2026, 11, 5, 10),
      notes: '  تسليم أولي  ',
    );

    final map = record.toMap();
    expect(map['employeeName'], 'أحمد محمد');
    expect(map['officeName'], 'قسم الشبكات');
    expect(map['notes'], 'تسليم أولي');
    expect(map['assetId'], 'asset-1');
    expect(map['status'], 'active');
    expect(assignedAt.toIso8601String(), map['assignedAt']);
  });

  test('custody record restores persisted values and identity', () {
    final record = CustodyRecord.fromMap('custody-2', {
      'assetId': 'asset-2',
      'assetLabel': 'HP LaserJet',
      'employeeName': 'سارة',
      'officeName': 'الدعم الفني',
      'assignedAt': '2026-11-05T10:00:00.000Z',
      'notes': 'عهدة مؤقتة',
      'status': 'returned',
    });

    expect(record.id, 'custody-2');
    expect(record.assetId, 'asset-2');
    expect(record.assetLabel, 'HP LaserJet');
    expect(record.employeeName, 'سارة');
    expect(record.officeName, 'الدعم الفني');
    expect(record.assignedAt.isAtSameMomentAs(DateTime.utc(2026, 11, 5, 10)), isTrue);
    expect(record.status, 'returned');
  });
}
