// lib/features/admin/pages/admin_member_list_page.dart
// 👤 會員管理（穩定完整版🔥）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_detail_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_merge_page.dart';

class AdminMemberListPage extends StatefulWidget {
  const AdminMemberListPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<AdminMemberListPage> createState() => _AdminMemberListPageState();
}

class _AdminMemberListPageState extends State<AdminMemberListPage> {
  String keyword = '';
  String memberFilter = 'activeAll';
  final List<Map<String, String>> memberFilters = const [
    {'key': 'activeAll', 'label': '全部'},
    {'key': 'app', 'label': '店家會員'},
    {'key': 'admin', 'label': '手動新增'},
    {'key': 'archived', 'label': '封存'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('會員管理')),
      body: Column(
        children: [
          /// 🔍 搜尋
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜尋姓名 / 電話',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  keyword = value.trim();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.merge_type, color: Colors.deepPurple),
                title: const Text(
                  '會員合併管理',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('掃描同電話會員並進行合併'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminMemberMergePage(shopId: widget.shopId),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: memberFilters.map((filter) {
                  final selected = memberFilter == filter['key'];

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter['label']!),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          memberFilter = filter['key']!;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          /// 📦 列表
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shops')
                  .doc(widget.shopId)
                  .collection('members')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  return {
                    ...data,
                    'userId': doc.id,
                    'bookingCount': data['bookingCount'] ?? 0,
                    'tags': data['tags'] ?? [],
                  };
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('查無會員'));
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _filterMembersWithProfile(docs),
                  builder: (context, memberSnapshot) {
                    if (!memberSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final visibleDocs = memberSnapshot.data!;

                    if (visibleDocs.isEmpty) {
                      return const Center(child: Text('查無會員'));
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.52,
                          ),
                      itemCount: visibleDocs.length,
                      itemBuilder: (context, index) {
                        final data = visibleDocs[index];

                        final userId = data['userId']?.toString() ?? '';
                        final rawName = data['name']?.toString().trim() ?? '';
                        final rawPhone = data['phone']?.toString().trim() ?? '';
                        final rawEmail = data['email']?.toString().trim() ?? '';

                        final name = rawName.isEmpty ? '未填姓名' : rawName;
                        final phone = rawPhone.isEmpty ? '未填電話' : rawPhone;
                        final email = rawEmail.isEmpty ? '無Email' : rawEmail;

                        String adminNote1 =
                            data['adminNote1']?.toString() ?? '';

                        int petCount = (data['petCount'] ?? 0).toInt();
                        List<String> tags = List<String>.from(
                          data['tags'] ?? [],
                        );
                        String displayName = name;
                        String displayPhone = phone;
                        String displayEmail = email;

                        final isBlacklisted =
                            data['blacklisted'] == true ||
                            data['isBlocked'] == true;

                        final source = data['source']?.toString() == 'admin'
                            ? 'admin'
                            : 'app';
                        final sourceLabel = source == 'admin' ? '手動新增' : '店家會員';
                        final sourceColor = source == 'admin'
                            ? Colors.purple
                            : Colors.blue;

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminMemberDetailPage(
                                  userId: userId,
                                  shopId: widget.shopId,
                                ),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      /// 📦 右邊資訊
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            /// 👤 名字 + 標籤
                                            const SizedBox(height: 8),

                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    displayName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),

                                                _memberBadge(
                                                  text: sourceLabel,
                                                  color: sourceColor,
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 8),

                                            /// 📞 電話
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.phone,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    displayPhone,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 6),

                                            /// 📧 Email
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.email,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    displayEmail,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _miniInfoBox(
                                              icon: Icons.pets,
                                              color: Colors.orange,
                                              label: '寵物數量',
                                              value:
                                                  '${data['petCount'] ?? 0} 隻',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _miniInfoBox(
                                              icon: Icons.receipt_long,
                                              color: Colors.blue,
                                              label: '訂單數量',
                                              value:
                                                  '${data['bookingCount'] ?? 0} 筆',
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 8),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: _miniInfoBox(
                                              icon: Icons.block,
                                              color:
                                                  source == 'app' &&
                                                      isBlacklisted
                                                  ? Colors.red
                                                  : Colors.grey,
                                              label: '黑名單',
                                              value:
                                                  source == 'app' &&
                                                      isBlacklisted
                                                  ? '是'
                                                  : '否',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _miniInfoBox(
                                              icon: Icons.star,
                                              color: tags.contains('vip')
                                                  ? Colors.amber
                                                  : Colors.grey,
                                              label: '常客',
                                              value: tags.contains('vip')
                                                  ? '是'
                                                  : '否',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  if (adminNote1.isNotEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.orange.shade100,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '📝 店家備註',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade800,
                                            ),
                                          ),

                                          const SizedBox(height: 4),

                                          Text(
                                            adminNote1,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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

  Widget _memberBadge({required String text, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(right: 6, top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _miniInfoBox({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _normalizePhoneForSearch(String value) {
    String digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('09')) {
      digits = digits.substring(2);
    }

    return digits;
  }

  Future<List<Map<String, dynamic>>> _filterMembersWithProfile(
    List<Map<String, dynamic>> docs,
  ) async {
    return docs.where((data) {
      final status = data['status']?.toString() ?? '';
      final source = data['source']?.toString().trim().isNotEmpty == true
          ? data['source'].toString()
          : 'app';
      final name = data['name']?.toString().toLowerCase() ?? '';
      final phone = data['phone']?.toString().toLowerCase() ?? '';
      final normalizedPhone = _normalizePhoneForSearch(phone);

      final email = data['email']?.toString().toLowerCase() ?? '';
      final searchText = keyword.toLowerCase();
      final normalizedSearchText = _normalizePhoneForSearch(searchText);

      if (status == 'merged') {
        return false;
      }

      if (memberFilter == 'archived') {
        if (status != 'archived') return false;
      } else {
        if (status == 'archived') return false;
      }

      if (memberFilter == 'app' && source != 'app') {
        return false;
      }

      if (memberFilter == 'admin' && source != 'admin') {
        return false;
      }

      if (searchText.isNotEmpty &&
          !name.contains(searchText) &&
          !phone
              .replaceAll(RegExp(r'[^0-9]'), '')
              .contains(searchText.replaceAll(RegExp(r'[^0-9]'), '')) &&
          !normalizedPhone.contains(normalizedSearchText) &&
          !email.contains(searchText)) {
        return false;
      }

      return true;
    }).toList();
  }
}
