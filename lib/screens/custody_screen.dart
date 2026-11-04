import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:metra_it_assets/services/custody_repository.dart';
import 'package:uuid/uuid.dart';

class CustodyScreen extends StatefulWidget {
  const CustodyScreen({super.key});

  @override
  State<CustodyScreen> createState() => _CustodyScreenState();
}

class _CustodyScreenState extends State<CustodyScreen> {
  final repo = CustodyRepository();
  final employee = TextEditingController();
  final office = TextEditingController();
  final notes = TextEditingController();
  final rejectionReason = TextEditingController();
  String? assetId;
  String? assetLabel;

  @override
  void dispose() {
    employee.dispose();
    office.dispose();
    notes.dispose();
    rejectionReason.dispose();
    super.dispose();
  }

  Future<void> create() async {
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنشاء بطاقة عهدة'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('assets')
                      .where('status', isEqualTo: 'available')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'الجهاز المتاح',
                      ),
                      items: docs.map((doc) {
                        final data = doc.data();
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(
                            '${data['brand'] ?? ''} ${data['model'] ?? ''} • ${data['serialNumber'] ?? ''}',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        assetId = value;
                        final matches =
                            docs.where((document) => document.id == value);
                        if (matches.isNotEmpty) {
                          final data = matches.first.data();
                          assetLabel =
                              '${data['brand'] ?? ''} ${data['model'] ?? ''}';
                        }
                      },
                      validator: (value) =>
                          value == null ? 'اختر جهازاً' : null,
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: employee,
                  decoration: const InputDecoration(
                    labelText: 'اسم الموظف المستلم',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: office,
                  decoration: const InputDecoration(labelText: 'المكتب / القسم'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, formKey.currentState?.validate() ?? false),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );

    if (confirmed == true && assetId != null) {
      try {
        await repo.add(CustodyRecord(
          id: const Uuid().v4(),
          assetId: assetId!,
          assetLabel: assetLabel ?? '',
          employeeName: employee.text,
          officeName: office.text,
          assignedAt: DateTime.now(),
          notes: notes.text,
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إنشاء بطاقة العهدة وتحديث حالة الجهاز')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر إنشاء العهدة: $error')),
          );
        }
      }
    }

