import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:metra_it_assets/models/office.dart';
import 'package:metra_it_assets/services/office_repository.dart';

class OfficesScreen extends StatefulWidget {
  const OfficesScreen({super.key});

  @override
  State<OfficesScreen> createState() => _OfficesScreenState();
}

class _OfficesScreenState extends State<OfficesScreen> {
  final repo = OfficeRepository();
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _editOffice([Office? office]) async {
    final name = TextEditingController(text: office?.name ?? '');
    final building = TextEditingController(text: office?.building ?? '');
    final directorate = TextEditingController(text: office?.directorate ?? '');
    final department = TextEditingController(text: office?.department ?? '');
    final room = TextEditingController(text: office?.room ?? '');
    final manager = TextEditingController(text: office?.manager ?? '');
    final phone = TextEditingController(text: office?.phone ?? '');
    final notes = TextEditingController(text: office?.notes ?? '');
    final key = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(office == null ? 'إضافة مكتب أو مركز عمل' : 'تعديل بيانات المكتب'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'اسم المكتب', required: true),
                  _field(directorate, 'المديرية'),
                  _field(department, 'القسم'),
                  _field(building, 'المبنى'),
                  _field(room, 'رقم الغرفة'),
                  _field(manager, 'المسؤول'),
                  _field(phone, 'هاتف التواصل', keyboard: TextInputType.phone),
                  _field(notes, 'ملاحظات', maxLines: 3),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, key.currentState?.validate() ?? false),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (saved == true) {
      try {
        await repo.save(Office(
          id: office?.id ?? const Uuid().v4(),
          name: name.text,
          building: building.text,
          directorate: directorate.text,
          department: department.text,
          room: room.text,
          manager: manager.text,
          phone: phone.text,
          notes: notes.text,
          isActive: office?.isActive ?? true,
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(office == null ? 'تمت إضافة المكتب' : 'تم تحديث بيانات المكتب')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر حفظ المكتب: $error')),
          );
        }
      }
    }

    name.dispose();
    building.dispose();
    directorate.dispose();
    department.dispose();
    room.dispose();
    manager.dispose();
    phone.dispose();
    notes.dispose();
  }

  Future<void> _toggleOffice(Office office) async {
    final nextActive = !office.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(nextActive ? 'إعادة تفعيل المكتب' : 'إيقاف المكتب'),
        content: Text(nextActive
            ? 'سيعود المكتب للظهور ضمن المكاتب المتاحة.'
            : 'سيبقى سجل المكتب وأصوله محفوظاً، ولن يظهر كوجهة جديدة للنقل.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await repo.save(Office(
        id: office.id,
        name: office.name,
        building: office.building,
        directorate: office.directorate,
        department: office.department,
        room: office.room,
        manager: office.manager,
        phone: office.phone,
        notes: office.notes,
        isActive: nextActive,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nextActive ? 'تم تفعيل المكتب' : 'تم إيقاف المكتب دون حذف بياناته')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تغيير حالة المكتب: $error')),
        );
      }
    }
  }

  static Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          validator: required
              ? (value) => value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null
              : null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('دليل المكاتب')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editOffice(),
          icon: const Icon(Icons.add),
          label: const Text('إضافة مكتب'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'ابحث باسم المكتب أو المديرية أو القسم أو المسؤول',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Office>>(
                  stream: repo.watchOffices(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('تعذر تحميل المكاتب: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final query = search.text.toLowerCase().trim();
                    final rows = snapshot.data!.where((office) {
                      final searchable = '${office.name} ${office.directorate} ${office.department} ${office.manager} ${office.building} ${office.room} ${office.phone}'.toLowerCase();
                      return searchable.contains(query);
                    }).toList();
                    if (rows.isEmpty) {
                      return const Center(child: Text('لا توجد مكاتب مطابقة لمعايير البحث'));
                    }
                    return ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final office = rows[index];
                        final details = [
                          office.directorate,
                          office.department,
                          office.building,
                          office.room,
                          office.manager,
                          office.phone,
                        ].where((value) => value.trim().isNotEmpty).join(' • ');
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: office.isActive ? const Color(0xFFE2F1F1) : Colors.black12,
                              child: Icon(
                                office.isActive ? Icons.business : Icons.business_outlined,
                                color: office.isActive ? const Color(0xFF168C8C) : Colors.black54,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(office.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                if (!office.isActive) const Chip(label: Text('متوقف')),
                              ],
                            ),
                            subtitle: Text(details.isEmpty ? 'لا توجد تفاصيل إضافية' : details),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'إجراءات المكتب',
                              onSelected: (value) {
                                if (value == 'edit') _editOffice(office);
                                if (value == 'toggle') _toggleOffice(office);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('تعديل البيانات'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(office.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
                                    title: Text(office.isActive ? 'إيقاف المكتب' : 'إعادة التفعيل'),
                                  ),
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
            ],
          ),
        ),
      );
}
