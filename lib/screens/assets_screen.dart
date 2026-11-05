import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:metra_it_assets/models/asset.dart';
import 'package:metra_it_assets/models/office.dart';
import 'package:metra_it_assets/screens/asset_form_screen.dart';
import 'package:metra_it_assets/screens/asset_scanner_screen.dart';
import 'package:metra_it_assets/services/asset_repository.dart';
import 'package:metra_it_assets/services/office_repository.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});
  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}
class _AssetsScreenState extends State<AssetsScreen> {
  final search = TextEditingController();
  final repository = AssetRepository();
  AssetCategory? category;
  AssetStatus? status;
  String? officeId;
  final officeRepository = OfficeRepository();
  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<void> _printQrLabel(Asset asset) async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'IT ASSET LABEL',
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 14),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: asset.id,
                width: 150,
                height: 150,
                drawText: false,
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'ASSET ID: ${asset.id}',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              if (asset.serialNumber.trim().isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text(
                  'SERIAL: ${asset.serialNumber.trim()}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) async => document.save(),
      name: 'asset-${asset.id}-qr-label.pdf',
    );
  }

  Future<void> _showQr(Asset asset) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رمز الأصل'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: asset.id,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
              const SizedBox(height: 12),
              Text('${asset.brand} ${asset.model}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('معرّف الأصل', style: TextStyle(color: Colors.black54)),
              SelectableText(asset.id, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('الرقم التسلسلي: ${asset.serialNumber.isEmpty ? 'غير محدد' : asset.serialNumber}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق'),
          ),
          FilledButton.icon(
            onPressed: () => _printQrLabel(asset),
            icon: const Icon(Icons.print_outlined),
            label: const Text('طباعة الملصق'),
          ),
        ],
      ),
    );
  }

  Future<void> _retire(Asset asset) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('استبعاد الجهاز من الخدمة'),
      content: TextField(controller: reason, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'سبب الاستبعاد')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد الاستبعاد')),
      ],
    ));
    if (confirmed == true) {
      try {
        await repository.retireAsset(asset, reason: reason.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استبعاد الجهاز مع الاحتفاظ بسجل حركته')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الاستبعاد: $e')));
      }
    }
    reason.dispose();
  }

  Future<void> _transfer(Asset asset) async {
    final offices = OfficeRepository();
    final notes = TextEditingController();
    final key = GlobalKey<FormState>();
    Office? destination;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('نقل الجهاز إلى مكتب آخر'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('الجهاز: ${asset.brand} ${asset.model}'),
                  const SizedBox(height: 14),
                  StreamBuilder<List<Office>>(
                    stream: offices.watchOffices(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Text('تعذر تحميل المكاتب: ${snapshot.error}');
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      final available = snapshot.data!.where((o) => o.isActive && o.id != asset.officeId).toList();
                      if (available.isEmpty) return const Text('لا توجد مكاتب نشطة أخرى. أضف مكتباً أولاً.');
                      return DropdownButtonFormField<String>(
                        initialValue: destination?.id,
                        decoration: const InputDecoration(labelText: 'المكتب الوجهة'),
                        items: available.map((o) => DropdownMenuItem(value: o.id, child: Text(o.name))).toList(),
                        onChanged: (id) => setDialog(() {
                          destination = available.firstWhere((o) => o.id == id);
                        }),
                        validator: (_) => destination == null ? 'اختر المكتب الوجهة' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'سبب النقل / ملاحظات'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (destination != null && key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('تأكيد النقل'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && destination != null) {
      try {
        await repository.transferAsset(asset, destination!, notes: notes.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم نقل الجهاز إلى ${destination!.name} وتسجيل الحركة')),
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر نقل الجهاز: $e')));
      }
    }
    notes.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الأجهزة والجرد')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssetFormScreen())),
      icon: const Icon(Icons.add), label: const Text('إضافة جهاز')),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      const Align(alignment: Alignment.centerRight, child: Text('سجل الأصول', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'بحث بالاسم أو الموديل أو الرقم التسلسلي',
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final code = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (_) => const AssetScannerScreen()),
            );
            if (code != null && mounted) {
              setState(() {
                search.text = code;
                category = null;
                status = null;
              });
            }
          },
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('مسح الرمز'),
        ),
        SizedBox(width: 220, child: DropdownButtonFormField<AssetCategory>(initialValue: category, decoration: const InputDecoration(labelText: 'التصنيف'),
          items: AssetCategory.values.map((e)=>DropdownMenuItem(value:e,child:Text(e.label))).toList(), onChanged: (v)=>setState(()=>category=v))),
        SizedBox(width: 220, child: DropdownButtonFormField<AssetStatus>(initialValue: status, decoration: const InputDecoration(labelText: 'الحالة'),
          items: AssetStatus.values.map((e)=>DropdownMenuItem(value:e,child:Text(e.label))).toList(), onChanged: (v)=>setState(()=>status=v))),
        SizedBox(
          width: 240,
          child: StreamBuilder<List<Office>>(
            stream: officeRepository.watchOffices(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const InputDecorator(
                  decoration: InputDecoration(labelText: 'المكتب'),
                  child: LinearProgressIndicator(),
                );
              }
              final offices = snapshot.data!;
              return DropdownButtonFormField<String>(
                initialValue: officeId ?? '',
                decoration: const InputDecoration(labelText: 'تصفية حسب المكتب'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('جميع المكاتب')),
                  ...offices.map((office) => DropdownMenuItem(
                    value: office.id,
                    child: Text(office.name),
                  )),
                ],
                onChanged: (value) => setState(() {
                  officeId = value == null || value.isEmpty ? null : value;
                }),
              );
            },
          ),
        ),
      ]),
      const SizedBox(height: 18),
      Expanded(child: StreamBuilder<List<Asset>>(
        stream: repository.watchAssets(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل الأصول: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final q = search.text.trim().toLowerCase();
          final items = snapshot.data!.where((a) =>
            (category == null || a.category == category) &&
            (status == null || a.status == status) &&
            (officeId == null || a.officeId == officeId) &&
            (q.isEmpty || '${a.id} ${a.brand} ${a.model} ${a.serialNumber} ${a.officeName ?? ''}'.toLowerCase().contains(q))).toList();
          if (items.isEmpty) return const Center(child: Text('لا توجد أجهزة مطابقة لمعايير البحث'));
          return Card(child: ListView.separated(itemCount: items.length, separatorBuilder: (_,__)=>const Divider(height: 1),
            itemBuilder: (context, i) { final a=items[i]; return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.devices_other)),
              title: Text('${a.brand} ${a.model}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${a.category.label} • المكتب: ${a.officeName?.isNotEmpty == true ? a.officeName : 'غير محدد'} • الرقم التسلسلي: ${a.serialNumber.isEmpty ? 'غير محدد' : a.serialNumber}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Chip(label: Text(a.status.label)),
                PopupMenuButton<String>(
                  tooltip: 'إجراءات الجهاز',
                  onSelected: (v) {
                    if (v == 'edit') Navigator.push(context, MaterialPageRoute(builder: (_) => AssetFormScreen(initialAsset: a)));
                    if (v == 'qr') _showQr(a);
                    if (v == 'retire') _retire(a);
                    if (v == 'transfer') _transfer(a);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'qr', child: ListTile(dense: true, leading: Icon(Icons.qr_code_2), title: Text('عرض رمز QR'))),
                    const PopupMenuItem(value: 'edit', child: ListTile(dense: true, leading: Icon(Icons.edit_outlined), title: Text('تعديل البيانات'))),
                    if (a.status != AssetStatus.retired) const PopupMenuItem(value: 'retire', child: ListTile(dense: true, leading: Icon(Icons.archive_outlined), title: Text('استبعاد من الخدمة'))),
                    if (a.status == AssetStatus.available || a.status == AssetStatus.returned) const PopupMenuItem(value: 'transfer', child: ListTile(dense: true, leading: Icon(Icons.drive_file_move_outline), title: Text('نقل إلى مكتب آخر'))),
                  ],
                ),
              ]),
            ); }));
        },
      )),
    ])),
  );
}
