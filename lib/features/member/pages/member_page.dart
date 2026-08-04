// lib/features/member/pages/member_page.dart
// 👤 會員中心頁（完整版：含電話輸入）

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:petnest_saas/features/pet/pages/pet_detail_page.dart';
import 'package:petnest_saas/features/pet/pages/add_pet_page.dart';
import 'package:petnest_saas/features/booking/pages/my_bookings_page.dart';
import 'package:petnest_saas/core/constants/taiwan_city_data.dart';
import 'package:petnest_saas/features/booking/pages/my_reviews_page.dart';
import 'package:petnest_saas/features/member/pages/member_point_detail_page.dart';
import 'package:petnest_saas/features/member/pages/member_coupon_page.dart';
import 'package:petnest_saas/core/services/notification_service.dart';
import 'package:petnest_saas/features/notifications/pages/notification_center_page.dart';
import 'package:petnest_saas/features/notifications/pages/notification_setting_page.dart';
import 'package:petnest_saas/features/member/pages/member_point_redemption_page.dart';

class MemberPage extends StatefulWidget {
  const MemberPage({super.key, required this.shopId, this.shopName = ''});

  final String shopId;
  final String shopName;

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();

  String? _city;
  String? _district;
  final TextEditingController _detailAddressController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  /// 🚨 緊急聯絡人
  final TextEditingController _emergencyNameController =
      TextEditingController();
  final TextEditingController _emergencyPhoneController =
      TextEditingController();
  final TextEditingController _emergencyRelationController =
      TextEditingController();
  String _emergencyRelation = '父母';
  final TextEditingController _emergencyAddressController =
      TextEditingController();

  bool _sameAsOwner = false;
  bool _editingProfile = false;
  bool _editingAddress = false;
  bool _editingEmergency = false;
  bool _hasSyncedMember = false;
  String? _validateName(String? value) {
    final text = (value ?? '').trim();

    if (text.isEmpty) {
      return '請輸入姓名';
    }

    if (text.length < 2) {
      return '姓名至少 2 個字';
    }

    final validNameRegex = RegExp(r'^[\u4e00-\u9fa5a-zA-Z\s．·.-]+$');

    if (!validNameRegex.hasMatch(text)) {
      return '姓名只能輸入中文、英文';
    }

    return null;
  }

  String? _validateTaiwanPhone(String? value) {
    final text = (value ?? '').trim();

    if (text.isEmpty) {
      return '請輸入電話';
    }

    final phoneRegex = RegExp(r'^09\d{8}$');

    if (!phoneRegex.hasMatch(text)) {
      return '請輸入 09 開頭的 10 碼手機號碼';
    }

    return null;
  }

