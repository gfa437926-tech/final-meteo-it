import 'package:flutter_test/flutter_test.dart';
import 'package:metra_it_assets/models/office.dart';
void main(){
 test('office serialization preserves directory details',(){
  const office=Office(id:'o-1',name:'المكتب المركزي',directorate:'المديرية العامة',department:'تقنية المعلومات',building:'المبنى A',room:'12',manager:'مسؤول التقنية',phone:'0990000000');
  final restored=Office.fromMap(office.id,office.toMap());
  expect(restored.name,office.name);expect(restored.directorate,office.directorate);
  expect(restored.department,office.department);expect(restored.room,office.room);
  expect(restored.manager,office.manager);expect(restored.phone,office.phone);
 });
 test('office defaults to active when old record has no flag',(){
  final office=Office.fromMap('legacy',{'name':'مكتب'});
  expect(office.isActive,isTrue);
 });
}