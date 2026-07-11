// lib/features/shop/pages/shop_contact_platform_page.dart
// 📮 店主聯絡平台頁
// 功能：店主從後台送出問題，寫入 Firestore 給平台後台處理，可附最多 3 張照片

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/features/shop/pages/shop_contact_request_detail_page.dart';

class ShopContactPlatformPage extends StatefulWidget {
  const ShopContactPlatformPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopContactPlatformPage> createState() =>
      _ShopContactPlatformPageState();
}

class _ShopContactPlatformPageState extends State<ShopContactPlatformPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];

  static const int _maxImageCount = 3;
  static const int _maxImageBytes = 5 * 1024 * 1024; // 5MB

  String _category = '功能問題';
  bool _isSubmitting = false;

  final List<String> _categories = const [
    '功能問題',
    '帳號 / 權限',
    '店家資料',
    '訂單 / 預約',
    '付款 / 訂金',
    '建議回饋',
    '其他',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_isSubmitting) return;

    final remainCount = _maxImageCount - _images.length;

    if (remainCount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('最多只能上傳 3 張照片')));
      return;
    }

    final pickedImages = await _picker.pickMultiImage(
      imageQuality: 85,
      limit: remainCount,
    );

    if (pickedImages.isEmpty) return;

    final validImages = <XFile>[];

    for (final image in pickedImages) {
      final bytes = await image.length();

      if (bytes > _maxImageBytes) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${image.name} 超過 5MB，已略過')));
        continue;
      }

      validImages.add(image);
    }

    if (!mounted) return;

    setState(() {
      _images.addAll(validImages.take(remainCount));
    });
  }

  void _removeImage(int index) {
    if (_isSubmitting) return;

    setState(() {
      _images.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages({
    required String requestId,
    required String userId,
  }) async {
    final urls = <String>[];

    for (int i = 0; i < _images.length; i++) {
      final image = _images[i];
      final bytes = await image.readAsBytes();

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${i}_${image.name}';

      final ref = FirebaseStorage.instance
          .ref()
          .child('platform_contact_requests')
          .child(requestId)
          .child(fileName);

      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'shopId': widget.shopId,
            'userId': userId,
            'source': 'shop_owner',
          },
        ),
      );

      final url = await uploadTask.ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先登入')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final shopDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .get();

      final shopData = shopDoc.data() ?? {};
      final shopName = (shopData['name'] ?? '').toString();
      final shopCode = (shopData['shopCode'] ?? '').toString();

      final docRef = FirebaseFirestore.instance
          .collection('platform_contact_requests')
          .doc();

      final imageUrls = await _uploadImages(
        requestId: docRef.id,
        userId: user.uid,
      );

      final now = FieldValue.serverTimestamp();

      await docRef.set({
        'source': 'shop_owner',
        'shopId': widget.shopId,
        'shopName': shopName,
        'shopCode': shopCode,
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'category': _category,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'imageUrls': imageUrls,
        'imageCount': imageUrls.length,
        'status': 'open',
        'createdAt': now,
        'updatedAt': now,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已送出，平台會在後台看到這筆聯絡紀錄')));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('送出失敗：$e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('附加照片', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              '最多 3 張，每張限制 5MB。可上傳錯誤畫面、截圖或相關照片。',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),

            if (_images.isNotEmpty)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(_images.length, (index) {
                  final image = _images[index];

                  return Stack(
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: FutureBuilder<List<int>>(
                          future: image.readAsBytes(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                snapshot.data! as dynamic,
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: InkWell(
                          onTap: () => _removeImage(index),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(3),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),

            if (_images.isNotEmpty) const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _isSubmitting || _images.length >= _maxImageCount
                  ? null
                  : _pickImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text('選擇照片 ${_images.length}/$_maxImageCount'),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'open':
        return '待處理';
      case 'processing':
        return '處理中';
      case 'closed':
        return '已關閉';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.red;
      case 'processing':
        return Colors.orange;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return '-';
    return DateFormat('yyyy/MM/dd HH:mm').format(value.toDate());
  }

  Widget _buildMyRequestList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('platform_contact_requests')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('案件讀取失敗：${snapshot.error}'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data?.docs ?? [];

        final docs =
            allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return (data['source'] ?? '').toString() == 'shop_owner' &&
                  (data['shopId'] ?? '').toString() == widget.shopId;
            }).toList()..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;

              final aTime = aData['updatedAt'];
              final bTime = bData['updatedAt'];

              if (aTime is Timestamp && bTime is Timestamp) {
                return bTime.compareTo(aTime);
              }

              return 0;
            });

        if (docs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '目前沒有案件紀錄',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            final status = (data['status'] ?? 'open').toString();
            final title = (data['title'] ?? '未填標題').toString();
            final category = (data['category'] ?? '未分類').toString();
            final lastMessage = (data['lastMessage'] ?? '').toString();
            final updatedAtText = _formatDate(data['updatedAt']);

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _statusColor(status).withOpacity(0.12),
                  child: Icon(Icons.support_agent, color: _statusColor(status)),
                ),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('分類：$category'),
                      Text('狀態：${_statusText(status)}'),
                      Text('更新：$updatedAtText'),
                      if (lastMessage.isNotEmpty)
                        Text(
                          '最後訊息：$lastMessage',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ShopContactRequestDetailPage(requestId: doc.id),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF7),
      appBar: AppBar(
        title: const Text('聯絡平台'),
        backgroundColor: const Color(0xFFFFFCF7),
        surfaceTintColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  '這裡不是寄 Email，而是送出一筆平台聯絡案件。平台後台之後可以查看、回覆與關閉案件。',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: '問題分類',
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _category = value);
                    },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _titleController,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: '標題',
                hintText: '例如：訂單列表無法正常顯示',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '請輸入標題';
                }
                if (value.trim().length < 3) {
                  return '標題至少 3 個字';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _contentController,
              enabled: !_isSubmitting,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: '問題內容',
                hintText: '請描述你遇到的狀況，包含頁面名稱、操作步驟、錯誤畫面等',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '請輸入問題內容';
                }
                if (value.trim().length < 10) {
                  return '內容至少 10 個字，方便平台判斷問題';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            _buildImageSection(),

            const SizedBox(height: 24),

            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSubmitting ? '送出中...' : '送出給平台'),
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              '我的案件紀錄',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            _buildMyRequestList(),
          ],
        ),
      ),
    );
  }
}