  Future<void> _syncMemberByEmail(User user) async {
    final result = await FirebaseFirestore.instance
        .collection('user_profiles')
        .where('email', isEqualTo: user.email)
        .limit(1)
        .get();

    if (result.docs.isEmpty) return;

    final oldDoc = result.docs.first;
    if (oldDoc.id == user.uid) return;

    final oldData = oldDoc.data();

    await FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(user.uid)
        .set({
          ...oldData,
          'uid': user.uid,
          'linkedAuthUid': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _createMemberLinkRequest({
    required User user,
    required String phone,
  }) async {
    final samePhoneResult = await FirebaseFirestore.instance
        .collection('user_profiles')
        .where('phone', isEqualTo: phone)
        .limit(10)
        .get();

    final oldDocs = samePhoneResult.docs.where((doc) {
      final data = doc.data();
      final linkedAuthUid = data['linkedAuthUid']?.toString() ?? '';

      return doc.id != user.uid && linkedAuthUid.isEmpty;
    }).toList();

    if (oldDocs.isEmpty) return;

    final oldDoc = oldDocs.first;

    final oldData = oldDoc.data();

    final linkedAuthUid = oldData['linkedAuthUid']?.toString() ?? '';
    if (linkedAuthUid.isNotEmpty) return;

    final exists = await FirebaseFirestore.instance
        .collection('member_link_requests')
        .where('authUid', isEqualTo: user.uid)
        .where('targetUserId', isEqualTo: oldDoc.id)
        .limit(1)
        .get();

    if (exists.docs.isNotEmpty) {
      final requestDoc = exists.docs.first;
      final requestData = requestDoc.data();

      final status = requestData['status']?.toString() ?? '';

      if (status == 'pending' || status == 'approved') {
        return;
      }

      if (status == 'rejected') {
        await requestDoc.reference.update({
          'status': 'pending',
          'resentAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return;
      }
    }
    await FirebaseFirestore.instance.collection('member_link_requests').add({
      'shopId':
          oldData['shopId'] ??
          ((oldData['shopIds'] is List && oldData['shopIds'].isNotEmpty)
              ? oldData['shopIds'].first
              : ''),
      'authUid': user.uid,
      'authEmail': user.email ?? '',
      'targetUserId': oldDoc.id,
      'targetName': oldData['name'] ?? '',
      'targetPhone': phone,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _showDeleteAccountDialog(User user) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('申請刪除帳號'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '送出申請後，平台會人工審核你的帳號刪除需求。\n\n'
                '若帳號內仍有尚未完成的預約、付款、退款或爭議紀錄，'
                '平台可能會先協助確認後再處理。\n\n'
                '完成後，平台會依服務條款與資料保存規範處理你的會員資料、'
                '寵物資料與相關紀錄。',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '刪除原因（可不填）',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('送出申請'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      reasonController.dispose();
      return;
    }

    final existing = await FirebaseFirestore.instance
        .collection('account_delete_requests')
        .where('uid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      reasonController.dispose();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('你已經送出刪除帳號申請，平台會盡快處理')));
      return;
    }

    await FirebaseFirestore.instance.collection('account_delete_requests').add({
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': user.displayName ?? '',
      'reason': reasonController.text.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    reasonController.dispose();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已送出刪除帳號申請，平台會盡快處理')));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !_hasSyncedMember) {
      _hasSyncedMember = true;
      _syncMemberByEmail(user);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('會員中心'),
        actions: [
          StreamBuilder<int>(
            stream: NotificationService.instance.unreadCountStream(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;

              return IconButton(
                tooltip: '通知中心',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationCenterPage(),
                    ),
                  );
                },
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (unreadCount > 0)
                      Positioned(
                        top: -6,
                        right: -7,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: user == null
              ? const Center(child: Text('尚未登入'))
              : StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('user_profiles')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>?;

                    final phone = data?['phone'] ?? '';
                    if (_nameController.text.isEmpty) {
                      _nameController.text = data?['name'] ?? '';
                    }

                    final address = data?['address'] ?? '';
                    // 🔥 拆地址（會員 → UI）
                    if (address.isNotEmpty && _city == null) {
                      final cityList = [
                        '台北市',
                        '新北市',
                        '桃園市',
                        '台中市',
                        '台南市',
                        '高雄市',
                        '新竹縣',
                        '苗栗縣',
                        '彰化縣',
                        '南投縣',
                        '雲林縣',
                        '嘉義縣',
                        '屏東縣',
                        '宜蘭縣',
                        '花蓮縣',
                        '台東縣',
                        '澎湖縣',
                        '金門縣',
                        '連江縣',
                      ];

                      for (final city in cityList) {
                        if (address.startsWith(city)) {
                          _city = city;

                          final districts = cityData[city] ?? [];

                          for (final d in districts) {
                            if (address.contains(d)) {
                              _district = d;
                              break;
                            }
                          }

                          break;
                        }
                      }

                      if (_detailAddressController.text.isEmpty) {
                        String detail = address;

                        if (_city != null && detail.startsWith(_city!)) {
                          detail = detail.replaceFirst(_city!, '');
                        }

                        if (_district != null &&
                            detail.startsWith(_district!)) {
                          detail = detail.replaceFirst(_district!, '');
                        }

                        _detailAddressController.text = detail;
                      }
                    } // ✅ 這個一定要有
                    final emergency = data?['emergencyContact'];

                    if (emergency != null && !_sameAsOwner) {
                      if (_emergencyNameController.text.isEmpty) {
                        _emergencyNameController.text = emergency['name'] ?? '';
                      }
                      if (_emergencyPhoneController.text.isEmpty) {
                        _emergencyPhoneController.text =
                            emergency['phone'] ?? '';
                      }
                      if (_emergencyRelationController.text.isEmpty) {
                        _emergencyRelationController.text =
                            emergency['relation'] ?? '父母';
                        _emergencyRelation = _emergencyRelationController.text;
                      }
                      if (_emergencyAddressController.text.isEmpty) {
                        _emergencyAddressController.text =
                            emergency['address'] ?? '';
                      }
                    }

                    /// 🔥 讓欄位帶入初始值（避免覆蓋輸入）
                    if (_phoneController.text.isEmpty) {
                      _phoneController.text = phone;
                    }
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((data?['linkedAuthUid'] ?? '')
                              .toString()
                              .isNotEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.green.shade100,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.verified_user,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '已完成會員綁定，原本的寵物與訂單資料已帶入此帳號，請留意寵物有重複記得刪除。',
                                      style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (_editingProfile ||
                              _editingAddress ||
                              _editingEmergency)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.amber.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.amber.shade800,
                                  ),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: Text(
                                      '你有尚未儲存的資料，記得按下方「儲存資料」',
                                      style: TextStyle(
                                        color: Colors.amber.shade900,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          _buildSectionCard(
                            title: '我的資料',
                            children: [
                              if (!_editingProfile) ...[
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Colors.blue.shade50,
                                    child: const Icon(Icons.person),
                                  ),
                                  title: Text(
                                    _nameController.text.isEmpty
                                        ? '尚未填寫姓名'
                                        : _nameController.text,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_phoneController.text}\n${user.email ?? ''}',
                                  ),
                                  isThreeLine: true,
                                  trailing: TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _editingProfile = true;
                                      });
                                    },
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('編輯'),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'Email：${user.email ?? ''}',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),

                                const SizedBox(height: 12),

                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: '飼主姓名',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: _validateName,
                                ),
                                const SizedBox(height: 12),

                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: '電話',
                                    hintText: '09xxxxxxxx',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: _validateTaiwanPhone,
                                ),

                                const SizedBox(height: 12),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _editingProfile = false;
                                        _editingAddress = false;
                                        _editingEmergency = false;
                                      });
                                    },
                                    icon: const Icon(Icons.close),
                                    label: const Text('取消編輯'),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          _buildSectionCard(
                            title: '地址資料',
                            children: [
                              if (!_editingAddress) ...[
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Colors.green.shade50,
                                    child: const Icon(Icons.location_on),
                                  ),
                                  title: const Text(
                                    '地址',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_city ?? ''}${_district ?? ''}${_detailAddressController.text}',
                                  ),
                                  trailing: TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _editingAddress = true;
                                      });
                                    },
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('編輯'),
                                  ),
                                ),
                              ] else ...[
                                DropdownButtonFormField<String>(
                                  value: _city,
                                  decoration: const InputDecoration(
                                    labelText: '縣市',
                                    border: UnderlineInputBorder(),
                                  ),
                                  items: cityData.keys.map((city) {
                                    return DropdownMenuItem(
                                      value: city,
                                      child: Text(city),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _city = value;
                                      _district = null;
                                    });
                                  },
                                ),

                                const SizedBox(height: 16),

                                DropdownButtonFormField<String>(
                                  value: _district,
                                  decoration: const InputDecoration(
                                    labelText: '區域',
                                    border: UnderlineInputBorder(),
                                  ),
                                  items:
                                      (_city == null
                                              ? <String>[]
                                              : cityData[_city]!)
                                          .map<DropdownMenuItem<String>>((d) {
                                            return DropdownMenuItem<String>(
                                              value: d,
                                              child: Text(d),
                                            );
                                          })
                                          .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _district = value;
                                    });
                                  },
                                ),

                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _detailAddressController,
                                  decoration: const InputDecoration(
                                    labelText: '詳細地址',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => v!.isEmpty ? '請輸入地址' : null,
                                ),

