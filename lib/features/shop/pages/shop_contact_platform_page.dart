// 檔案名稱：lib/features/shop/pages/shop_contact_platform_page.dart
// 功能說明：店主查看自己的聯絡平台案件，並建立新案件後進入聊天室。

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:petnest_saas/features/shop/pages/shop_contact_request_detail_page.dart';
import 'package:petnest_saas/features/support/contact_case_labels.dart';

class ShopContactPlatformPage extends StatefulWidget {
  const ShopContactPlatformPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopContactPlatformPage> createState() =>
      _ShopContactPlatformPageState();
}

class _ShopContactPlatformPageState extends State<ShopContactPlatformPage> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _requests;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      _requests = null;
      return;
    }
    _requests = FirebaseFirestore.instance
        .collection('platform_contact_requests')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  void _openCreate() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ShopContactRequestCreatePage(shopId: widget.shopId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('聯絡平台'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonal(
              onPressed: _openCreate,
              child: const Text('建立案件'),
            ),
          ),
        ],
      ),
      body: _requests == null
          ? const _EmptyPane(title: '請先登入', message: '登入後才能查看你的案件。')
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _requests,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                  ) {
                    if (snapshot.hasError) {
                      return _EmptyPane(
                        title: '案件讀取失敗',
                        message: '請確認網路與權限後再試。',
                        action: '重試',
                        onPressed: () => setState(_listen),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    docs = snapshot.data!.docs.where((
                      QueryDocumentSnapshot<Map<String, dynamic>> doc,
                    ) {
                      final Map<String, dynamic> data = doc.data();
                      return (data['source'] ?? '').toString() ==
                              'shop_owner' &&
                          (data['shopId'] ?? '').toString() == widget.shopId;
                    }).toList()..sort(_newestFirst);
                    if (docs.isEmpty) {
                      return _EmptyPane(
                        title: '還沒有案件',
                        message: '每個問題建立一筆案件，之後可在同一案件繼續補充。',
                        action: '建立案件',
                        onPressed: _openCreate,
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: docs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                            docs[index];
                        return _CaseTile(requestId: doc.id, data: doc.data());
                      },
                    );
                  },
            ),
    );
  }
}

class ShopContactRequestCreatePage extends StatefulWidget {
  const ShopContactRequestCreatePage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopContactRequestCreatePage> createState() =>
      _ShopContactRequestCreatePageState();
}

class _PendingImage {
  const _PendingImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class _ShopContactRequestCreatePageState
    extends State<ShopContactRequestCreatePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<_PendingImage> _images = <_PendingImage>[];

  static const int _maxImageCount = 3;
  static const int _maxImageBytes = 5 * 1024 * 1024;

