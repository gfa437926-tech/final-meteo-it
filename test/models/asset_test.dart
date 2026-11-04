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
}
