import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  Future<void> _editUser(BuildContext context, {DocumentSnapshot<Map<String, dynamic>>? profile}) async {
    final uid = TextEditingController(text: profile?.id ?? '');
    final name = TextEditingController(text: profile?.data()?['displayName'] as String? ?? '');
    final email = TextEditingController(text: profile?.data()?['email'] as String? ?? '');
    final currentRole = profile?.data()?['role'] as String? ?? 'it_manager';
    var role = currentRole == 'admin' ? 'admin' : 'it_manager';
    var active = profile?.data()?['isActive'] == true;
    final isNew = profile == null;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isSelf = profile?.id == currentUid;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isNew ? 'إضافة ملف مستخدم' : 'تعديل صلاحيات المستخدم'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: uid,
                      readOnly: !isNew,
                      decoration: const InputDecoration(labelText: 'معرّف حساب Firebase UID'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'أدخل UID' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'أدخل الاسم' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        return text.contains('@') && text.contains('.') ? null : 'أدخل بريداً إلكترونياً صحيحاً';
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: 'الدور'),
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('مسؤول النظام')),
                        DropdownMenuItem(value: 'it_manager', child: Text('مدير تقنية المعلومات')),
                      ],
                      onChanged: isSelf ? null : (value) {
                        if (value != null) setDialogState(() => role = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('الحساب نشط'),
                      subtitle: isSelf ? const Text('لا يمكن تعطيل حسابك الحالي من هذه الشاشة') : null,
                      value: isSelf ? true : active,
                      onChanged: isSelf ? null : (value) => setDialogState(() => active = value),
                    ),
                    if (isNew)
                      const Text(
                        'أنشئ حساب المصادقة أولاً من Firebase Authentication، ثم أدخل UID هنا. هذه الشاشة لا تنشئ كلمات مرور ولا حسابات مصادقة.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, formKey.currentState?.validate() ?? false),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      try {
        final ref = FirebaseFirestore.instance.collection('users').doc(uid.text.trim());
        final data = <String, dynamic>{
          'displayName': name.text.trim(),
          'email': email.text.trim(),
          'role': role,
          'isActive': active,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (isNew) data['createdAt'] = FieldValue.serverTimestamp();
        await ref.set(data, SetOptions(merge: true));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isNew ? 'تم إنشاء ملف المستخدم' : 'تم تحديث المستخدم')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ المستخدم: $error')));
        }
      }
    }
    uid.dispose();
    name.dispose();
    email.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('إدارة المستخدمين والصلاحيات')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editUser(context),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('إضافة مستخدم'),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('تعذر تحميل المستخدمين: ${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final users = [...snapshot.data!.docs]
              ..sort((a, b) => (a.data()['displayName'] as String? ?? '').compareTo(b.data()['displayName'] as String? ?? ''));
            if (users.isEmpty) return const Center(child: Text('لا توجد ملفات مستخدمين مسجلة'));
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final profile = users[index];
                final data = profile.data();
                final role = data['role'] as String? ?? '';
                final active = data['isActive'] == true;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(active ? Icons.person : Icons.person_off)),
                    title: Text(data['displayName'] as String? ?? 'مستخدم بلا اسم'),
                    subtitle: Text('${data['email'] ?? ''} • ${role == 'admin' ? 'مسؤول النظام' : 'مدير تقنية المعلومات'}\nUID: ${profile.id}'),
                    isThreeLine: true,
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(label: Text(active ? 'نشط' : 'معطّل')),
                        IconButton(
                          tooltip: 'تعديل المستخدم',
                          onPressed: () => _editUser(context, profile: profile),
                          icon: const Icon(Icons.edit_outlined),
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