  String _category = contactCaseCategories.first;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_submitting) {
      return;
    }
    final int remain = _maxImageCount - _images.length;
    if (remain <= 0) {
      _toast('最多只能上傳 3 張照片');
      return;
    }
    final List<XFile> picked = await _picker.pickMultiImage(
      imageQuality: 85,
      limit: remain,
    );
    if (picked.isEmpty || !mounted) {
      return;
    }
    final List<_PendingImage> accepted = <_PendingImage>[];
    for (final XFile image in picked) {
      final Uint8List bytes = await image.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        if (mounted) {
          _toast('${image.name} 超過 5MB，已略過');
        }
        continue;
      }
      accepted.add(_PendingImage(name: image.name, bytes: bytes));
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _images.addAll(accepted.take(remain));
    });
  }

  Future<List<String>> _upload(String requestId, String userId) async {
    final List<String> urls = <String>[];
    for (int i = 0; i < _images.length; i++) {
      final _PendingImage image = _images[i];
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${i}_${image.name}';
      final Reference ref = FirebaseStorage.instance
          .ref()
          .child('platform_contact_requests')
          .child(requestId)
          .child(fileName);
      final TaskSnapshot upload = await ref.putData(
        image.bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: <String, String>{
            'shopId': widget.shopId,
            'userId': userId,
            'source': 'shop_owner',
          },
        ),
      );
      urls.add(await upload.ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('請先登入');
      return;
    }
    setState(() => _submitting = true);
    try {
      final DocumentSnapshot<Map<String, dynamic>> shopDoc =
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(widget.shopId)
              .get();
      final Map<String, dynamic> shop = shopDoc.data() ?? <String, dynamic>{};
      final DocumentReference<Map<String, dynamic>> docRef = FirebaseFirestore
          .instance
          .collection('platform_contact_requests')
          .doc();
      final List<String> imageUrls = await _upload(docRef.id, user.uid);
      final FieldValue now = FieldValue.serverTimestamp();
      final String title = _title.text.trim();
      final String content = _content.text.trim();
      await docRef.set(<String, dynamic>{
        'source': 'shop_owner',
        'shopId': widget.shopId,
        'shopName': (shop['name'] ?? '').toString(),
        'shopCode': (shop['shopCode'] ?? '').toString(),
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'category': _category,
        'title': title,
        'content': content,
        'imageUrls': imageUrls,
        'imageCount': imageUrls.length,
        'status': 'open',
        'lastMessage': content,
        'lastSenderType': 'shop_owner',
        'createdAt': now,
        'updatedAt': now,
      });
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ShopContactRequestDetailPage(requestId: docRef.id),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _toast('送出失敗，內容已保留');
      debugPrint('建立聯絡案件失敗：$error');
      setState(() => _submitting = false);
    }
  }

  Future<void> _pickCategory() async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: contactCaseCategories.map((String item) {
              return ListTile(
                title: Text(item),
                trailing: item == _category ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetContext, item),
              );
            }).toList(),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _category = picked);
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final bool phone = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('建立案件')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: <Widget>[
                      const Text(
                        '送出後可在同一案件繼續補充，不必重新填表。',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      if (phone)
                        _CategoryButton(
                          category: _category,
                          enabled: !_submitting,
                          onTap: _pickCategory,
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: const InputDecoration(labelText: '問題分類'),
                          items: contactCaseCategories
                              .map(
                                (String item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: _submitting
                              ? null
                              : (String? value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() => _category = value);
                                },
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _title,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: '標題',
                          hintText: '例如：訂單列表無法正常顯示',
                        ),
                        validator: (String? value) {
                          final String text = (value ?? '').trim();
                          if (text.isEmpty) {
                            return '請輸入標題';
                          }
                          if (text.length < 3) {
                            return '標題至少 3 個字';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _content,
                        enabled: !_submitting,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: '問題內容',
                          alignLabelWithHint: true,
                          hintText: '請寫下頁面、操作步驟與錯誤情況',
                        ),
                        validator: (String? value) {
                          final String text = (value ?? '').trim();
                          if (text.isEmpty) {
                            return '請輸入問題內容';
                          }
                          if (text.length < 10) {
                            return '內容至少 10 個字';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _AttachmentBox(
                        images: _images,
                        submitting: _submitting,
                        onPick: _pickImages,
                        onRemove: (int index) {
                          if (_submitting) {
                            return;
                          }
                          setState(() => _images.removeAt(index));
                        },
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: Text(_submitting ? '送出中' : '建立並開始對話'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.category,
    required this.enabled,
    required this.onTap,
  });

  final String category;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: '問題分類'),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(category)),
            const Icon(Icons.expand_more),
          ],
        ),
      ),
    );
  }
}

class _AttachmentBox extends StatelessWidget {
  const _AttachmentBox({
    required this.images,
    required this.submitting,
    required this.onPick,
    required this.onRemove,
  });

  final List<_PendingImage> images;
  final bool submitting;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('附件 ${images.length}/3　每張最多 5MB'),
            if (images.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List<Widget>.generate(images.length, (int index) {
                  return Stack(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          images[index].bytes,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: InkWell(
                          onTap: () => onRemove(index),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: submitting || images.length >= 3 ? null : onPick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('選擇照片'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.requestId, required this.data});

  final String requestId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String status = (data['status'] ?? 'open').toString();
    final String title = (data['title'] ?? '未填標題').toString();
    final String category = (data['category'] ?? '未分類').toString();
    final String when = _timeText(data['updatedAt'] ?? data['createdAt']);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  ShopContactRequestDetailPage(requestId: requestId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusLabel(status: status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$category　$when',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                contactCaseSummary(data),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (status) {
      'processing' => (const Color(0xFF1D4ED8), const Color(0xFFEFF6FF)),
      'closed' => (const Color(0xFF475569), const Color(0xFFF1F5F9)),
      _ => (const Color(0xFFB45309), const Color(0xFFFFF7ED)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        contactCaseStatusLabel(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({
    required this.title,
    required this.message,
    this.action,
    this.onPressed,
  });

  final String title;
  final String message;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.forum_outlined,
              size: 36,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton(onPressed: onPressed, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

int _newestFirst(
  QueryDocumentSnapshot<Map<String, dynamic>> a,
  QueryDocumentSnapshot<Map<String, dynamic>> b,
) {
  final int left = _millis(a.data()['updatedAt'] ?? a.data()['createdAt']);
  final int right = _millis(b.data()['updatedAt'] ?? b.data()['createdAt']);
  return right.compareTo(left);
}

String _timeText(Object? value) {
  final DateTime? time = _date(value);
  if (time == null) {
    return '-';
  }
  return '${contactDayLabel(time)} ${contactClockLabel(time)}';
}

DateTime? _date(Object? value) {
  if (value is Timestamp) {
    return value.toDate().toLocal();
  }
  return null;
}

int _millis(Object? value) {
  return _date(value)?.millisecondsSinceEpoch ?? 0;
}