    employee.clear();
    office.clear();
    notes.clear();
    assetId = null;
    assetLabel = null;
  }

  String _escapeHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  Future<void> printForm(CustodyRecord record) async {
    final statusLabel = switch (record.status) {
      'returned' => 'مغلقة - تم إرجاع الأصل',
      'rejected' => 'مرفوضة',
      _ when record.approvalStatus == 'pending' => 'بانتظار الاعتماد',
      _ => 'معتمدة ونشطة',
    };
    final html = '''
<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>محضر عهدة تقنية - ${_escapeHtml(record.id)}</title>
<style>
@page { size: A4; margin: 18mm; }
* { box-sizing: border-box; }
body { font-family: Tahoma, Arial, sans-serif; color: #172b3a; line-height: 1.8; }
header { text-align: center; border-bottom: 3px solid #168c8c; padding-bottom: 14px; margin-bottom: 20px; }
h1 { font-size: 22px; margin: 0; }
h2 { font-size: 16px; margin: 22px 0 8px; color: #183b56; }
.meta { color: #536574; font-size: 12px; }
table { width: 100%; border-collapse: collapse; margin: 10px 0 18px; }
th, td { border: 1px solid #aab8c2; padding: 9px 11px; text-align: right; }
th { width: 27%; background: #edf4f5; }
.notice { border: 1px solid #aab8c2; padding: 12px; border-radius: 6px; }
.signatures { display: grid; grid-template-columns: 1fr 1fr; gap: 26px 18px; margin-top: 34px; }
.signature { border-top: 1px solid #536574; padding-top: 8px; min-height: 70px; }
footer { margin-top: 28px; font-size: 11px; color: #536574; text-align: center; }
@media print { .no-print { display: none; } }
</style>
</head>
<body>
<header>
<h1>محضر تسليم واستلام عهدة تقنية</h1>
<div class="meta">نظام إدارة وجرد الأصول التقنية</div>
<div class="meta">رقم البطاقة: ${_escapeHtml(record.id)}</div>
</header>
<h2>بيانات العهدة</h2>
<table>
<tr><th>الأصل التقني</th><td>${_escapeHtml(record.assetLabel)}</td></tr>
<tr><th>معرّف الأصل</th><td>${_escapeHtml(record.assetId)}</td></tr>
<tr><th>الموظف المستلم</th><td>${_escapeHtml(record.employeeName)}</td></tr>
<tr><th>المكتب / القسم</th><td>${_escapeHtml(record.officeName)}</td></tr>
<tr><th>تاريخ التسليم</th><td>${_escapeHtml(record.assignedAt.toLocal().toString().split('.').first)}</td></tr>
<tr><th>حالة البطاقة</th><td>${_escapeHtml(statusLabel)}</td></tr>
<tr><th>ملاحظات</th><td>${_escapeHtml(record.notes.isEmpty ? 'لا توجد' : record.notes)}</td></tr>
</table>
<h2>إقرار الاستلام</h2>
<div class="notice">أقر أنا الموظف الموضح اسمي أعلاه باستلام الأصل التقني المبين في هذا المحضر، وأتعهد بالمحافظة عليه واستخدامه لأغراض العمل وإعادته عند الطلب أو انتهاء الحاجة إليه، وإبلاغ الجهة المختصة عن أي عطل أو فقد أو ضرر.</div>
<div class="signatures">
<div class="signature">اسم وتوقيع الموظف المستلم</div>
<div class="signature">اسم وتوقيع مسؤول تقنية المعلومات</div>
<div class="signature">اعتماد رئيس القسم / المدير</div>
<div class="signature">تاريخ الاعتماد والختم</div>
</div>
<footer>تم إنشاء هذا النموذج من نظام إدارة الأصول التقنية. يرجى حفظ نسخة موقعة ضمن مستندات الأصل.</footer>
<div class="no-print" style="text-align:center;margin-top:20px"><button onclick="window.print()">طباعة النموذج</button></div>
</body>
</html>
''';
    try {
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(utf8.encode(html)),
          mimeType: 'text/html',
          name: 'custody-${record.id}.html',
        ),
      ], text: 'محضر عهدة تقنية جاهز للطباعة');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنشاء نموذج الطباعة: $error')),
        );
      }
    }
  }

  Future<void> approve(CustodyRecord record) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await repo.approveCustody(record, approverUid: uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم اعتماد بطاقة العهدة')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر اعتماد العهدة: $error')),
        );
      }
    }
  }

  Future<void> reject(CustodyRecord record) async {
    rejectionReason.clear();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفض بطاقة العهدة'),
        content: TextField(
          controller: rejectionReason,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'سبب الرفض (اختياري)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, rejectionReason.text),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await repo.rejectCustody(record, approverUid: uid, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض العهدة وإعادة الجهاز إلى المتاح')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر رفض العهدة: $error')),
        );
      }
    }
  }

  Future<void> transfer(CustodyRecord record) async {
    final employeeController = TextEditingController();
    final officeController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('نقل العهدة إلى موظف آخر'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الجهاز: ${record.assetLabel}'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: employeeController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الموظف الجديد',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: officeController,
                  decoration: const InputDecoration(
                    labelText: 'المكتب / القسم الجديد',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات النقل'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, formKey.currentState?.validate() ?? false),
            child: const Text('تأكيد النقل'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await repo.transferCustody(
          record,
          newEmployeeName: employeeController.text,
          newOfficeName: officeController.text,
          notes: notesController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم نقل العهدة وتسجيل الحركة')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر نقل العهدة: $error')),
          );
        }
      }
    }

    employeeController.dispose();
    officeController.dispose();
    notesController.dispose();
  }

  Future<void> returnCustody(CustodyRecord record) async {
    try {
      await repo.returnAsset(record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرجاع الجهاز وإغلاق بطاقة العهدة')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الإرجاع: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('بطاقات العهدة')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: create,
          icon: const Icon(Icons.assignment_add),
          label: const Text('بطاقة جديدة'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: StreamBuilder<List<CustodyRecord>>(
            stream: repo.watch(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('تعذر تحميل العهد: ${snapshot.error}'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final records = snapshot.data!;
              if (records.isEmpty) {
                return const Center(child: Text('لا توجد بطاقات عهدة مسجلة'));
              }
              return ListView.separated(
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final record = records[index];
                  final active = record.status == 'active';
                  final pending = active && record.approvalStatus == 'pending';
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(pending ? Icons.pending_actions : Icons.assignment_ind),
                      ),
                      title: Text(
                        record.employeeName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${record.assetLabel} • ${record.officeName}'
                        '${pending ? ' • بانتظار الاعتماد' : ''}',
                      ),
                      trailing: Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            tooltip: 'إنشاء محضر للطباعة',
                            onPressed: () => printForm(record),
                            icon: const Icon(Icons.print_outlined),
                          ),
                          if (pending) ...[
                            IconButton(
                              tooltip: 'اعتماد العهدة',
                              onPressed: () => approve(record),
                              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                            ),
                            IconButton(
                              tooltip: 'رفض العهدة',
                              onPressed: () => reject(record),
                              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                            ),
                          ] else if (active) ...[
                            IconButton(
                              tooltip: 'نقل العهدة',
                              onPressed: () => transfer(record),
                              icon: const Icon(Icons.swap_horiz),
                            ),
                            IconButton(
                              tooltip: 'إرجاع الجهاز',
                              onPressed: () => returnCustody(record),
                              icon: const Icon(Icons.assignment_return),
                            ),
                          ] else
                            Chip(
                              label: Text(record.approvalStatus == 'rejected'
                                  ? 'مرفوضة'
                                  : 'مغلقة'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
}
