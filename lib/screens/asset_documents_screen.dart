import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:metra_it_assets/models/asset.dart';
import 'package:metra_it_assets/services/asset_repository.dart';

class AssetDocumentsScreen extends StatefulWidget {
  const AssetDocumentsScreen({super.key});

  @override
  State<AssetDocumentsScreen> createState() => _AssetDocumentsScreenState();
}

class _AssetDocumentsScreenState extends State<AssetDocumentsScreen> {
  String? selectedAssetId;
  String? selectedAssetOfficeId;
  final assetRepository = AssetRepository();
  String documentType = 'other';
  String? purchaseRecordId;
  bool uploading = false;

  String _contentType(String extension) => switch (extension.toLowerCase()) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        _ => 'application/octet-stream',
      };

  Future<void> _upload() async {
    if (selectedAssetId == null || uploading) return;
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx', 'xlsx'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _message('تعذر قراءة الملف المحدد');
      return;
    }
    if (bytes.length > 10 * 1024 * 1024) {
      _message('الحد الأقصى لحجم الملف 10 ميغابايت');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _message('يجب تسجيل الدخول أولاً');
      return;
    }
    final extension = (file.extension ?? '').toLowerCase();
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final documentId = const Uuid().v4();
    final path = 'asset_documents/$selectedAssetId/$documentId-$safeName';
    setState(() => uploading = true);
    try {
      final storageRef = FirebaseStorage.instance.ref(path);
      await storageRef.putData(
        bytes,
        SettableMetadata(
          contentType: _contentType(extension),
          customMetadata: {'assetId': selectedAssetId!, 'uploadedBy': uid},
        ),
      );
      await FirebaseFirestore.instance.collection('asset_documents').doc(documentId).set({
        'assetId': selectedAssetId,
        'officeId': selectedAssetOfficeId,
        'fileName': file.name,
        'storagePath': path,
        'contentType': _contentType(extension),
        'sizeBytes': file.size,
        'uploadedBy': uid,
        'documentType': documentType,
        'purchaseRecordId': purchaseRecordId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _message('تم رفع المستند وربطه بالأصل');
    } catch (error) {
      _message('تعذر رفع المستند: $error');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _shareDocument(Map<String, dynamic> data) async {
    try {
      final path = data['storagePath'] as String? ?? '';
      if (path.isEmpty) throw StateError('مسار المستند غير متوفر');
      final bytes = await FirebaseStorage.instance.ref(path).getData(10 * 1024 * 1024);
      if (bytes == null || bytes.isEmpty) throw StateError('تعذر تنزيل المستند');
      await Share.shareXFiles([
        XFile.fromData(
          bytes,
          mimeType: data['contentType'] as String? ?? 'application/octet-stream',
          name: data['fileName'] as String? ?? 'asset-document',
        ),
      ], text: 'مستند مرتبط بأصل تقني');
    } catch (error) {
      _message('تعذرت مشاركة المستند: $error');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('مرفقات ومستندات الأصول')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: uploading || selectedAssetId == null ? null : _upload,
          icon: uploading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.upload_file),
          label: Text(uploading ? 'جارٍ الرفع...' : 'رفع مستند'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<List<Asset>>(
                stream: assetRepository.watchAssets(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('تعذر تحميل الأصول: ${snapshot.error}');
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final assets = snapshot.data!;
                  if (assets.isEmpty) return const Text('لا توجد أصول ضمن المكاتب المصرح بها');
                  if (!assets.any((asset) => asset.id == selectedAssetId)) {
                    final firstAsset = assets.first;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && selectedAssetId != firstAsset.id) {
                        setState(() {
                          selectedAssetId = firstAsset.id;
                          selectedAssetOfficeId = firstAsset.officeId;
                        });
                      }
                    });
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: selectedAssetId,
                    decoration: const InputDecoration(
                      labelText: 'الأصل المرتبط بالمستند',
                      prefixIcon: Icon(Icons.devices_other),
                    ),
                    items: assets.map((asset) {
                      final label = '${asset.brand} ${asset.model}'.trim();
                      return DropdownMenuItem(
                        value: asset.id,
                        child: Text(label.isEmpty ? asset.id : label,
                            overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() {
                      selectedAssetId = value;
                      final selected = assets.where((asset) => asset.id == value).toList();
                      selectedAssetOfficeId = selected.isEmpty ? null : selected.first.officeId;
                      purchaseRecordId = null;
                    }),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
              child: DropdownButtonFormField<String>(
                initialValue: documentType,
                decoration: const InputDecoration(
                  labelText: 'نوع المستند',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'invoice', child: Text('فاتورة شراء')),
                  DropdownMenuItem(value: 'warranty', child: Text('كفالة / ضمان')),
                  DropdownMenuItem(value: 'handover', child: Text('محضر تسليم أو استلام')),
                  DropdownMenuItem(value: 'maintenance', child: Text('مستند صيانة')),
                  DropdownMenuItem(value: 'photo', child: Text('صورة الجهاز')),
                  DropdownMenuItem(value: 'other', child: Text('مستند آخر')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      documentType = value;
                      purchaseRecordId = null;
                    });
                  }
                },
              ),
            ),
            if (selectedAssetId != null && (documentType == 'invoice' || documentType == 'warranty'))
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('purchase_records')
                      .where('assetId', isEqualTo: selectedAssetId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final purchases = snapshot.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: purchases.any((purchase) => purchase.id == purchaseRecordId)
                          ? purchaseRecordId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'فاتورة الشراء المرتبطة (اختياري)',
                        prefixIcon: Icon(Icons.receipt_long_outlined),
                      ),
                      items: purchases.map((purchase) {
                        final data = purchase.data();
                        final invoice = data['invoiceNumber'] as String? ?? purchase.id;
                        final supplier = data['supplier'] as String? ?? '';
                        return DropdownMenuItem(
                          value: purchase.id,
                          child: Text('$invoice • $supplier', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => purchaseRecordId = value),
                    );
                  },
                ),
              ),
            Expanded(
              child: selectedAssetId == null
                  ? const Center(child: Text('اختر أصلاً لعرض مستنداته'))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('asset_documents')
                          .where(
                            selectedAssetOfficeId == null ? 'assetId' : 'officeId',
                            isEqualTo: selectedAssetOfficeId ?? selectedAssetId,
                          )
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return Center(child: Text('تعذر تحميل المستندات: ${snapshot.error}'));
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final docs = snapshot.data!.docs
                            .where((doc) => doc.data()['assetId'] == selectedAssetId)
                            .toList()
                          ..sort((a, b) {
                            final ad = a.data()['createdAt'];
                            final bd = b.data()['createdAt'];
                            final at = ad is Timestamp ? ad.toDate() : DateTime(2000);
                            final bt = bd is Timestamp ? bd.toDate() : DateTime(2000);
                            return bt.compareTo(at);
                          });
                        if (docs.isEmpty) return const Center(child: Text('لا توجد مستندات مرفقة بهذا الأصل'));
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();
                            final size = ((data['sizeBytes'] as num?)?.toDouble() ?? 0) / 1024;
                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
                                title: Text(data['fileName'] as String? ?? 'مستند'),
                                subtitle: Text('${switch (data['documentType'] as String? ?? 'other') {
                                  'invoice' => 'فاتورة شراء',
                                  'warranty' => 'كفالة / ضمان',
                                  'handover' => 'محضر تسليم أو استلام',
                                  'maintenance' => 'مستند صيانة',
                                  'photo' => 'صورة الجهاز',
                                  _ => 'مستند آخر',
                                }} • ${(size / 1024).toStringAsFixed(2)} MB'),
                                trailing: IconButton(
                                  tooltip: 'تنزيل أو مشاركة المستند',
                                  icon: const Icon(Icons.download_outlined),
                                  onPressed: () => _shareDocument(data),
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
      );
}
