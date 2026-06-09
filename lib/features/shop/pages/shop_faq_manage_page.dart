// lib/features/shop/pages/shop_faq_manage_page.dart
// ❓ 店家常見問題管理頁
// 功能：新增、編輯、刪除、上架/下架、上移/下移排序店家常見問題

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ShopFaqManagePage extends StatelessWidget {
  const ShopFaqManagePage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('常見問題管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showFaqDialog(context);
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
              final showFaqSection = data?['showFaqSection'] != false;

              return Card(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SwitchListTile(
                  title: const Text(
                    '前台顯示常見問題',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('關閉後，前台首頁不會顯示常見問題入口'),
                  value: showFaqSection,
                  onChanged: (value) async {
                    await FirebaseFirestore.instance
                        .collection('shops')
                        .doc(shopId)
                        .set({
                          'showFaqSection': value,
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
                  .collection('faqs')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.toList();

                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;

                  final aSort = aData['sortOrder'] ?? 999;
                  final bSort = bData['sortOrder'] ?? 999;

                  return aSort.compareTo(bSort);
                });

                if (docs.isEmpty) {
                  return const Center(child: Text('目前尚無常見問題'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final question = data['question']?.toString() ?? '未命名問題';
                    final answer = data['answer']?.toString() ?? '';
                    final isPublished = data['isPublished'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFFFF1DD),
                              child: Icon(
                                Icons.help_outline,
                                color: Color(0xFFB86B18),
                              ),
                            ),
                            title: Text(
                              question,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${isPublished ? '已上架' : '未上架'}\n$answer',
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
                              _showFaqDialog(
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
                                  icon: const Icon(Icons.keyboard_arrow_up),
                                  label: const Text('上移'),
                                  onPressed: index == 0
                                      ? null
                                      : () async {
                                          await _swapFaqOrder(
                                            currentDoc: doc,
                                            targetDoc: docs[index - 1],
                                          );
                                        },
                                ),
                              ),

                              Expanded(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                  label: const Text('下移'),
                                  onPressed: index == docs.length - 1
                                      ? null
                                      : () async {
                                          await _swapFaqOrder(
                                            currentDoc: doc,
                                            targetDoc: docs[index + 1],
                                          );
                                        },
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.edit),
                                  label: const Text('編輯'),
                                  onPressed: () {
                                    _showFaqDialog(
                                      context,
                                      docId: doc.id,
                                      data: data,
                                    );
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
                                    await _deleteFaq(
                                      context: context,
                                      docRef: doc.reference,
                                      question: question,
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

  Future<void> _swapFaqOrder({
    required QueryDocumentSnapshot currentDoc,
    required QueryDocumentSnapshot targetDoc,
  }) async {
    final currentData = currentDoc.data() as Map<String, dynamic>;
    final targetData = targetDoc.data() as Map<String, dynamic>;

    final currentSort = currentData['sortOrder'] ?? 999;
    final targetSort = targetData['sortOrder'] ?? 999;

    final batch = FirebaseFirestore.instance.batch();

    batch.update(currentDoc.reference, {
      'sortOrder': targetSort,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(targetDoc.reference, {
      'sortOrder': currentSort,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> _deleteFaq({
    required BuildContext context,
    required DocumentReference docRef,
    required String question,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('刪除常見問題'),
          content: Text('確定要刪除「$question」嗎？\n\n刪除後無法復原。'),
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
    ).showSnackBar(const SnackBar(content: Text('常見問題已刪除')));
  }

  void _showFaqDialog(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? data,
  }) {
    final questionController = TextEditingController(
      text: data?['question']?.toString() ?? '',
    );

    final answerController = TextEditingController(
      text: data?['answer']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(docId == null ? '新增常見問題' : '編輯常見問題'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  decoration: const InputDecoration(
                    labelText: '問題',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: answerController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '回答',
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
                final question = questionController.text.trim();
                final answer = answerController.text.trim();

                if (question.isEmpty) return;

                final ref = FirebaseFirestore.instance
                    .collection('shops')
                    .doc(shopId)
                    .collection('faqs');

                if (docId == null) {
                  final count = (await ref.get()).docs.length;

                  await ref.add({
                    'question': question,
                    'answer': answer,
                    'sortOrder': count + 1,
                    'isPublished': true,
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  await ref.doc(docId).update({
                    'question': question,
                    'answer': answer,
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
  }
}
