// lib/features/admin/pages/admin_member_list_page.dart
// 👤 會員管理（穩定完整版🔥）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_detail_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_link_request_page.dart';

class AdminMemberListPage extends StatefulWidget {
  const AdminMemberListPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<AdminMemberListPage> createState() => _AdminMemberListPageState();
}

class _AdminMemberListPageState extends State<AdminMemberListPage> {
  String keyword = '';
  bool showArchived = false;

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
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 8),
              child: TextButton.icon(
                icon: Icon(showArchived ? Icons.people : Icons.archive),
                label: Text(showArchived ? '查看正常會員' : '查看封存會員'),
                onPressed: () {
                  setState(() {
                    showArchived = !showArchived;
                  });
                },
              ),
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('member_link_requests')
                .where('shopId', isEqualTo: widget.shopId)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;

              if (count <= 0) {
                return const SizedBox();
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.link, color: Colors.red),
                    title: const Text(
                      '會員綁定申請',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('目前有 $count 筆待確認申請'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminMemberLinkRequestPage(shopId: widget.shopId),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          /// 📦 列表
          Expanded(
            child: showArchived
                ? _buildArchivedMembers()
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('bookings')
                        .where('shopId', isEqualTo: widget.shopId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final bookingDocs = snapshot.data!.docs;

                      final userMap = <String, Map<String, dynamic>>{};

                      for (final doc in bookingDocs) {
                        final data = doc.data() as Map<String, dynamic>;

                        final userId = data['userId'];

                        if (userId == null) continue;

                        if (!userMap.containsKey(userId)) {
                          userMap[userId] = {
                            'userId': userId,
                            'name': data['customerName'] ?? '',
                            'phone': data['customerPhone'] ?? '',
                            'email': data['customerEmail'] ?? '',
                            'bookingCount': 0,
                            'tags': [],
                          };
                        }

                        userMap[userId]!['bookingCount'] =
                            (userMap[userId]!['bookingCount'] ?? 0) + 1;
                        final startDate = data['startDate'];

                        if (startDate != null) {
                          final currentLatest =
                              userMap[userId]!['latestStartDate'];

                          if (currentLatest == null ||
                              startDate.compareTo(currentLatest) > 0) {
                            userMap[userId]!['latestStartDate'] = startDate;

                            userMap[userId]!['latestRoomName'] =
                                data['roomName'] ?? '';

                            userMap[userId]!['latestEndDate'] = data['endDate'];
                          }
                        }
                      }

                      final docs = userMap.values.toList();

                      if (docs.isEmpty) {
                        return const Center(child: Text('查無會員'));
                      }

                      return FutureBuilder<List<Map<String, dynamic>>>(
                        future: _filterMembersWithProfile(docs),
                        builder: (context, memberSnapshot) {
                          if (!memberSnapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
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
                              final name =
                                  data['name']?.toString().isEmpty == true
                                  ? '未填姓名'
                                  : data['name'].toString();
                              final phone =
                                  data['phone']?.toString().isEmpty == true
                                  ? '未填電話'
                                  : data['phone'].toString();
                              final email =
                                  data['email']?.toString().isEmpty == true
                                  ? '無Email'
                                  : data['email'].toString();

                              final latestRoomName =
                                  data['latestRoomName']?.toString() ?? '';
                              final latestStartDate = data['latestStartDate'];
                              final latestEndDate = data['latestEndDate'];

                              final latestDateText =
                                  latestStartDate is Timestamp &&
                                      latestEndDate is Timestamp
                                  ? '${_formatDateShort(latestStartDate)}-${_formatDateShort(latestEndDate)}'
                                  : '';

                              String adminNote1 =
                                  data['adminNote1']?.toString() ?? '';

                              return FutureBuilder<List<dynamic>>(
                                future: Future.wait([
                                  FirebaseFirestore.instance
                                      .collection('user_profiles')
                                      .doc(userId)
                                      .collection('pets')
                                      .get(),
                                  FirebaseFirestore.instance
                                      .collection('user_profiles')
                                      .doc(userId)
                                      .get(),
                                ]),
                                builder: (context, profileSnapshot) {
                                  int petCount = 0;
                                  List<String> tags = [];
                                  bool isBlacklisted = false;
                                  String displayName = name;
                                  String displayPhone = phone;
                                  String displayEmail = email;

                                  if (profileSnapshot.hasData) {
                                    final petsSnap =
                                        profileSnapshot.data![0]
                                            as QuerySnapshot;
                                    final userSnap =
                                        profileSnapshot.data![1]
                                            as DocumentSnapshot;

                                    petCount = petsSnap.docs.length;

                                    final profileData =
                                        userSnap.data()
                                            as Map<String, dynamic>?;

                                    tags = List<String>.from(
                                      profileData?['tags'] ?? [],
                                    );

                                    final profileName =
                                        profileData?['name']?.toString() ?? '';

                                    final profilePhone =
                                        profileData?['phone']?.toString() ?? '';

                                    final profileEmail =
                                        profileData?['email']?.toString() ?? '';

                                    displayName = profileName.isNotEmpty
                                        ? profileName
                                        : name;

                                    displayPhone = profilePhone.isNotEmpty
                                        ? profilePhone
                                        : phone;

                                    displayEmail = profileEmail.isNotEmpty
                                        ? profileEmail
                                        : email;
                                    final profileNote =
                                        profileData?['adminNote1']
                                            ?.toString() ??
                                        '';

                                    adminNote1 = profileNote;
                                  }

                                  return StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('shops')
                                        .doc(widget.shopId)
                                        .collection('members')
                                        .doc(userId)
                                        .snapshots(),
                                    builder: (context, shopMemberSnapshot) {
                                      final shopMemberData =
                                          shopMemberSnapshot.data?.data()
                                              as Map<String, dynamic>?;

                                      final isBlacklisted =
                                          shopMemberData?['blacklisted'] ==
                                          true;

                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  AdminMemberDetailPage(
                                                    userId: userId,
                                                    shopId: widget.shopId,
                                                  ),
                                            ),
                                          );
                                        },
                                        child: Card(
                                          elevation: 5,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    /// 📦 右邊資訊
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          /// 👤 名字 + 標籤
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  displayName,
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        20,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w900,
                                                                  ),
                                                                ),
                                                              ),

                                                              if (tags.contains(
                                                                'vip',
                                                              ))
                                                                Container(
                                                                  margin:
                                                                      const EdgeInsets.only(
                                                                        left: 6,
                                                                      ),
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            4,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: Colors
                                                                        .orange
                                                                        .shade50,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          20,
                                                                        ),
                                                                  ),
                                                                  child: Text(
                                                                    '⭐ 常客',
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .orange
                                                                          .shade800,
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),

                                                              if (isBlacklisted)
                                                                Container(
                                                                  margin:
                                                                      const EdgeInsets.only(
                                                                        left: 6,
                                                                      ),
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            4,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: Colors
                                                                        .red
                                                                        .shade50,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          20,
                                                                        ),
                                                                  ),
                                                                  child: Text(
                                                                    '🚫 黑名單',
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .red
                                                                          .shade700,
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),

                                                          const SizedBox(
                                                            height: 8,
                                                          ),

                                                          /// 📞 電話
                                                          Row(
                                                            children: [
                                                              const Icon(
                                                                Icons.phone,
                                                                size: 16,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  displayPhone,
                                                                  style:
                                                                      const TextStyle(
                                                                        fontSize:
                                                                            15,
                                                                      ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),

                                                          const SizedBox(
                                                            height: 6,
                                                          ),

                                                          /// 📧 Email
                                                          Row(
                                                            children: [
                                                              const Icon(
                                                                Icons.email,
                                                                size: 16,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  displayEmail,
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color: Colors
                                                                        .grey,
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

                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _miniInfoBox(
                                                        icon: Icons.pets,
                                                        color: Colors.orange,
                                                        label: '寵物',
                                                        value: '$petCount 隻',
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: _miniInfoBox(
                                                        icon:
                                                            Icons.receipt_long,
                                                        color: Colors.blue,
                                                        label: '訂單',
                                                        value:
                                                            '${data['bookingCount'] ?? 0} 筆',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),

                                                if (latestRoomName.isNotEmpty)
                                                  Container(
                                                    width: double.infinity,
                                                    margin:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.green.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const Text(
                                                          '最近入住',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          latestRoomName,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            color: Colors
                                                                .green
                                                                .shade800,
                                                          ),
                                                        ),
                                                        if (latestDateText
                                                            .isNotEmpty)
                                                          Text(
                                                            latestDateText,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .green
                                                                  .shade700,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),

                                                if (adminNote1.isNotEmpty)
                                                  Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 8,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.orange.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .orange
                                                            .shade100,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          '📝 店家備註',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors
                                                                .orange
                                                                .shade800,
                                                          ),
                                                        ),

                                                        const SizedBox(
                                                          height: 4,
                                                        ),

                                                        Text(
                                                          adminNote1,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey
                                                                .shade800,
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

  Widget _miniInfoBox({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11)),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _filterMembersWithProfile(
    List<Map<String, dynamic>> docs,
  ) async {
    final result = <Map<String, dynamic>>[];

    for (final data in docs) {
      final userId = data['userId']?.toString() ?? '';

      if (userId.isEmpty) continue;

      final profileSnap = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(userId)
          .get();

      final profileData = profileSnap.data() ?? {};

      final status = profileData['status']?.toString() ?? '';

      if (status == 'archived') continue;

      result.add({...data, 'profileData': profileData});
    }

    return result;
  }

  String _formatDate(Timestamp value) {
    final dt = value.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  String _formatDateShort(Timestamp value) {
    final dt = value.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.month)}/${two(dt.day)}';
  }

  Widget _buildArchivedMembers() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_profiles')
          .where('status', isEqualTo: 'archived')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final shopIds = List<String>.from(data['shopIds'] ?? []);
          return shopIds.contains(widget.shopId);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('目前沒有封存會員'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.archive),
                title: Text(data['name'] ?? '未填姓名'),
                subtitle: Text('電話：${data['phone'] ?? '未填'}\n封存會員'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminMemberDetailPage(
                        userId: doc.id,
                        shopId: widget.shopId,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
