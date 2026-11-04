import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AssetMovementsScreen extends StatelessWidget {
  const AssetMovementsScreen({super.key});

  String _label(String type) => switch (type) {
    'custody_assigned' => 'تسليم عهدة',
    'custody_returned' => 'إعادة عهدة',
    'maintenance_opened' => 'بدء صيانة',
    'maintenance_completed' => 'إنهاء صيانة',
    'retired' => 'استبعاد من الخدمة',
    'transferred' => 'نقل جهاز',
    _ => type.isEmpty ? 'حركة أخرى' : type,
  };

  IconData _icon(String type) => switch (type) {
    'custody_assigned' => Icons.assignment_ind_outlined,
    'custody_returned' => Icons.assignment_return_outlined,
    'maintenance_opened' || 'maintenance_completed' => Icons.build_outlined,
    'retired' => Icons.archive_outlined,
    'transferred' => Icons.swap_horiz,
    _ => Icons.history,
  };

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('سجل حركة الأجهزة')),
    body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream: FirebaseFirestore.instance.collection('asset_movements').orderBy('occurredAt', descending: true).limit(250).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر تحميل سجل الحركات: ${snapshot.error}')));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('لا توجد حركات مسجلة للأجهزة حتى الآن'));
        return ListView.separated(
          padding: const EdgeInsets.all(16), itemCount: docs.length,
          separatorBuilder: (_,__) => const Divider(height: 1),
          itemBuilder: (context,index) {
            final data=docs[index].data();
            final type=data['movementType'] as String? ?? '';
            final timestamp=data['occurredAt'];
            final date=timestamp is Timestamp ? timestamp.toDate() : null;
            final notes=data['notes'] as String? ?? '';
            return ListTile(
              leading: CircleAvatar(child: Icon(_icon(type))),
              title: Text(data['assetLabel'] as String? ?? 'جهاز غير معروف', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${_label(type)}${notes.isEmpty ? '' : ' • $notes'}${date == null ? '' : '\\n${date.toLocal().toString().substring(0,16)}'}', maxLines: 3, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_left),
            );
          },
        );
      },
    ),
  );
}
