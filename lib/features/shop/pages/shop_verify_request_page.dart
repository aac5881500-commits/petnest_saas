// 檔案名稱：lib/features/shop/pages/shop_verify_request_page.dart
// 功能說明：送出特寵字號認證、統編認證、平台公開申請，並上傳審核用照片
// ✅ 店家認證／平台公開申請頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ShopVerifyRequestPage extends StatefulWidget {
  const ShopVerifyRequestPage({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.currentLicenseNumber,
    required this.currentTaxId,
  });

  final String shopId;
  final String shopName;
  final String currentLicenseNumber;
  final String currentTaxId;

  @override
  State<ShopVerifyRequestPage> createState() => _ShopVerifyRequestPageState();
}

class _ShopVerifyRequestPageState extends State<ShopVerifyRequestPage> {
  final _formKey = GlobalKey<FormState>();

  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactTitleController = TextEditingController();
  final _noteController = TextEditingController();

  final _picker = ImagePicker();

  bool _submitting = false;

  XFile? _identityImage;
  XFile? _licenseImage;
  XFile? _taxIdImage;

  String _typeLabel() {
    return '店家認證／平台公開申請';
  }

  String _currentValueText() {
    return '申請店家認證並公開於平台';
  }

  Future<void> _pickImage(String type) async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    setState(() {
      if (type == 'identity') {
        _identityImage = image;
      } else if (type == 'license') {
        _licenseImage = image;
      } else if (type == 'taxId') {
        _taxIdImage = image;
      }
    });
  }

  Future<String> _uploadImage({
    required XFile image,
    required String folderName,
  }) async {
    final bytes = await image.readAsBytes();

    final safeName = image.name.replaceAll('/', '_');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';

    final ref = FirebaseStorage.instance
        .ref()
        .child('shop_verify_requests')
        .child(widget.shopId)
        .child(folderName)
        .child(fileName);

    await ref.putData(
      bytes,
      SettableMetadata(contentType: image.mimeType ?? 'image/jpeg'),
    );

    return ref.getDownloadURL();
  }

  bool _validateImages() {
    if (_identityImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請上傳負責人／聯絡人相關證明照片')));
      return false;
    }

    if (_licenseImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請上傳特寵字號證明照片')));
      return false;
    }

    if (_taxIdImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請上傳統編證明照片')));
      return false;
    }

    return true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validateImages()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請重新登入後再送出申請')));
      return;
    }

    setState(() => _submitting = true);

    try {
      final duplicateQuery = await FirebaseFirestore.instance
          .collection('shop_change_requests')
          .where('shopId', isEqualTo: widget.shopId)
          .where('requestType', isEqualTo: 'fullVerify')
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (duplicateQuery.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('此項目已有審核中的申請')));
        return;
      }

      final identityImageUrl = await _uploadImage(
        image: _identityImage!,
        folderName: 'identity',
      );

      String? licenseImageUrl;
      String? taxIdImageUrl;

      if (_licenseImage != null) {
        licenseImageUrl = await _uploadImage(
          image: _licenseImage!,
          folderName: 'license',
        );
      }

      if (_taxIdImage != null) {
        taxIdImageUrl = await _uploadImage(
          image: _taxIdImage!,
          folderName: 'tax_id',
        );
      }

      await FirebaseFirestore.instance.collection('shop_change_requests').add({
        'shopId': widget.shopId,
        'shopName': widget.shopName,
        'requestType': 'fullVerify',
        'currentValue': _currentValueText(),
        'newValue': _currentValueText(),
        'contactName': _contactNameController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'contactTitle': _contactTitleController.text.trim(),
        'contactProofImageUrl': identityImageUrl,
        'licenseImageUrl': licenseImageUrl,
        'taxIdImageUrl': taxIdImageUrl,
        'reason': _noteController.text.trim(),
        'applicantUid': user.uid,
        'applicantEmail': user.email ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('認證申請已送出')));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('送出失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _imageButton({
    required String title,
    required String hint,
    required XFile? image,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _submitting ? null : onPressed,
      icon: Icon(
        image == null ? Icons.add_photo_alternate_outlined : Icons.check_circle,
      ),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          image == null ? '$title\n$hint' : '$title\n已選擇：${image.name}',
          style: const TextStyle(height: 1.4),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactTitleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('認證／平台公開申請')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                '目前申請：${_typeLabel()}\n'
                '目前資料：${_currentValueText().isEmpty ? '尚未填寫' : _currentValueText()}\n\n'
                '平台會依照你填寫的聯絡人資料與上傳照片進行人工審核。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.blue.shade800,
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _contactNameController,
              decoration: const InputDecoration(
                labelText: '聯絡人姓名',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return '請填寫聯絡人姓名';
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _contactPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '聯絡電話',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return '請填寫聯絡電話';
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _contactTitleController,
              decoration: const InputDecoration(
                labelText: '職稱／身分，例如：負責人、店長、管理員',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return '請填寫職稱或身分';
                return null;
              },
            ),

            const SizedBox(height: 16),

            _imageButton(
              title: '負責人／聯絡人相關證明照片（必填）',
              hint: '可上傳名片、店家文件、證照截圖或其他可供平台比對的資料',
              image: _identityImage,
              onPressed: () => _pickImage('identity'),
            ),

            ...[
              const SizedBox(height: 12),
              _imageButton(
                title: '特寵字號證明照片（必填）',
                hint: '請上傳特寵業相關證明文件',
                image: _licenseImage,
                onPressed: () => _pickImage('license'),
              ),
            ],

            ...[
              const SizedBox(height: 12),
              _imageButton(
                title: '統編證明照片（必填）',
                hint: '請上傳統一編號或營業相關證明',
                image: _taxIdImage,
                onPressed: () => _pickImage('taxId'),
              ),
            ],

            const SizedBox(height: 16),

            TextFormField(
              controller: _noteController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '備註／補充說明',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? '送出中' : '送出申請'),
            ),
          ],
        ),
      ),
    );
  }
}