                                const SizedBox(height: 12),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _editingProfile = false;
                                        _editingAddress = false;
                                        _editingEmergency = false;
                                      });
                                    },
                                    icon: const Icon(Icons.close),
                                    label: const Text('取消編輯'),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          _buildSectionCard(
                            title: '緊急聯絡人',
                            children: [
                              if (!_editingEmergency) ...[
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Colors.red.shade50,
                                    child: const Icon(Icons.emergency),
                                  ),
                                  title: Text(
                                    _emergencyNameController.text.isEmpty
                                        ? '尚未填寫緊急聯絡人'
                                        : _emergencyNameController.text,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_emergencyRelationController.text}\n${_emergencyPhoneController.text}',
                                  ),
                                  isThreeLine: true,
                                  trailing: TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _editingEmergency = true;
                                      });
                                    },
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('編輯'),
                                  ),
                                ),
                              ] else ...[
                                TextFormField(
                                  controller: _emergencyNameController,
                                  decoration: const InputDecoration(
                                    labelText: '緊急聯絡人姓名',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: _validateName,
                                ),

                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _emergencyPhoneController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: '緊急聯絡人電話',
                                    hintText: '09xxxxxxxx',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: _validateTaiwanPhone,
                                ),

                                const SizedBox(height: 16),

                                DropdownButtonFormField<String>(
                                  value: _emergencyRelation,
                                  decoration: const InputDecoration(
                                    labelText: '關係',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: '父母',
                                      child: Text('父母'),
                                    ),
                                    DropdownMenuItem(
                                      value: '夫妻',
                                      child: Text('夫妻'),
                                    ),
                                    DropdownMenuItem(
                                      value: '配偶',
                                      child: Text('配偶'),
                                    ),
                                    DropdownMenuItem(
                                      value: '兄弟姊妹',
                                      child: Text('兄弟姊妹'),
                                    ),
                                    DropdownMenuItem(
                                      value: '情侶',
                                      child: Text('情侶'),
                                    ),
                                    DropdownMenuItem(
                                      value: '朋友',
                                      child: Text('朋友'),
                                    ),
                                    DropdownMenuItem(
                                      value: '其他',
                                      child: Text('其他'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _emergencyRelation = value ?? '父母';

                                      if (_emergencyRelation == '其他') {
                                        _emergencyRelationController.clear();
                                      } else {
                                        _emergencyRelationController.text =
                                            _emergencyRelation;
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    Checkbox(
                                      value: _sameAsOwner,
                                      onChanged: (value) {
                                        setState(() {
                                          _sameAsOwner = value ?? false;

                                          if (_sameAsOwner) {
                                            String detail =
                                                _detailAddressController.text
                                                    .trim();

                                            if (_city != null &&
                                                detail.startsWith(_city!)) {
                                              detail = detail.replaceFirst(
                                                _city!,
                                                '',
                                              );
                                            }

                                            if (_district != null &&
                                                detail.startsWith(_district!)) {
                                              detail = detail.replaceFirst(
                                                _district!,
                                                '',
                                              );
                                            }

                                            final fullAddress =
                                                '${_city ?? ''}${_district ?? ''}$detail';

                                            _emergencyAddressController.text =
                                                fullAddress;
                                          } else {
                                            _emergencyAddressController.text =
                                                '';
                                          }
                                        });
                                      },
                                    ),
                                    const Text('地址與飼主相同'),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                TextField(
                                  controller: _emergencyAddressController,
                                  decoration: const InputDecoration(
                                    labelText: '地址',
                                    border: OutlineInputBorder(),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _editingEmergency = false;
                                      });
                                    },
                                    icon: const Icon(Icons.close),
                                    label: const Text('取消編輯'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                /// 🔥 這行一定要加（觸發紅字）
                                if (!_formKey.currentState!.validate()) {
                                  return;
                                }

                                /// （你原本的必填判斷可以刪掉或留著都可以）

                                /// ✅ 必填鎖（全部欄位）
                                /// ✅ 會員中心只強制姓名 + 電話
                                if (_nameController.text.trim().isEmpty ||
                                    _phoneController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('請填寫姓名與電話')),
                                  );
                                  return;
                                }
                                final fullAddress =
                                    '${_city ?? ''}${_district ?? ''}${_detailAddressController.text}';

                                //ait _createMemberLinkRequest(
                                //user: user,
                                //phone: _phoneController.text.trim(),
                                //

                                await FirebaseFirestore.instance
                                    .collection('user_profiles')
                                    .doc(user.uid)
                                    .set({
                                      'name': _nameController.text.trim(),
                                      'phone': _phoneController.text.trim(),
                                      'address': fullAddress,

                                      /// 🚨 緊急聯絡人
                                      'emergencyContact': {
                                        'name': _emergencyNameController.text
                                            .trim(),
                                        'phone': _emergencyPhoneController.text
                                            .trim(),
                                        'relation': _emergencyRelationController
                                            .text
                                            .trim(),
                                        'address': _emergencyAddressController
                                            .text
                                            .trim(),
                                      },

                                      'updatedAt': FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));

                                if (context.mounted) {
                                  setState(() {
                                    _editingProfile = false;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('已儲存，可直接新增寵物並預約'),
                                    ),
                                  );
                                }
                              },
                              child: const Text('儲存資料'),
                            ),
                          ),

                          const SizedBox(height: 20),

                          _buildSectionCard(
                            title: '我的寵物',
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '管理你的寵物資料',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const AddPetPage(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('新增'),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              StreamBuilder<List<Map<String, dynamic>>>(
                                stream: PetService.instance.streamMyPets(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const CircularProgressIndicator();
                                  }

                                  final pets = snapshot.data!;

                                  if (pets.isEmpty) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(20),
                                        child: Text('尚未新增寵物'),
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: pets.map((pet) {
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.all(
                                            12,
                                          ),

                                          leading: CircleAvatar(
                                            radius: 28,
                                            backgroundImage:
                                                pet['photoUrl'] != null &&
                                                    pet['photoUrl']
                                                        .toString()
                                                        .isNotEmpty
                                                ? NetworkImage(pet['photoUrl'])
                                                : null,
                                            child:
                                                (pet['photoUrl'] == null ||
                                                    pet['photoUrl']
                                                        .toString()
                                                        .isEmpty)
                                                ? const Icon(Icons.pets)
                                                : null,
                                          ),

                                          title: Text(
                                            pet['name'] ?? '未命名',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          subtitle: Text(pet['type'] ?? ''),

                                          trailing: const Icon(
                                            Icons.chevron_right,
                                          ),

                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PetDetailPage(pet: pet),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          _buildSectionCard(
                            title: '訂單中心',
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.blue.shade50,
                                  child: const Icon(Icons.receipt_long),
                                ),
                                title: const Text(
                                  '我的訂單',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: const Text('查看所有預約紀錄與付款狀態'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MyBookingsPage(
                                        returnShopId: widget.shopId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.orange.shade50,
                                  child: const Icon(Icons.stars_outlined),
                                ),
                                title: const Text(
                                  '我的點數',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: const Text('查看目前點數與點數紀錄'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  String currentShopId = widget.shopId.trim();
                                  String currentShopName = widget.shopName
                                      .trim();

                                  // 舊入口沒有傳入店家時，暫時保留最新訂單作為相容處理。
                                  // 等 Classic、Modern Drawer 都完成傳值後，再移除此備援。
                                  if (currentShopId.isEmpty) {
                                    final QuerySnapshot<Map<String, dynamic>>
                                    bookingSnapshot = await FirebaseFirestore
                                        .instance
                                        .collection('bookings')
                                        .where('userId', isEqualTo: user.uid)
                                        .orderBy('createdAt', descending: true)
                                        .limit(1)
                                        .get();

                                    if (!context.mounted) return;

                                    if (bookingSnapshot.docs.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('目前沒有可查看的店家點數'),
                                        ),
                                      );
                                      return;
                                    }

                                    final Map<String, dynamic> bookingData =
                                        bookingSnapshot.docs.first.data();

                                    currentShopId =
                                        (bookingData['shopId'] ?? '')
                                            .toString()
                                            .trim();

                                    currentShopName =
                                        (bookingData['shopName'] ?? '')
                                            .toString()
                                            .trim();
                                  }

                                  if (currentShopId.isEmpty) {
                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('找不到目前店家資料'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (!context.mounted) return;

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => MemberPointDetailPage(
                                        shopId: currentShopId,
                                        shopName: currentShopName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 1),

                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.purple.shade50,
                                  child: Icon(
                                    Icons.confirmation_number_outlined,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                                title: const Text(
                                  '我的優惠券',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: const Text('查看目前店家的可用與歷史優惠券'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  final currentShopId = widget.shopId.trim();

                                  if (currentShopId.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('找不到目前店家資料'),
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => MemberCouponPage(
                                        shopId: currentShopId,
                                        shopName: widget.shopName.trim(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 1),

                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.amber.shade50,
                                  child: const Icon(Icons.rate_review),
                                ),
                                title: const Text(
                                  '我的評價',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: const Text('查看住宿評價、店家回覆與修改'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const MyReviewsPage(),
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.blueGrey.shade50,
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    color: Colors.blueGrey.shade700,
                                  ),
                                ),
                                title: const Text(
                                  '我的實體商品',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: const Text('查看待領取商品、領取碼與兌換狀態'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  final String currentShopId = widget.shopId
                                      .trim();

                                  if (currentShopId.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('找不到目前店家資料'),
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => MemberPointRedemptionPage(
                                        shopId: currentShopId,
                                        shopName: widget.shopName.trim(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.green.shade50,
                                  child: const Icon(
                                    Icons.notifications_active_outlined,
                                  ),
                                ),
                                title: const Text(
                                  '通知設定',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: const Text('調整訂單、聊天、評價與入住提醒'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const NotificationSettingPage(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('account_delete_requests')
                                .where('uid', isEqualTo: user.uid)
                                .orderBy('createdAt', descending: true)
                                .limit(1)
                                .snapshots(),
                            builder: (context, snapshot) {
                              final doc = snapshot.data?.docs.isNotEmpty == true
                                  ? snapshot.data!.docs.first
                                  : null;

                              final data = doc?.data() as Map<String, dynamic>?;

                              final status = (data?['status'] ?? '') as String;

                              String statusText = '';
                              if (status == 'pending') {
                                statusText = '目前狀態：待處理';
                              } else if (status == 'processing') {
                                statusText = '目前狀態：處理中';
                              } else if (status == 'rejected') {
                                statusText = '目前狀態：已拒絕，如仍需刪除可再次聯絡平台';
                              } else if (status == 'completed') {
                                statusText = '目前狀態：已完成';
                              }

                              final canSubmit =
                                  status.isEmpty || status == 'rejected';

                              return _buildSectionCard(
                                title: '帳號管理',
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 26,
                                      backgroundColor: Colors.red.shade50,
                                      child: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                    title: const Text(
                                      '申請刪除帳號',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      statusText.isEmpty
                                          ? '送出後由平台協助處理會員資料與相關紀錄'
                                          : statusText,
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    enabled: canSubmit,
                                    onTap: canSubmit
                                        ? () {
                                            _showDeleteAccountDialog(user);
                                          }
                                        : null,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _detailAddressController.dispose();

    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    _emergencyAddressController.dispose();

    super.dispose();
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
