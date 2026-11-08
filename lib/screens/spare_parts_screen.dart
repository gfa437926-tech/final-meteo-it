import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../services/spare_parts_repository.dart';
import '../services/office_repository.dart';

class SparePartsScreen extends StatefulWidget {
  const SparePartsScreen({super.key});

  @override
  State<SparePartsScreen> createState() => _SparePartsScreenState();
}

class _SparePartsScreenState extends State<SparePartsScreen> {
  final repository = SparePartsRepository();

  Future<void> _addPart() async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController();
    final sku = TextEditingController();
    final quantity = TextEditingController(text: '0');
    final minimum = TextEditingController(text: '1');
    final cost = TextEditingController(text: '0');
    final supplier = TextEditingController();
    final offices = (await OfficeRepository().watchOffices().first)
        .where((office) => office.isActive).toList();
    if (!mounted) return;
    if (offices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مكاتب نشطة مخولة لإضافة المخزون')),
      );
      name.dispose(); sku.dispose(); quantity.dispose(); minimum.dispose();
      cost.dispose(); supplier.dispose();
      return;
    }
    String? selectedOfficeId = offices.length == 1 ? offices.first.id : null;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
        title: const Text('إضافة قطعة غيار للمخزون'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedOfficeId,
                  decoration: const InputDecoration(labelText: 'المكتب'),
                  items: offices.map((office) => DropdownMenuItem(
                    value: office.id, child: Text(office.name),
                  )).toList(),
                  onChanged: (value) => setDialog(() => selectedOfficeId = value),
                  validator: (value) => value == null ? 'اختر المكتب' : null,
                ),
                const SizedBox(height: 10),
                _field(name, 'اسم القطعة'),
                _field(sku, 'رمز القطعة / SKU'),
                _field(quantity, 'الكمية الحالية', numeric: true),
                _field(minimum, 'حد التنبيه الأدنى', numeric: true),
                _field(cost, 'تكلفة القطعة الواحدة', numeric: true),
                _field(supplier, 'المورد (اختياري)', required: false),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (selectedOfficeId != null && form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('حفظ القطعة'),
          ),
        ],
      ),
      ),
    );
    if (saved == true) {
      try {
        await repository.addPart(
          id: const Uuid().v4(),
          officeId: selectedOfficeId!,
          name: name.text,
          sku: sku.text,
          quantity: int.parse(quantity.text),
          minimumQuantity: int.parse(minimum.text),
          unitCost: double.parse(cost.text),
          supplier: supplier.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت إضافة قطعة الغيار إلى المخزون')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذرت إضافة القطعة: $error')),
          );
        }
      }
    }
    name.dispose();
    sku.dispose();
    quantity.dispose();
    minimum.dispose();
    cost.dispose();
    supplier.dispose();
  }


  Future<void> _restock(QueryDocumentSnapshot<Map<String, dynamic>> part) async {
    final form = GlobalKey<FormState>();
    final quantity = TextEditingController(text: '1');
    final cost = TextEditingController(text: '0');
    final supplier = TextEditingController();
    final notes = TextEditingController();
    DateTime receivedAt = DateTime.now();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('إعادة توريد: ${part.data()['name'] ?? ''}'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _field(quantity, 'الكمية المستلمة', numeric: true),
                  _field(cost, 'تكلفة الوحدة عند الشراء', numeric: true),
                  _field(supplier, 'اسم المورد'),
                  _field(notes, 'ملاحظات (اختياري)', required: false),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: receivedAt,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) {
                          setDialog(() => receivedAt = DateTime(
                            picked.year, picked.month, picked.day,
                            receivedAt.hour, receivedAt.minute,
                          ));
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text('تاريخ الاستلام: ${receivedAt.toLocal().toString().split(' ').first}'),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('تأكيد إعادة التوريد'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      try {
        await repository.restock(
          partId: part.id,
          quantity: int.parse(quantity.text),
          unitCost: double.parse(cost.text),
          supplier: supplier.text,
          notes: notes.text,
          receivedAt: receivedAt,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تسجيل التوريد وتحديث الرصيد والتكلفة')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذرت إعادة التوريد: $error')),
          );
        }
      }
    }
    quantity.dispose();
    cost.dispose();
    supplier.dispose();
    notes.dispose();
  }

  Future<void> _consume(QueryDocumentSnapshot<Map<String, dynamic>> part) async {
    final form = GlobalKey<FormState>();
    final amount = TextEditingController(text: '1');
    final notes = TextEditingController();
    String? maintenanceId;
    final tickets = await repository.watchOpenTickets().first;
    if (!mounted) return;
    final openTickets = tickets.docs.where((ticket) {
      final status = ticket.data()['status'] as String? ?? '';
      return status == 'open' || status == 'inProgress';
    }).toList();
    if (openTickets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد طلبات صيانة مفتوحة لصرف القطع عليها')),
      );
      amount.dispose();
      notes.dispose();
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('صرف قطعة: ${part.data()['name'] ?? ''}'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'طلب الصيانة'),
                  items: openTickets.map((ticket) {
                    final data = ticket.data();
                    return DropdownMenuItem(
                      value: ticket.id,
                      child: Text('${data['title'] ?? 'طلب صيانة'} • ${data['assetLabel'] ?? ''}',
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (value) => setDialog(() => maintenanceId = value),
                  validator: (_) => maintenanceId == null ? 'اختر طلب الصيانة' : null,
                ),
                _field(amount, 'الكمية المصروفة', numeric: true),
                _field(notes, 'ملاحظات (اختياري)', required: false),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (maintenanceId != null && form.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('تأكيد الصرف'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && maintenanceId != null) {
      try {
        await repository.consume(
          partId: part.id,
          maintenanceId: maintenanceId!,
          quantity: int.parse(amount.text),
          notes: notes.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم صرف القطعة وتحديث رصيد المخزون')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر صرف القطعة: $error')),
          );
        }
      }
    }
    amount.dispose();
    notes.dispose();
  }




  String _movementSupplierSummary(Map<String, dynamic> event) {
    if (event['isIncoming'] == true || event['allocationLine'] == true) {
      return event['supplier']?.toString() ?? '';
    }
    final lines = event['allocationLines'];
    if (lines is! List) return 'قديم غير منسوب';
    final suppliers = <String>{};
    var hasLegacy = false;
    for (final line in lines) {
      if (line is! Map) continue;
      if (line['sourceType'] == 'legacy_untracked') hasLegacy = true;
      if (line['sourceType'] == 'lot' && line['supplier'] is String) {
        suppliers.add(line['supplier'] as String);
      }
    }
    final labels = suppliers.toList()..sort();
    if (hasLegacy) labels.add('رصيد تاريخي غير منسوب');
    return labels.join('، ');
  }

  List<Map<String, dynamic>> _filterMovementEvents(
    List<Map<String, dynamic>> events, {
    required String? selectedOffice,
    required String? selectedSupplier,
  }) {
    final result = <Map<String, dynamic>>[];
    for (final event in events) {
      if (selectedOffice != null && event['officeId'] != selectedOffice) continue;
      if (selectedSupplier == null) {
        result.add(event);
        continue;
      }
      if (event['isIncoming'] == true) {
        if (event['supplier'] == selectedSupplier) result.add(event);
        continue;
      }
      final rawLines = event['allocationLines'];
      if (rawLines is! List) continue;
      for (final rawLine in rawLines) {
        if (rawLine is! Map || rawLine['sourceType'] != 'lot' ||
            rawLine['supplier'] != selectedSupplier) {
          continue;
        }
        result.add({
          ...event,
          'quantity': (rawLine['quantity'] as num?)?.toInt() ?? 0,
          'unitCost': (rawLine['unitCost'] as num?)?.toDouble() ?? 0,
          'totalCost': (rawLine['totalCost'] as num?)?.toDouble() ?? 0,
          'supplier': rawLine['supplier'],
          'allocationLine': true,
        });
      }
    }
    return result;
  }

  Future<void> _exportMovementReport({
    required List<Map<String, dynamic>> events,
    required Map<String, String> officeNames,
    required String? selectedOffice,
    required String? selectedSupplier,
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final filtered = _filterMovementEvents(
      events,
      selectedOffice: selectedOffice,
      selectedSupplier: selectedSupplier,
    );

    final workbook = Excel.createExcel();
    final sheet = workbook['حركة المخزون'];
    sheet.appendRow([
      TextCellValue('التاريخ'),
      TextCellValue('المكتب'),
      TextCellValue('نوع الحركة'),
      TextCellValue('القطعة'),
      TextCellValue('معرّف القطعة'),
      TextCellValue('الكمية'),
      TextCellValue('تكلفة الوحدة'),
      TextCellValue('إجمالي التكلفة'),
      TextCellValue('المورد'),
      TextCellValue('طلب الصيانة'),
      TextCellValue('المنفذ'),
      TextCellValue('معرّف الحركة'),
      TextCellValue('مصدر المورد'),
      TextCellValue('اكتمال نسبة التكلفة'),
    ]);
    for (final event in filtered) {
      final date = event['eventAt'] as DateTime;
      sheet.appendRow([
        TextCellValue(date.toIso8601String()),
        TextCellValue(officeNames[event['officeId']] ?? event['officeId']?.toString() ?? ''),
        TextCellValue(event['kind']?.toString() ?? ''),
        TextCellValue(event['partName']?.toString() ?? ''),
        TextCellValue(event['partId']?.toString() ?? ''),
        IntCellValue((event['quantity'] as num?)?.toInt() ?? 0),
        DoubleCellValue((event['unitCost'] as num?)?.toDouble() ?? 0),
        DoubleCellValue((event['totalCost'] as num?)?.toDouble() ?? 0),
        TextCellValue(event['supplier']?.toString() ?? ''),
        TextCellValue(event['maintenanceId']?.toString() ?? ''),
        TextCellValue(event['createdBy']?.toString() ?? ''),
        TextCellValue(event['eventId']?.toString() ?? ''),
        TextCellValue(_movementSupplierSummary(event)),
        TextCellValue(event['isIncoming'] == true
            ? 'غير منطبق'
            : event['costAttributionComplete'] == true
                ? 'مكتملة'
                : 'جزئية / رصيد تاريخي غير منسوب'),
      ]);
    }

    void appendPeriodSummary(String sheetName, String Function(DateTime) keyOf) {
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final event in filtered) {
        final key = keyOf(event['eventAt'] as DateTime);
        grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(event);
      }
      final summary = workbook[sheetName];
      summary.appendRow([
        TextCellValue('الفترة'),
        TextCellValue('كمية التوريد'),
        TextCellValue('تكلفة التوريد'),
        TextCellValue('كمية الصرف'),
        TextCellValue('قيمة الصرف'),
      ]);
      final keys = grouped.keys.toList()..sort();
      for (final key in keys) {
        final rows = grouped[key]!;
        final incoming = rows.where((row) => row['isIncoming'] == true).toList();
        final outgoing = rows.where((row) => row['isIncoming'] != true).toList();
        int quantityOf(List<Map<String, dynamic>> values) =>
            values.fold<int>(0, (runningTotal, row) =>
                runningTotal + ((row['quantity'] as num?)?.toInt() ?? 0));
        double costOf(List<Map<String, dynamic>> values) =>
            values.fold<double>(0, (runningTotal, row) =>
                runningTotal + ((row['totalCost'] as num?)?.toDouble() ?? 0));
        summary.appendRow([
          TextCellValue(key),
          IntCellValue(quantityOf(incoming)),
          DoubleCellValue(costOf(incoming)),
          IntCellValue(quantityOf(outgoing)),
          DoubleCellValue(costOf(outgoing)),
        ]);
      }
    }

    appendPeriodSummary('المقارنة الشهرية', (date) =>
        '${date.year}-${date.month.toString().padLeft(2, '0')}');
    appendPeriodSummary('المقارنة السنوية', (date) => date.year.toString());

    final bytes = workbook.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('تعذر إنشاء ملف Excel');
    }
    final fileName = 'spare_parts_movements_${start.toIso8601String().substring(0, 10)}_${endExclusive.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10)}.xlsx';
    await Share.shareXFiles(
      [XFile.fromData(Uint8List.fromList(bytes),
          name: fileName,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      text: 'تقرير حركة مخزون قطع الغيار — للقراءة فقط',
    );
  }

  Future<void> _showMovementReport() async {
    final now = DateTime.now();
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 29)),
        end: now,
      ),
      helpText: 'اختر فترة تقرير المخزون',
      saveText: 'عرض التقرير',
    );
    if (pickedRange == null || !mounted) return;

    try {
      final offices = (await OfficeRepository().watchOffices().first)
          .where((office) => office.isActive).toList();
      final events = await repository.loadMovementReport(
        start: DateTime(pickedRange.start.year, pickedRange.start.month,
            pickedRange.start.day),
        endExclusive: DateTime(pickedRange.end.year, pickedRange.end.month,
            pickedRange.end.day).add(const Duration(days: 1)),
      );
      if (!mounted) return;
      final officeNames = {for (final office in offices) office.id: office.name};
      final supplierNames = <String>{};
      for (final event in events) {
        if (event['isIncoming'] == true) {
          final supplier = event['supplier'] as String? ?? '';
          if (supplier.isNotEmpty) supplierNames.add(supplier);
        } else {
          final lines = event['allocationLines'];
          if (lines is List) {
            for (final line in lines) {
              if (line is Map && line['sourceType'] == 'lot' &&
                  line['supplier'] is String && (line['supplier'] as String).isNotEmpty) {
                supplierNames.add(line['supplier'] as String);
              }
            }
          }
        }
      }
      final suppliers = supplierNames.toList()..sort();
      String? selectedOffice;
      String? selectedSupplier;

      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) {
            final officeEvents = events.where((e) =>
              selectedOffice == null || e['officeId'] == selectedOffice).toList();
            final filteredEvents = _filterMovementEvents(
              events,
              selectedOffice: selectedOffice,
              selectedSupplier: selectedSupplier,
            );
            final incoming = filteredEvents.where((e) => e['isIncoming'] == true).toList();
            final outgoing = filteredEvents.where((e) => e['isIncoming'] == false).toList();
            int quantityOf(List<Map<String, dynamic>> rows) =>
                rows.fold<int>(0, (total, row) => total + (row['quantity'] as int));
            double costOf(List<Map<String, dynamic>> rows) =>
                rows.fold<double>(0, (total, row) => total + (row['totalCost'] as double));
            final officeIds = filteredEvents.map((e) => e['officeId'] as String? ?? '')
                .where((id) => id.isNotEmpty).toSet().toList()..sort();
            final periodEvents = filteredEvents;
            final periodGroups = <String, List<Map<String, dynamic>>>{};
            for (final event in periodEvents) {
              final date = event['eventAt'] as DateTime;
              final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
              periodGroups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(event);
            }
            final annualGroups = <String, List<Map<String, dynamic>>>{};
            for (final event in periodEvents) {
              final date = event['eventAt'] as DateTime;
              annualGroups.putIfAbsent(date.year.toString(), () => <Map<String, dynamic>>[]).add(event);
            }
            final sortedMonthly = periodGroups.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));
            final sortedAnnual = annualGroups.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));
            final supplierTotals = <String, List<Map<String, dynamic>>>{};
            final supplierIssueTotals = <String, List<Map<String, dynamic>>>{};
            for (final event in officeEvents.where((e) => e['isIncoming'] == true)) {
              final name = event['supplier'] as String? ?? 'غير محدد';
              supplierTotals.putIfAbsent(name, () => <Map<String, dynamic>>[]).add(event);
            }
            for (final event in officeEvents.where((e) => e['isIncoming'] == false)) {
              final lines = event['allocationLines'];
              if (lines is! List) continue;
              for (final line in lines) {
                if (line is! Map || line['sourceType'] != 'lot' ||
                    line['supplier'] is! String) {
                  continue;
                }
                final name = line['supplier'] as String;
                supplierIssueTotals.putIfAbsent(name, () => <Map<String, dynamic>>[]).add({
                  ...event,
                  'quantity': (line['quantity'] as num?)?.toInt() ?? 0,
                  'totalCost': (line['totalCost'] as num?)?.toDouble() ?? 0,
                });
              }
            }
            return AlertDialog(
              title: const Text('تقرير مقارنة التوريد والصرف'),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('الفترة: ${pickedRange.start.toLocal().toString().split(' ').first} — ${pickedRange.end.toLocal().toString().split(' ').first}'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedOffice,
                        decoration: const InputDecoration(labelText: 'المكتب'),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('جميع المكاتب المصرح بها')),
                          ...offices.map((office) => DropdownMenuItem(
                            value: office.id, child: Text(office.name),
                          )),
                        ],
                        onChanged: (value) => setDialog(() => selectedOffice = value),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSupplier,
                        decoration: const InputDecoration(labelText: 'المورد (الوارد والصرف المتتبع)'),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('جميع الموردين')),
                          ...suppliers.map((supplier) => DropdownMenuItem(
                            value: supplier, child: Text(supplier),
                          )),
                        ],
                        onChanged: (value) => setDialog(() => selectedSupplier = value),
                      ),
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _historyMetric('الكمية المستلمة', quantityOf(incoming).toString()),
                        _historyMetric('تكلفة التوريد', costOf(incoming).toStringAsFixed(2)),
                        _historyMetric('الكمية المصروفة', quantityOf(outgoing).toString()),
                        _historyMetric('قيمة الصرف', costOf(outgoing).toStringAsFixed(2)),
                        _historyMetric('صرف غير مكتمل النسبة', events.where((e) =>
                          e['isIncoming'] == false && e['costAttributionComplete'] != true).length.toString()),
                      ]),
                      const Divider(height: 24),
                      const Text('المقارنة حسب المكتب', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (officeIds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('لا توجد حركات خلال الفترة المحددة.'),
                        )
                      else
                        ...officeIds.map((id) {
                          final rows = filteredEvents.where((e) => e['officeId'] == id).toList();
                          final receivedRows = rows.where((e) =>
                            e['isIncoming'] == true &&
                            (selectedSupplier == null || e['supplier'] == selectedSupplier)).toList();
                          final issuedRows = rows.where((e) => e['isIncoming'] == false).toList();
                          return Card(
                            child: ListTile(
                              title: Text(officeNames[id] ?? id),
                              subtitle: Text('وارد: ${quantityOf(receivedRows)} • تكلفة: ${costOf(receivedRows).toStringAsFixed(2)}\n'
                                  'منصرف: ${quantityOf(issuedRows)} • قيمة: ${costOf(issuedRows).toStringAsFixed(2)}'),
                            ),
                          );
                        }),
                      const Divider(height: 24),
                      const Text('المقارنة الشهرية', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (periodGroups.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('لا توجد بيانات شهرية ضمن الفترة.'),
                        )
                      else
                        ...sortedMonthly.map((entry) {
                              final rows = entry.value;
                              final received = rows.where((e) => e['isIncoming'] == true).toList();
                              final issued = rows.where((e) => e['isIncoming'] != true).toList();
                              return ListTile(
                                dense: true,
                                title: Text(entry.key),
                                subtitle: Text('توريد: ${quantityOf(received)} وحدة • ${costOf(received).toStringAsFixed(2)}'
                                    ' | صرف: ${quantityOf(issued)} وحدة • ${costOf(issued).toStringAsFixed(2)}'),
                              );
                            }),
                      const Divider(height: 24),
                      const Text('المقارنة السنوية', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (annualGroups.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('لا توجد بيانات سنوية ضمن الفترة.'),
                        )
                      else
                        ...sortedAnnual.map((entry) {
                              final rows = entry.value;
                              final received = rows.where((e) => e['isIncoming'] == true).toList();
                              final issued = rows.where((e) => e['isIncoming'] != true).toList();
                              return ListTile(
                                dense: true,
                                title: Text(entry.key),
                                subtitle: Text('توريد: ${quantityOf(received)} وحدة • ${costOf(received).toStringAsFixed(2)}'
                                    ' | صرف: ${quantityOf(issued)} وحدة • ${costOf(issued).toStringAsFixed(2)}'),
                              );
                            }),
                      const Divider(height: 24),
                      const Text('تفصيل التوريد حسب المورد', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (supplierTotals.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('لا توجد إيصالات توريد في الفترة.'),
                        )
                      else
                        ...supplierTotals.entries.where((entry) =>
                          selectedSupplier == null || entry.key == selectedSupplier).map((entry) =>
                          ListTile(
                            dense: true,
                            title: Text(entry.key),
                            trailing: Text('${quantityOf(entry.value)} وحدة • ${costOf(entry.value).toStringAsFixed(2)}'),
                          )),
                      const SizedBox(height: 8),
                      const Divider(height: 24),
                      const Text('الصرف حسب المورد الفعلي', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (supplierIssueTotals.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('لا توجد حركات صرف منسوبة إلى دفعات موردين ضمن الفترة.'),
                        )
                      else
                        ...supplierIssueTotals.entries.where((entry) =>
                          selectedSupplier == null || entry.key == selectedSupplier).map((entry) =>
                          ListTile(
                            dense: true,
                            title: Text(entry.key),
                            trailing: Text('${quantityOf(entry.value)} وحدة • ${costOf(entry.value).toStringAsFixed(2)}'),
                          )),
                      const SizedBox(height: 8),
                      const Text('الرصيد التاريخي غير المنسوب يظهر دون مورد أو تكلفة مفترضة، وتكون نسبة التكلفة مكتملة فقط عندما تأتي الكمية المصروفة بالكامل من دفعات موثقة.',
                          style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      const Text('التقرير للقراءة فقط، ويُبنى من إيصالات التوريد وسجلات الصرف الأصلية غير القابلة للتعديل أو الحذف.',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    try {
                      await _exportMovementReport(
                        events: events,
                        officeNames: officeNames,
                        selectedOffice: selectedOffice,
                        selectedSupplier: selectedSupplier,
                        start: DateTime(pickedRange.start.year,
                            pickedRange.start.month, pickedRange.start.day),
                        endExclusive: DateTime(pickedRange.end.year,
                            pickedRange.end.month, pickedRange.end.day)
                            .add(const Duration(days: 1)),
                      );
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تعذر تصدير Excel: $error')),
                        );
                      }
                    }
                  },
                  child: const Text('تصدير Excel'),
                ),
                TextButton(onPressed: () => Navigator.pop(ctx),
                    child: const Text('إغلاق')),
              ],
            );
          },
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنشاء تقرير المخزون: $error')),
        );
      }
    }
  }

  Future<void> _showMovementHistory(QueryDocumentSnapshot<Map<String, dynamic>> part) async {
    final data = part.data();
    final officeId = data['officeId'] as String? ?? '';
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('spare_part_receipts')
            .where('partId', isEqualTo: part.id)
            .where('officeId', isEqualTo: officeId).get(),
        db.collection('maintenance_parts')
            .where('partId', isEqualTo: part.id)
            .where('officeId', isEqualTo: officeId).get(),
      ]);
      if (!mounted) return;
      final issueDocs = results[1].docs;
      final allocationSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (var offset = 0; offset < issueDocs.length; offset += 30) {
        final batch = issueDocs.skip(offset).take(30);
        allocationSnapshots.addAll(await Future.wait(batch.map((doc) =>
            db.collection('spare_part_allocations').doc(doc.id).get())));
      }
      final receipts = results[0].docs.map((doc) {
        final value = doc.data();
        return <String, dynamic>{
          ...value, 'kind': 'توريد',
          'eventAt': value['receivedAt'] ?? value['createdAt'],
          'quantityDelta': (value['quantity'] as num?)?.toInt() ?? 0,
          'isIncoming': true,
        };
      }).toList();
      final issues = issueDocs.asMap().entries.map((entry) {
        final value = entry.value.data();
        final allocation = allocationSnapshots[entry.key].data();
        return <String, dynamic>{
          ...value, 'kind': 'صرف',
          'eventAt': value['usedAt'],
          'quantityDelta': -((value['quantity'] as num?)?.toInt() ?? 0),
          'allocationLines': allocation?['lines'] is List
              ? allocation!['lines'] as List
              : const <dynamic>[],
          'costAttributionComplete': value['costAttributionComplete'] == true,
          'isIncoming': false,
        };
      }).toList();
      final events = <Map<String, dynamic>>[...receipts, ...issues]
        ..sort((a, b) {
          DateTime dateOf(Map<String, dynamic> row) {
            final value = row['eventAt'];
            if (value is Timestamp) return value.toDate();
            if (value is DateTime) return value;
            return DateTime.fromMillisecondsSinceEpoch(0);
          }
          return dateOf(b).compareTo(dateOf(a));
        });
      final received = receipts.fold<int>(0, (total, row) => total + (row['quantity'] as int));
      final consumed = issues.fold<int>(0, (total, row) => total + (row['quantity'] as int));
      final receivedCost = receipts.fold<double>(0, (total, row) => total + ((row['totalCost'] as num?)?.toDouble() ?? 0));
      final issuedCost = issues.fold<double>(0, (total, row) => total + ((row['totalCost'] as num?)?.toDouble() ?? 0));
      final closing = (data['quantity'] as num?)?.toInt() ?? 0;
      final opening = closing - received + consumed;
      final supplierSet = <String>{};
      for (final row in receipts) {
        final supplier = row['supplier'] as String? ?? '';
        if (supplier.isNotEmpty) supplierSet.add(supplier);
      }
      for (final issue in issues) {
        final lines = issue['allocationLines'];
        if (lines is List) {
          for (final line in lines) {
            if (line is Map && line['sourceType'] == 'lot' &&
                line['supplier'] is String) {
              supplierSet.add(line['supplier'] as String);
            }
          }
        }
      }
      final suppliers = supplierSet.toList()..sort();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('حركة المخزون • ${data['name'] ?? ''}'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _historyMetric('الرصيد الافتتاحي', opening.toString()),
                    _historyMetric('إجمالي الوارد', received.toString()),
                    _historyMetric('إجمالي المنصرف', consumed.toString()),
                    _historyMetric('الرصيد الحالي', closing.toString()),
                    _historyMetric('تكلفة التوريد', receivedCost.toStringAsFixed(2)),
                    _historyMetric('قيمة الصرف', issuedCost.toStringAsFixed(2)),
                  ]),
                  const SizedBox(height: 12),
                  Text('الموردون: ${suppliers.isEmpty ? '—' : suppliers.join('، ')}'),
                  const Divider(height: 24),
                  if (events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('لا توجد حركات توريد أو صرف مسجلة لهذه القطعة.'),
                    )
                  else
                    ...events.map((event) {
                      final rawDate = event['eventAt'];
                      final date = rawDate is Timestamp ? rawDate.toDate() :
                          rawDate is DateTime ? rawDate : null;
                      final qty = (event['quantity'] as num?)?.toInt() ?? 0;
                      final cost = (event['totalCost'] as num?)?.toDouble() ?? 0;
                      final actor = event['createdBy'] as String? ?? '';
                      return ListTile(
                        dense: true,
                        leading: Icon(event['kind'] == 'توريد'
                            ? Icons.call_received : Icons.call_made),
                        title: Text('${event['kind']} • ${event['kind'] == 'توريد' ? event['supplier'] ?? 'مورد غير محدد' : _movementSupplierSummary(event)}'),
                        subtitle: Text('${date?.toLocal().toString().split('.').first ?? 'تاريخ غير متاح'} • المنفذ: ${actor.isEmpty ? 'مسجل في طلب الصيانة' : actor}${event['kind'] == 'صرف' && event['costAttributionComplete'] != true ? ' • تكلفة غير مكتملة النسبة' : ''}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${event['kind'] == 'توريد' ? '+' : '−'}$qty'),
                            Text(cost.toStringAsFixed(2), style: Theme.of(ctx).textTheme.bodySmall),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  const Text('المورد المعروض للصرف مستمد من دفعات FIFO الفعلية. الرصيد التاريخي غير المنسوب لا يحمل مورداً أو تكلفة مفترضة.',
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  const Text('السجلات الأصلية محفوظة للقراءة فقط؛ لا يمكن تعديلها أو حذفها من التطبيق.',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل سجل الحركة: $error')),
        );
      }
    }
  }

  Widget _historyMetric(String label, String value) => Container(
    constraints: const BoxConstraints(minWidth: 145),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ]),
  );

  Widget _field(TextEditingController controller, String label,
      {bool numeric = false, bool required = true}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(labelText: label),
          validator: (value) {
            if (required && (value == null || value.trim().isEmpty)) {
              return 'هذا الحقل مطلوب';
            }
            if (numeric && value != null && value.trim().isNotEmpty) {
              final parsed = double.tryParse(value);
              if (parsed == null || !parsed.isFinite || parsed < 0 ||
                  ((label.contains('الكمية') || label.contains('حد التنبيه')) && parsed != parsed.roundToDouble())) {
                return 'أدخل قيمة صحيحة غير سالبة';
              }
            }
            return null;
          },
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('مخزون قطع الغيار'),
          actions: [
            IconButton(
              tooltip: 'تقارير التوريد والصرف',
              onPressed: _showMovementReport,
              icon: const Icon(Icons.assessment_outlined),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addPart,
          icon: const Icon(Icons.add),
          label: const Text('إضافة قطعة'),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: repository.watchParts(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('تعذر تحميل المخزون: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Center(child: Text('مخزون قطع الغيار فارغ'));
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final part = docs[index];
                final data = part.data();
                final stock = (data['quantity'] as num?)?.toInt() ?? 0;
                final minimum = (data['minimumQuantity'] as num?)?.toInt() ?? 0;
                final low = stock <= minimum;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: low ? Colors.orange.shade50 : null,
                      child: Icon(low ? Icons.warning_amber : Icons.inventory_2_outlined,
                          color: low ? Colors.deepOrange : null),
                    ),
                    title: Text(data['name'] as String? ?? 'قطعة غيار',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'الرمز: ${data['sku'] ?? '—'} • المورد: ${data['supplier'] ?? '—'}\n'
                      'الرصيد: $stock • حد التنبيه: $minimum • تكلفة الوحدة: ${data['unitCost'] ?? 0}',
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showMovementHistory(part),
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('الحركة'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _restock(part),
                          icon: const Icon(Icons.add_box_outlined, size: 18),
                          label: const Text('توريد'),
                        ),
                        FilledButton.tonal(
                          onPressed: stock > 0 ? () => _consume(part) : null,
                          child: const Text('صرف'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}
