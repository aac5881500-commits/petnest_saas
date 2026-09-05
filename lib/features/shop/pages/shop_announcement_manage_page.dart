// 檔案名稱：lib/features/shop/pages/shop_announcement_manage_page.dart
// 功能說明：新增、編輯、上架/下架、置頂/取消置頂、刪除店家公告，並支援公告類型與前台公告欄開關
// 📢 店家公告管理頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ShopAnnouncementManagePage extends StatelessWidget {
  const ShopAnnouncementManagePage({super.key, required this.shopId});

  final String shopId;

  static const List<Map<String, dynamic>> _typeOptions = [
    {'label': '一般公告', 'value': 'normal', 'icon': Icons.campaign},
    {'label': '重要公告', 'value': 'important', 'icon': Icons.priority_high},
    {'label': '營業異動', 'value': 'business_hours', 'icon': Icons.schedule},
    {'label': '優惠活動', 'value': 'promotion', 'icon': Icons.card_giftcard},
    {'label': '入住提醒', 'value': 'checkin_notice', 'icon': Icons.pets},
  ];

  static Map<String, dynamic> _typeOption(String value) {
    return _typeOptions.firstWhere(
      (item) => item['value'] == value,
      orElse: () => _typeOptions.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('公告管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAnnouncementDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .doc(shopId)
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final showAnnouncementSection =
                  data?['showAnnouncementSection'] != false;

              return Card(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SwitchListTile(
                  title: const Text(
                    '前台顯示公告欄',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('關閉後，前台首頁不會顯示公告區塊'),
                  value: showAnnouncementSection,
                  onChanged: (value) async {
                    await FirebaseFirestore.instance
                        .collection('shops')
                        .doc(shopId)
                        .set({
                          'showAnnouncementSection': value,
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                  },
                ),
              );
            },
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shops')
                  .doc(shopId)
                  .collection('announcements')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.toList();

                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;

                  final aPinned = aData['isPinned'] == true;
                  final bPinned = bData['isPinned'] == true;

                  if (aPinned != bPinned) {
                    return aPinned ? -1 : 1;
                  }

                  final aTime = aData['createdAt'];
                  final bTime = bData['createdAt'];

                  if (aTime is! Timestamp || bTime is! Timestamp) return 0;

                  return bTime.compareTo(aTime);
                });

                if (docs.isEmpty) {
                  return const Center(child: Text('目前尚無公告'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final title = data['title']?.toString() ?? '未命名公告';
                    final content = data['content']?.toString() ?? '';
                    final isPublished = data['isPublished'] == true;
                    final isPinned = data['isPinned'] == true;
                    final type = data['type']?.toString() ?? 'normal';
                    final typeOption = _typeOption(type);
                    final typeLabel = typeOption['label'] as String;
                    final typeIcon = typeOption['icon'] as IconData;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFFFF1DD),
                              child: Icon(
                                typeIcon,
                                color: const Color(0xFFB86B18),
                              ),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '$typeLabel｜${isPublished ? '已上架' : '未上架'}'
                              '${isPinned ? '｜置頂' : ''}\n'
                              '$content',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                            trailing: Switch(
                              value: isPublished,
                              onChanged: (value) async {
                                await doc.reference.update({
                                  'isPublished': value,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                              },
                            ),
                            onTap: () {
                              _showAnnouncementDialog(
                                context,
                                docId: doc.id,
                                data: data,
                              );
                            },
                          ),

                          const Divider(height: 1),

                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  icon: Icon(
                                    isPinned
                                        ? Icons.push_pin
                                        : Icons.push_pin_outlined,
                                  ),
                                  label: Text(isPinned ? '取消置頂' : '設為置頂'),
                                  onPressed: () async {
                                    await doc.reference.update({
                                      'isPinned': !isPinned,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                  },
                                ),
                              ),

                              Expanded(
                                child: TextButton.icon(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    '刪除',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  onPressed: () async {
                                    await _deleteAnnouncement(
                                      context: context,
                                      docRef: doc.reference,
                                      title: title,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Future<void> _deleteAnnouncement({
    required BuildContext context,
    required DocumentReference docRef,
    required String title,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('刪除公告'),
          content: Text('確定要刪除「$title」嗎？\n\n刪除後會同步移除後台資料，無法復原。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('確認刪除'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await docRef.delete();

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('公告已刪除')));
  }

  void _showAnnouncementDialog(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? data,
  }) {
    final titleController = TextEditingController(
      text: data?['title']?.toString() ?? '',
    );
    final contentController = TextEditingController(
      text: data?['content']?.toString() ?? '',
    );

    String selectedType = data?['type']?.toString() ?? 'normal';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedOption = _typeOption(selectedType);
            final selectedLabel = selectedOption['label'] as String;
            final selectedIcon = selectedOption['icon'] as IconData;

            return AlertDialog(
              title: Text(docId == null ? '新增公告' : '編輯公告'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: '公告類型',
                        border: OutlineInputBorder(),
                      ),
                      items: _typeOptions.map((item) {
                        final label = item['label'] as String;
                        final value = item['value'] as String;
                        final icon = item['icon'] as IconData;

                        return DropdownMenuItem<String>(
                          value: value,
                          child: Row(
                            children: [
                              Icon(icon, size: 18),
                              const SizedBox(width: 8),
                              Text(label),
                            ],
                          ),
                        );
                      }).toList(),
                      selectedItemBuilder: (context) {
                        return _typeOptions.map((item) {
                          return Row(
                            children: [
                              Icon(selectedIcon, size: 18),
                              const SizedBox(width: 8),
                              Text(selectedLabel),
                            ],
                          );
                        }).toList();
                      },
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '公告標題',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: contentController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: '公告內容',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final content = contentController.text.trim();

                    if (title.isEmpty) return;

                    final ref = FirebaseFirestore.instance
                        .collection('shops')
                        .doc(shopId)
                        .collection('announcements');

                    if (docId == null) {
                      await ref.add({
                        'title': title,
                        'content': content,
                        'type': selectedType,
                        'isPublished': true,
                        'isPinned': false,
                        'createdAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    } else {
                      await ref.doc(docId).update({
                        'title': title,
                        'content': content,
                        'type': selectedType,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
