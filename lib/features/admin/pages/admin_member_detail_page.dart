// lib/features/admin/pages/admin_member_detail_page.dart
// 👤 後台會員詳細頁（改為 shops/{shopId}/members 為主資料來源）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/admin/widgets/admin_member_booking_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_member_detail_badges.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_review_list_page.dart';

class AdminMemberDetailPage extends StatelessWidget {
  const AdminMemberDetailPage({
    super.key,
    required this.userId,
    required this.shopId,
  });

  final String userId;
  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('會員詳細')),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMemberProfile(),

            const SizedBox(height: 20),

            _sectionTitle(
              icon: Icons.note_alt_outlined,
              color: Colors.orange,
              title: '店家備註',
            ),

            _buildAdminNote(),

            _sectionTitle(
              icon: Icons.pets,
              color: Colors.orange,
              title: '寵物資料',
            ),

            _buildMemberPets(),

            _sectionTitle(
              icon: Icons.description_outlined,
              color: Colors.teal,
              title: '條款同意紀錄',
            ),

            _buildPolicyRecord(),

            _sectionTitle(
              icon: Icons.star_rate_rounded,
              color: Colors.amber,
              title: '我的評價',
            ),

            _buildMemberReviewsEntry(memberName: '會員'),

            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ExpansionTile(
                initiallyExpanded: false,
                leading: const Icon(Icons.receipt_long, color: Colors.blue),
                title: const Text(
                  '訂單紀錄',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('bookings')
                        .where('shopId', isEqualTo: shopId)
                        .where('userId', isEqualTo: userId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text('訂單讀取失敗：${snapshot.error}');
                      }

                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        );
                      }

                      final bookings = snapshot.data!.docs.toList();

                      if (bookings.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('無訂單'),
                        );
                      }

                      return Column(
                        children: bookings.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;

                          return AdminMemberBookingCard(
                            bookingId: doc.id,
                            data: data,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ExpansionTile(
                initiallyExpanded: false,
                leading: const Icon(Icons.history, color: Colors.purple),
                title: const Text(
                  '操作紀錄',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('action_logs')
                        .where('shopId', isEqualTo: shopId)
                        .where('targetUserId', isEqualTo: userId)
                        .limit(20)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text('操作紀錄讀取失敗：${snapshot.error}');
                      }

                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        );
                      }

                      final logs = snapshot.data!.docs.toList();

                      logs.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;

                        final aTime = aData['createdAt'];
                        final bTime = bData['createdAt'];

                        if (aTime is! Timestamp || bTime is! Timestamp)
                          return 0;

                        return bTime.compareTo(aTime);
                      });

                      if (logs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('尚無操作紀錄'),
                        );
                      }

                      return Column(
                        children: logs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _logTitle(data['type']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('操作人：${data['operatorEmail'] ?? '未知操作人'}'),
                                if ((data['reason'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Text('原因：${data['reason']}'),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(data['createdAt']),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberReviewsEntry({required String memberName}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('shopId', isEqualTo: shopId)
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final count = snapshot.data!.docs.length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.star_rate_rounded, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  count == 0 ? '這位會員尚未留下評價' : '這位會員共有 $count 筆評價',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton(
                onPressed: count == 0
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminMemberReviewListPage(
                              shopId: shopId,
                              userId: userId,
                              memberName: memberName,
                            ),
                          ),
                        );
                      },
                child: const Text('查看評價'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPolicyRecord() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('shopId', isEqualTo: shopId)
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('條款紀錄讀取失敗：${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final bookings = snapshot.data!.docs.toList();

        bookings.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aTime = aData['createdAt'];
          final bTime = bData['createdAt'];

          if (aTime is! Timestamp || bTime is! Timestamp) return 0;

          return bTime.compareTo(aTime);
        });

        Map<String, dynamic>? policyData;

        for (final doc in bookings) {
          final data = doc.data() as Map<String, dynamic>;

          if (data['policyAcceptedAt'] != null ||
              data['policyVersion'] != null ||
              data['policyTitle'] != null) {
            policyData = data;
            break;
          }
        }

        String text = '尚無條款同意紀錄。';

        if (policyData != null) {
          final title = (policyData['policyTitle'] ?? '入住須知').toString();
          final version = (policyData['policyVersion'] ?? '').toString();
          final acceptedAt = _formatTime(policyData['policyAcceptedAt']);

          text = '已同意 $title\n版本：v$version\n同意時間：$acceptedAt';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(text),
        );
      },
    );
  }

  Widget _buildAdminNote() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final note = (data['adminNote1'] ?? '').toString();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(note.isEmpty ? '尚無店家備註' : note),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _editAdminNote(context, note),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('編輯備註'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editAdminNote(BuildContext context, String currentNote) async {
    final controller = TextEditingController(text: currentNote);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('店家備註'),
          content: TextField(
            controller: controller,
            maxLines: 6,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: '輸入店家備註...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .doc(userId)
        .set({
          'adminNote1': result,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('店家備註已更新')));
    }
  }

  Future<void> _editManualMember(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final nameController = TextEditingController(
      text: (data['name'] ?? '').toString(),
    );
    final emergencyContact = data['emergencyContact'] is Map
        ? Map<String, dynamic>.from(data['emergencyContact'])
        : <String, dynamic>{};

    final emergencyNameController = TextEditingController(
      text: (emergencyContact['name'] ?? '').toString(),
    );
    final emergencyPhoneController = TextEditingController(
      text: (emergencyContact['phone'] ?? '').toString(),
    );
    String emergencyRelation =
        (emergencyContact['relation'] ?? '').toString().isEmpty
        ? '父母'
        : (emergencyContact['relation'] ?? '').toString();
    final emergencyAddressController = TextEditingController(
      text: (emergencyContact['address'] ?? '').toString(),
    );
    final addressController = TextEditingController(
      text: (data['address'] ?? '').toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('編輯手動會員資料'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '姓名'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: '地址'),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '緊急聯絡人',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emergencyNameController,
                  decoration: const InputDecoration(labelText: '緊急聯絡人姓名'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: '緊急聯絡人電話'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: emergencyRelation,
                  decoration: const InputDecoration(labelText: '關係'),
                  items: const [
                    DropdownMenuItem(value: '父母', child: Text('父母')),
                    DropdownMenuItem(value: '夫妻', child: Text('夫妻')),
                    DropdownMenuItem(value: '配偶', child: Text('配偶')),
                    DropdownMenuItem(value: '兄弟姊妹', child: Text('兄弟姊妹')),
                    DropdownMenuItem(value: '情侶', child: Text('情侶')),
                    DropdownMenuItem(value: '朋友', child: Text('朋友')),
                    DropdownMenuItem(value: '其他', child: Text('其他')),
                  ],
                  onChanged: (value) {
                    emergencyRelation = value ?? '父母';
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emergencyAddressController,
                  decoration: const InputDecoration(labelText: '緊急聯絡人地址'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final newName = nameController.text.trim();
    final newPhone = (data['phone'] ?? '').toString().trim();

    if (newName.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('請輸入會員姓名')));
      }
      return;
    }

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .doc(userId)
        .set({
          'name': newName,
          'phone': newPhone,
          'address': addressController.text.trim(),
          'emergencyContact': {
            'name': emergencyNameController.text.trim(),
            'phone': emergencyPhoneController.text.trim(),
            'relation': emergencyRelation,
            'address': emergencyAddressController.text.trim(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    final bookingsSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('userId', isEqualTo: userId)
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in bookingsSnapshot.docs) {
      batch.set(doc.reference, {
        'customerName': newName,
        'customerPhone': newPhone,
        'customerAddress': addressController.text.trim(),
        'customer': {
          'name': newName,
          'phone': newPhone,
          'address': addressController.text.trim(),
        },
        'emergencyContact': {
          'name': emergencyNameController.text.trim(),
          'phone': emergencyPhoneController.text.trim(),
          'relation': emergencyRelation,
          'address': emergencyAddressController.text.trim(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();

    nameController.dispose();
    addressController.dispose();
    emergencyNameController.dispose();
    emergencyPhoneController.dispose();
    emergencyAddressController.dispose();

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('手動會員資料已更新')));
    }
  }

  Future<void> _editManualPet(
    BuildContext context,
    Map<String, dynamic> pet,
  ) async {
    final petId = pet['petId']?.toString() ?? '';

    final nameController = TextEditingController(
      text: (pet['name'] ?? '').toString(),
    );
    final breedController = TextEditingController(
      text: (pet['breed'] ?? '').toString(),
    );
    String vaccine = (pet['vaccine'] ?? '').toString().isEmpty
        ? '無'
        : (pet['vaccine'] ?? '').toString();

    if (vaccine != '無' &&
        vaccine != '慢性腎臟病' &&
        vaccine != '心臟病' &&
        vaccine != '糖尿病' &&
        vaccine != '術後照護' &&
        vaccine != '皮膚疾病') {
      vaccine = '無';
    }
    String litterType = (pet['litterType'] ?? '').toString().isEmpty
        ? '豆腐砂'
        : (pet['litterType'] ?? '').toString();

    if (litterType != '豆腐砂' && litterType != '礦砂') {
      litterType = '豆腐砂';
    }
    final noteController = TextEditingController(
      text: (pet['note'] ?? '').toString(),
    );
    String gender = (pet['gender'] ?? '').toString();

    if (gender != '公貓' && gender != '母貓') {
      gender = '母貓';
    }

    String age = (pet['age'] ?? '').toString();

    if (age != '6~12個月' &&
        age != '1~10歲' &&
        age != '10~12歲' &&
        age != '12歲以上') {
      age = '1~10歲';
    }

    bool isNeutered = pet['isNeutered'] == true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('編輯寵物資料'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '寵物名字'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: gender,
                      decoration: const InputDecoration(labelText: '性別'),
                      items: const [
                        DropdownMenuItem(value: '公貓', child: Text('公貓')),
                        DropdownMenuItem(value: '母貓', child: Text('母貓')),
                      ],
                      onChanged: (value) {
                        gender = value ?? '母貓';
                      },
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: age,
                      decoration: const InputDecoration(labelText: '年齡'),
                      items: const [
                        DropdownMenuItem(
                          value: '6~12個月',
                          child: Text('含6~12個月'),
                        ),
                        DropdownMenuItem(value: '1~10歲', child: Text('1~10歲')),
                        DropdownMenuItem(
                          value: '10~12歲',
                          child: Text('10~12歲'),
                        ),
                        DropdownMenuItem(value: '12歲以上', child: Text('12歲以上')),
                      ],
                      onChanged: (value) {
                        age = value ?? '1~10歲';
                      },
                    ),
                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('是否已結紮'),
                      value: isNeutered,
                      onChanged: (value) {
                        setDialogState(() {
                          isNeutered = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: breedController,
                      decoration: const InputDecoration(labelText: '品種'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: vaccine,
                      decoration: const InputDecoration(labelText: '疫苗 / 醫療狀況'),
                      items: const [
                        DropdownMenuItem(value: '無', child: Text('無')),
                        DropdownMenuItem(value: '慢性腎臟病', child: Text('慢性腎臟病')),
                        DropdownMenuItem(value: '心臟病', child: Text('心臟病')),
                        DropdownMenuItem(value: '糖尿病', child: Text('糖尿病')),
                        DropdownMenuItem(value: '術後照護', child: Text('術後照護')),
                        DropdownMenuItem(value: '皮膚疾病', child: Text('皮膚治療')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          vaccine = value ?? '無';
                        });
                      },
                    ),

                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: litterType,
                      decoration: const InputDecoration(labelText: '貓砂'),
                      items: const [
                        DropdownMenuItem(value: '豆腐砂', child: Text('豆腐砂')),
                        DropdownMenuItem(value: '礦砂', child: Text('礦砂')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          litterType = value ?? '豆腐砂';
                        });
                      },
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: '備註'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || petId.isEmpty) return;

    final newName = nameController.text.trim();

    if (newName.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('請輸入寵物名字')));
      }
      return;
    }

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .doc(userId)
        .collection('pets')
        .doc(petId)
        .set({
          'name': newName,
          'gender': gender,
          'age': age,
          'isNeutered': isNeutered,
          'breed': breedController.text.trim(),
          'vaccine': vaccine,
          'litterType': litterType,
          'note': noteController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    nameController.dispose();
    breedController.dispose();
    noteController.dispose();

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('寵物資料已更新')));
    }
  }

  Widget _buildMemberPets() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
          .doc(userId)
          .collection('pets')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('寵物資料讀取失敗：${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final pets = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {'petId': doc.id, ...data};
        }).toList();

        if (pets.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('尚無寵物資料'),
          );
        }

        return Column(
          children: pets.map((pet) {
            final name = (pet['name'] ?? '未命名寵物').toString();
            final type = (pet['type'] ?? '未填種類').toString();
            final gender = (pet['gender'] ?? '未填性別').toString();
            final breed = (pet['breed'] ?? '未填品種').toString();
            final age = (pet['age'] ?? '未填年齡').toString();
            final vaccine = (pet['vaccine'] ?? '未填疫苗').toString();
            final litterType = (pet['litterType'] ?? '未填貓砂').toString();
            final isNeutered = pet['isNeutered'];
            final note = (pet['note'] ?? '').toString();
            final photoUrl = (pet['photoUrl'] ?? pet['imageUrl'] ?? '')
                .toString();

            final neuteredText = isNeutered == true
                ? '已結紮'
                : isNeutered == false
                ? '未結紮'
                : '未填結紮';
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.orange.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.orange.shade50,
                    backgroundImage: photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl.isEmpty
                        ? const Icon(Icons.pets, color: Colors.orange, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),

                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('shops')
                                  .doc(shopId)
                                  .collection('members')
                                  .doc(userId)
                                  .snapshots(),
                              builder: (context, memberSnapshot) {
                                final member =
                                    memberSnapshot.data?.data()
                                        as Map<String, dynamic>? ??
                                    {};

                                final isManual = member['source'] == 'admin';

                                if (!isManual) {
                                  return const SizedBox();
                                }

                                return IconButton(
                                  tooltip: '編輯寵物',
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.deepPurple,
                                  ),
                                  onPressed: () {
                                    _editManualPet(context, pet);
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _petInfoChip('種類', type),
                            _petInfoChip('性別', gender),
                            _petInfoChip('年齡', age),
                          ],
                        ),

                        const SizedBox(height: 10),

                        _buildPetInfoRow(Icons.category_outlined, '品種', breed),
                        _buildPetInfoRow(Icons.content_cut, '結紮', neuteredText),
                        _buildPetInfoRow(Icons.favorite_outline, '疫苗', vaccine),
                        _buildPetInfoRow(
                          Icons.grass_outlined,
                          '貓砂',
                          litterType,
                        ),
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '備註：$note',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _petInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Text(
        '$label：$value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPetInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text('$title：', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildMemberProfile() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('會員資料讀取失敗：${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

        final name = (data['name']?.toString().trim() ?? '').isEmpty
            ? '未填姓名'
            : data['name'].toString();

        final phone = (data['phone']?.toString().trim() ?? '').isEmpty
            ? '未填電話'
            : data['phone'].toString();

        final email = (data['email']?.toString().trim() ?? '').isEmpty
            ? '無Email'
            : data['email'].toString();

        final source = data['source']?.toString() == 'admin' ? 'admin' : 'app';
        final sourceLabel = source == 'admin' ? '手動新增' : '店家會員';
        final sourceColor = source == 'admin' ? Colors.purple : Colors.blue;

        final tags = List<String>.from(data['tags'] ?? []);
        final isVip = tags.contains('vip');

        final isBlocked =
            data['blacklisted'] == true || data['isBlocked'] == true;

        final petCount = data['petCount'] ?? 0;
        final bookingCount = data['bookingCount'] ?? 0;
        final addressText = (data['address'] ?? '').toString().trim();
        final emergencyContact = data['emergencyContact'] is Map
            ? Map<String, dynamic>.from(data['emergencyContact'])
            : <String, dynamic>{};

        final emergencyName = (emergencyContact['name'] ?? '')
            .toString()
            .trim();
        final emergencyPhone = (emergencyContact['phone'] ?? '')
            .toString()
            .trim();
        final emergencyRelation = (emergencyContact['relation'] ?? '')
            .toString()
            .trim();
        final emergencyAddress = (emergencyContact['address'] ?? '')
            .toString()
            .trim();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue.shade50,
                    child: const Icon(Icons.person, color: Colors.blue),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            adminMemberSmallBadge(sourceLabel, sourceColor),
                            if (source == 'app')
                              adminMemberSmallBadge(
                                isBlocked ? '黑名單' : '非黑名單',
                                isBlocked ? Colors.red : Colors.grey,
                              ),
                            adminMemberSmallBadge(
                              isVip ? '常客' : '一般會員',
                              isVip ? Colors.amber : Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Text('電話：$phone'),
              const SizedBox(height: 6),
              Text('Email：$email'),
              const SizedBox(height: 6),
              Text('地址：${addressText.isEmpty ? '未填地址' : addressText}'),
              const SizedBox(height: 6),
              Text(
                '緊急聯絡人：${emergencyName.isEmpty ? '未填' : emergencyName}'
                '${emergencyRelation.isEmpty ? '' : '（$emergencyRelation）'}'
                '${emergencyPhone.isEmpty ? '' : '｜$emergencyPhone'}',
              ),
              if (emergencyAddress.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('緊急聯絡人地址：$emergencyAddress'),
              ],

              const SizedBox(height: 16),
              if (source == 'admin' && phone != '未填電話') ...[
                _buildSamePhoneMemberHint(phone),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 14),

              if (source == 'app') ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleBlacklist(context, data),
                    icon: Icon(
                      isBlocked ? Icons.lock_open : Icons.block,
                      color: isBlocked ? Colors.green : Colors.red,
                    ),
                    label: Text(
                      isBlocked ? '解除黑名單' : '加入黑名單',
                      style: TextStyle(
                        color: isBlocked ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isBlocked ? Colors.green : Colors.red,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _toggleVip(context, data),
                  icon: Icon(
                    isVip ? Icons.star_border : Icons.star,
                    color: isVip ? Colors.grey : Colors.amber,
                  ),
                  label: Text(
                    isVip ? '取消常客' : '設為常客',
                    style: TextStyle(
                      color: isVip ? Colors.grey : Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isVip ? Colors.grey : Colors.amber),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              if (source == 'admin') ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _editManualMember(context, data),
                    icon: const Icon(Icons.edit),
                    label: const Text('編輯會員資料'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      side: const BorderSide(color: Colors.deepPurple),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (source == 'admin') ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleArchive(context, data),
                    icon: Icon(
                      data['status'] == 'archived'
                          ? Icons.unarchive
                          : Icons.archive_outlined,
                    ),
                    label: Text(data['status'] == 'archived' ? '解除封存' : '封存會員'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueGrey,
                      side: const BorderSide(color: Colors.blueGrey),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (source == 'admin') ...[
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteMember(context, data),
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text(
                      '刪除會員',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
              Row(
                children: [
                  Expanded(
                    child: _infoBox(
                      icon: Icons.pets,
                      color: Colors.orange,
                      label: '寵物數',
                      value: '$petCount',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _infoBox(
                      icon: Icons.receipt_long,
                      color: Colors.blue,
                      label: '訂單數',
                      value: '$bookingCount',
                    ),
                  ),
                  if (source == 'app') ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _infoBox(
                        icon: Icons.verified_user,
                        color: isBlocked ? Colors.red : Colors.grey,
                        label: isBlocked ? '黑名單' : '一般',
                        value: '會員',
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSamePhoneMemberHint(String phone) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
          .where('phone', isEqualTo: phone)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final matches = snapshot.data!.docs.where((doc) {
          if (doc.id == userId) return false;

          final data = doc.data() as Map<String, dynamic>;
          return data['source'] == 'app';
        }).toList();

        if (matches.isEmpty) return const SizedBox();

        final targetDoc = matches.first;
        final targetData = targetDoc.data() as Map<String, dynamic>;
        final targetName = (targetData['name'] ?? '未命名會員').toString();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '偵測到同電話的店家會員：$targetName',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '之後可將此手動會員的訂單合併到店家會員。',
                style: TextStyle(color: Colors.brown),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) {
                      return AlertDialog(
                        title: const Text('合併訂單確認'),
                        content: Text(
                          '之後會把此手動會員的訂單合併到「$targetName」。\n\n'
                          '這一步目前先確認畫面，尚未真的執行合併。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('知道了'),
                          ),
                        ],
                      );
                    },
                  );
                },
                icon: const Icon(Icons.merge_type),
                label: const Text('合併訂單'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleBlacklist(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final ref = FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .doc(userId);

    final isBlacklisted =
        data['blacklisted'] == true || data['isBlocked'] == true;
    final user = FirebaseAuth.instance.currentUser;

    if (isBlacklisted) {
      await ref.set({
        'blacklisted': false,
        'isBlocked': false,
        'blacklistReason': FieldValue.delete(),
        'blacklistedAt': FieldValue.delete(),
        'blacklistRemovedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('action_logs').add({
        'type': 'member_blacklist_removed',
        'shopId': shopId,
        'targetUserId': userId,
        'targetUserName': data['name'] ?? '',
        'targetUserEmail': data['email'] ?? '',
        'operatorUid': user?.uid,
        'operatorEmail': user?.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return;
    }

    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('加入黑名單原因'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '例如：惡意取消、未付款、攻擊店員',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('確認加入'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;

    final tags = List<String>.from(data['tags'] ?? []);
    tags.remove('vip');

    await ref.set({
      'blacklisted': true,
      'isBlocked': true,
      'tags': tags,
      'blacklistReason': reason,
      'blacklistedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('action_logs').add({
      'type': 'member_blacklisted',
      'shopId': shopId,
      'targetUserId': userId,
      'targetUserName': data['name'] ?? '',
      'targetUserEmail': data['email'] ?? '',
      'operatorUid': user?.uid,
      'operatorEmail': user?.email,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Widget _sectionTitle({
    required IconData icon,
    required Color color,
    required String title,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleVip(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final ref = FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .doc(userId);

    final tags = List<String>.from(data['tags'] ?? []);
    final isVip = tags.contains('vip');
    final user = FirebaseAuth.instance.currentUser;

    final isBlacklisted =
        data['blacklisted'] == true || data['isBlocked'] == true;

    if (isBlacklisted && !isVip) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('黑名單會員不能設為常客')));
      return;
    }

    if (isVip) {
      tags.remove('vip');

      await ref.set({
        'tags': tags,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('action_logs').add({
        'type': 'member_vip_removed',
        'shopId': shopId,
        'targetUserId': userId,
        'targetUserName': data['name'] ?? '',
        'targetUserEmail': data['email'] ?? '',
        'operatorUid': user?.uid,
        'operatorEmail': user?.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return;
    }

    tags.add('vip');

    await ref.set({
      'tags': tags,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('action_logs').add({
      'type': 'member_vip_added',
      'shopId': shopId,
      'targetUserId': userId,
      'targetUserName': data['name'] ?? '',
      'targetUserEmail': data['email'] ?? '',
      'operatorUid': user?.uid,
      'operatorEmail': user?.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _toggleArchive(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final isArchived = data['status'] == 'archived';
    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .doc(userId)
        .set({
          'status': isArchived ? 'active' : 'archived',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('action_logs').add({
      'type': isArchived ? 'member_unarchived' : 'member_archived',
      'shopId': shopId,
      'targetUserId': userId,
      'targetUserName': data['name'] ?? '',
      'targetUserEmail': data['email'] ?? '',
      'operatorUid': user?.uid,
      'operatorEmail': user?.email,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(isArchived ? '已解除封存' : '已封存會員')));
    }
  }

  Future<void> _deleteMember(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final memberName = (data['name'] ?? '此會員').toString();

    final source = (data['source'] ?? '').toString();

    if (source != 'admin') {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('店家會員不可刪除，只能刪除手動新增會員')));
      }
      return;
    }
    final bookingsSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('userId', isEqualTo: userId)
        .get();

    final bookings = bookingsSnapshot.docs;

    final blockedBookings = bookings.where((doc) {
      final status = (doc.data()['status'] ?? '').toString().trim();

      return status != 'cancelled';
    }).toList();

    if (blockedBookings.isNotEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('此會員仍有非取消訂單，不能刪除')));
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('確認刪除會員？'),
          content: Text('將刪除「$memberName」會員資料、寵物資料，以及此會員所有已取消訂單。\n\n此操作無法復原。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認刪除'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    final batch = FirebaseFirestore.instance.batch();

    final memberRef = FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .doc(userId);

    final petsSnapshot = await memberRef.collection('pets').get();

    for (final petDoc in petsSnapshot.docs) {
      batch.delete(petDoc.reference);
    }

    for (final bookingDoc in bookings) {
      final status = (bookingDoc.data()['status'] ?? '').toString().trim();
      if (status == 'cancelled') {
        batch.delete(bookingDoc.reference);
      }
    }

    batch.delete(memberRef);

    final logRef = FirebaseFirestore.instance.collection('action_logs').doc();

    batch.set(logRef, {
      'type': 'member_deleted',
      'shopId': shopId,
      'targetUserId': userId,
      'targetUserName': data['name'] ?? '',
      'targetUserEmail': data['email'] ?? '',
      'operatorUid': user?.uid,
      'operatorEmail': user?.email,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('會員已刪除')));

      Navigator.pop(context);
    }
  }

  Widget _infoBox({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _logTitle(dynamic typeValue) {
    final type = typeValue?.toString() ?? '';

    switch (type) {
      case 'member_blacklisted':
        return '加入黑名單';
      case 'member_link_approved':
        return '確認會員綁定';
      case 'member_link_rejected':
        return '拒絕會員綁定';
      case 'member_blacklist_removed':
        return '解除黑名單';
      case 'member_vip_added':
        return '設為常客';
      case 'member_vip_removed':
        return '取消常客';
      case 'member_archived':
        return '封存會員';
      case 'member_unarchived':
        return '解除封存';
      case 'member_deleted':
        return '刪除會員';
      default:
        return type.isEmpty ? '操作紀錄' : type;
    }
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '-';

    final dt = value.toDate();
    String two(int n) => n.toString().padLeft(2, '0');

    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}
