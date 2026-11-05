import 'package:flutter_test/flutter_test.dart';
import 'package:metra_it_assets/models/asset.dart';

void main() {
  test('category labels are localized', () {
    expect(AssetCategory.laptop.label, 'لابتوب');
    expect(AssetCategory.monitor.label, 'شاشة');
  });

  test('status labels are localized', () {
    expect(AssetStatus.maintenance.label, 'صيانة');
    expect(AssetStatus.assigned.label, 'موزع');
  });

  test('asset serializes stable identity and category', () {
    const asset = Asset(
      id: 'IT-000001',
      category: AssetCategory.desktop,
      brand: 'Dell',
      model: 'OptiPlex',
      serialNumber: 'SN-EXAMPLE',
      status: AssetStatus.available,
    );
    final map = asset.toMap();
    expect(map['id'], 'IT-000001');
    expect(map['category'], 'desktop');
    expect(map['serialNumber'], 'SN-EXAMPLE');
  });
  test('asset round-trips optional specifications and received date', () {
    final receivedAt = DateTime.utc(2026, 10, 12, 9, 30);
    const asset = Asset(
      id: 'IT-000002',
      category: AssetCategory.laptop,
      brand: ' Lenovo ',
      model: ' ThinkPad ',
      serialNumber: ' SN-002 ',
      status: AssetStatus.available,
      cpu: 'Core i7',
      ram: '16 GB',
      storage: '512 GB SSD',
      officeId: 'office-1',
      officeName: 'تقنية المعلومات',
    );
    final map = asset.toMap()..['receivedAt'] = receivedAt.toIso8601String();
    final restored = Asset.fromMap('IT-000002', map);

    expect(restored.brand, 'Lenovo');
    expect(restored.model, 'ThinkPad');
    expect(restored.serialNumber, 'SN-002');
    expect(restored.cpu, 'Core i7');
    expect(restored.ram, '16 GB');
    expect(restored.storage, '512 GB SSD');
    expect(restored.officeId, 'office-1');
    expect(restored.receivedAt, receivedAt);
  });

  test('unknown category and status values fall back safely', () {
    final restored = Asset.fromMap('legacy-1', {
      'category': 'unknown-category',
      'brand': 'Legacy',
      'model': 'Device',
      'serialNumber': 'OLD-1',
      'status': 'unknown-status',
    });

    expect(restored.category, AssetCategory.other);
    expect(restored.status, AssetStatus.available);
  });

}
