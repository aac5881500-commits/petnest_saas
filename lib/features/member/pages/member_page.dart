// lib/features/member/pages/member_page.dart
// 👤 會員中心頁（完整版：含電話輸入）

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/services/member_avatar_service.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/widgets/member_avatar.dart';
import 'package:petnest_saas/features/pet/pages/pet_detail_page.dart';
import 'package:petnest_saas/features/pet/pages/add_pet_page.dart';
import 'package:petnest_saas/features/shop/widgets/media/banner_image_crop_page.dart';
import 'package:petnest_saas/core/constants/taiwan_city_data.dart';
import 'package:petnest_saas/features/booking/pages/my_reviews_page.dart';
import 'package:petnest_saas/features/member/pages/member_point_detail_page.dart';
import 'package:petnest_saas/features/member/pages/member_coupon_page.dart';
import 'package:petnest_saas/core/services/notification_service.dart';
import 'package:petnest_saas/features/notifications/pages/notification_center_page.dart';
import 'package:petnest_saas/features/notifications/pages/notification_setting_page.dart';
import 'package:petnest_saas/features/member/pages/member_point_redemption_page.dart';
import 'package:petnest_saas/core/widgets/point_module_visibility.dart';
import 'package:petnest_saas/core/widgets/member_point_history_visibility.dart';
import 'package:petnest_saas/core/debug/chat_error_probe.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_customer_chat_page.dart';

class MemberPage extends StatefulWidget {
  const MemberPage({
    super.key,
    required this.shopId,
    this.shopName = '',
    this.theme = HomeThemeModel.modernDefault,
  });

  final String shopId;
  final String shopName;
  final HomeThemeModel theme;

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
  bool _hasSyncedMember = false;
  bool _avatarBusy = false;
  String? _avatarBusyMessage;
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

  String _petTypeLabel(Map<String, dynamic> pet) {
    final String raw = (pet['type'] ?? pet['species'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (raw == 'cat' || raw == '貓咪') {
      return '貓咪';
    }
    if (raw == 'dog' || raw == '狗' || raw == '狗狗') {
      return '狗狗';
    }
    if (raw.isEmpty) {
      return '寵物';
    }
    return raw;
  }

  String _fullAddressText() {
    return '${_city ?? ''}${_district ?? ''}${_detailAddressController.text.trim()}';
  }

  String _emergencySummary() {
    final String name = _emergencyNameController.text.trim();
    final String relation = _emergencyRelationController.text.trim();
    final String phone = _emergencyPhoneController.text.trim();

    if (name.isEmpty && relation.isEmpty && phone.isEmpty) {
      return '尚未填寫緊急聯絡人';
    }
    if (name.isNotEmpty && relation.isNotEmpty) {
      return '$name・$relation';
    }
    if (name.isNotEmpty && phone.isNotEmpty) {
      return '$name・$phone';
    }
    if (name.isNotEmpty) {
      return name;
    }
    return '尚未填寫緊急聯絡人';
  }

  Future<void> _persistMemberProfile(User user) async {
    await FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(user.uid)
        .set({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _fullAddressText(),
          'emergencyContact': {
            'name': _emergencyNameController.text.trim(),
            'phone': _emergencyPhoneController.text.trim(),
            'relation': _emergencyRelationController.text.trim(),
            'address': _emergencyAddressController.text.trim(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _openProfileEditor(User user) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '個人資料',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Email：${user.email ?? ''}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('取消'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          final ScaffoldMessengerState messenger =
                              ScaffoldMessenger.of(context);
                          await _persistMemberProfile(user);
                          if (!sheetContext.mounted) {
                            return;
                          }
                          Navigator.pop(sheetContext);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('個人資料已儲存')),
                          );
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        child: const Text('儲存'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAddressEditor(User user) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '常用地址',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _city,
                        decoration: const InputDecoration(
                          labelText: '縣市',
                          border: OutlineInputBorder(),
                        ),
                        items: cityData.keys.map((String city) {
                          return DropdownMenuItem<String>(
                            value: city,
                            child: Text(city),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          setModalState(() {
                            _city = value;
                            _district = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _district,
                        decoration: const InputDecoration(
                          labelText: '區域',
                          border: OutlineInputBorder(),
                        ),
                        items: (_city == null ? <String>[] : cityData[_city]!)
                            .map<DropdownMenuItem<String>>((String d) {
                              return DropdownMenuItem<String>(
                                value: d,
                                child: Text(d),
                              );
                            })
                            .toList(),
                        onChanged: (String? value) {
                          setModalState(() {
                            _district = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _detailAddressController,
                        decoration: const InputDecoration(
                          labelText: '詳細地址',
                          border: OutlineInputBorder(),
                        ),
                        validator: (String? v) =>
                            (v ?? '').trim().isEmpty ? '請輸入地址' : null,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('取消'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }
                              final ScaffoldMessengerState messenger =
                                  ScaffoldMessenger.of(context);
                              await _persistMemberProfile(user);
                              if (!sheetContext.mounted) {
                                return;
                              }
                              Navigator.pop(sheetContext);
                              messenger.showSnackBar(
                                const SnackBar(content: Text('常用地址已儲存')),
                              );
                              if (mounted) {
                                setState(() {});
                              }
                            },
                            child: const Text('儲存'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openEmergencyEditor(User user) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '緊急聯絡人',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emergencyNameController,
                        decoration: const InputDecoration(
                          labelText: '緊急聯絡人姓名',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateName,
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _emergencyRelation,
                        decoration: const InputDecoration(
                          labelText: '關係',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: '父母', child: Text('父母')),
                          DropdownMenuItem(value: '夫妻', child: Text('夫妻')),
                          DropdownMenuItem(value: '配偶', child: Text('配偶')),
                          DropdownMenuItem(value: '兄弟姊妹', child: Text('兄弟姊妹')),
                          DropdownMenuItem(value: '情侶', child: Text('情侶')),
                          DropdownMenuItem(value: '朋友', child: Text('朋友')),
                          DropdownMenuItem(value: '其他', child: Text('其他')),
                        ],
                        onChanged: (String? value) {
                          setModalState(() {
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _sameAsOwner,
                            onChanged: (bool? value) {
                              setModalState(() {
                                _sameAsOwner = value ?? false;
                                if (_sameAsOwner) {
                                  _emergencyAddressController.text =
                                      _fullAddressText();
                                } else {
                                  _emergencyAddressController.text = '';
                                }
                              });
                            },
                          ),
                          const Text('地址與飼主相同'),
                        ],
                      ),
                      TextField(
                        controller: _emergencyAddressController,
                        decoration: const InputDecoration(
                          labelText: '地址',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('取消'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }
                              final ScaffoldMessengerState messenger =
                                  ScaffoldMessenger.of(context);
                              await _persistMemberProfile(user);
                              if (!sheetContext.mounted) {
                                return;
                              }
                              Navigator.pop(sheetContext);
                              messenger.showSnackBar(
                                const SnackBar(content: Text('緊急聯絡人已儲存')),
                              );
                              if (mounted) {
                                setState(() {});
                              }
                            },
                            child: const Text('儲存'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  bool get _canUseCamera {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _setAvatarBusy(bool busy, [String? message]) {
    if (!mounted) {
      return;
    }
    setState(() {
      _avatarBusy = busy;
      _avatarBusyMessage = busy ? message : null;
    });
  }

  Future<void> _openAvatarActions({
    required String customAvatarUrl,
    required String customAvatarPath,
  }) async {
    if (_avatarBusy) {
      return;
    }

    final bool hasCustom = hasCustomMemberAvatar(customAvatarUrl);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '變更大頭貼',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (_canUseCamera)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: Text(hasCustom ? '拍照更換' : '拍照'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndUploadAvatar(
                        source: ImageSource.camera,
                        previousUrl: customAvatarUrl,
                        previousPath: customAvatarPath,
                      );
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.photo_outlined),
                  title: Text(hasCustom ? '更換照片' : '選擇照片'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadAvatar(
                      source: ImageSource.gallery,
                      previousUrl: customAvatarUrl,
                      previousPath: customAvatarPath,
                    );
                  },
                ),
                if (hasCustom)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade700,
                    ),
                    title: Text(
                      '移除照片',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _confirmRemoveAvatar(
                        previousUrl: customAvatarUrl,
                        previousPath: customAvatarPath,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadAvatar({
    required ImageSource source,
    required String previousUrl,
    required String previousPath,
  }) async {
    if (_avatarBusy) {
      return;
    }

    _setAvatarBusy(true);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );

      if (file == null) {
        debugPrint('[Avatar] picker cancelled');
        return;
      }

      if (!mounted) {
        return;
      }
      _setAvatarBusy(true, '正在讀取圖片…');

      final Uint8List originalBytes = await file.readAsBytes();
      debugPrint('[Avatar] picked bytes=${originalBytes.length}');
      if (originalBytes.isEmpty) {
        _showAvatarMessage('圖片處理失敗，請重新選擇圖片。');
        return;
      }
      if (originalBytes.length > MemberAvatarService.maxImageBytes) {
        _showAvatarMessage('單張圖片最大 5 MB，請換一張較小的照片');
        return;
      }

      if (!mounted) {
        return;
      }
      _setAvatarBusy(true, '正在處理圖片…');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!mounted) {
        return;
      }

      final Uint8List? croppedBytes = await BannerImageCropPage.open(
        context: context,
        imageBytes: originalBytes,
        cropAspectRatio: 1,
        outputWidth: MemberAvatarService.outputSize,
        outputHeight: MemberAvatarService.outputSize,
        hintText: '框內區域就是大頭貼顯示範圍。可拖曳、縮放圖片來選擇臉部或主體。',
      );

      if (croppedBytes == null) {
        debugPrint('[Avatar] crop cancelled');
        return;
      }
      debugPrint('[Avatar] cropped bytes=${croppedBytes.length}');
      if (croppedBytes.length > MemberAvatarService.maxImageBytes) {
        _showAvatarMessage('單張圖片最大 5 MB，請換一張較小的照片');
        return;
      }

      if (!mounted) {
        return;
      }
      _setAvatarBusy(true, '正在上傳大頭貼…');

      final MemberAvatarUpload uploaded = await MemberAvatarService.instance
          .uploadAvatarBytes(croppedBytes);

      await MemberAvatarService.instance.replaceProfileAvatar(
        newImageUrl: uploaded.imageUrl,
        newStoragePath: uploaded.imageStoragePath,
        previousImageUrl: previousUrl,
        previousStoragePath: previousPath,
      );

      if (!mounted) {
        return;
      }
      _showAvatarMessage('大頭貼已更新');
    } catch (e, st) {
      MemberAvatarService.logFailure('pickAndUpload', e, st);
      _showAvatarMessage('大頭貼更新失敗，請稍後再試');
    } finally {
      _setAvatarBusy(false);
    }
  }

  Future<void> _confirmRemoveAvatar({
    required String previousUrl,
    required String previousPath,
  }) async {
    if (_avatarBusy) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('移除大頭貼'),
          content: const Text('確定要移除目前的大頭貼嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('移除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    _setAvatarBusy(true, '正在移除大頭貼…');
    try {
      await MemberAvatarService.instance.removeProfileAvatar(
        previousImageUrl: previousUrl,
        previousStoragePath: previousPath,
      );
      if (!mounted) {
        return;
      }
      _showAvatarMessage('已移除大頭貼');
    } catch (e, st) {
      MemberAvatarService.logFailure('removeAvatar', e, st);
      _showAvatarMessage('移除失敗，請稍後再試');
    } finally {
      _setAvatarBusy(false);
    }
  }

  void _showAvatarMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openAddPetPage() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => AddPetPage(theme: widget.theme)),
    );
  }

  Widget _buildMyPointsTile(User user) {
    return _memberNavTile(
      icon: Icons.stars_outlined,
      iconColor: const Color(0xFFD08A3A),
      title: '我的點數',
      subtitle: '查看目前點數與點數紀錄',
      onTap: () async {
        String currentShopId = widget.shopId.trim();
        String currentShopName = widget.shopName.trim();

        // 舊入口沒有傳入店家時，保留最新訂單作為相容處理。
        if (currentShopId.isEmpty) {
          final QuerySnapshot<Map<String, dynamic>> bookingSnapshot =
              await FirebaseFirestore.instance
                  .collection('bookings')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .get();

          if (!mounted) return;

          if (bookingSnapshot.docs.isEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('目前沒有可查看的店家點數')));
            return;
          }

          final Map<String, dynamic> bookingData = bookingSnapshot.docs.first
              .data();

          currentShopId = (bookingData['shopId'] ?? '').toString().trim();
          currentShopName = (bookingData['shopName'] ?? '').toString().trim();
        }

        if (currentShopId.isEmpty) {
          if (!mounted) return;

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('找不到目前店家資料')));
          return;
        }

        if (!mounted) return;

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
    );
  }

  Widget _buildMyPointRedemptionTile() {
    return _memberNavTile(
      icon: Icons.inventory_2_outlined,
      iconColor: const Color(0xFF5B6E7A),
      title: '我的實體商品',
      subtitle: '查看待領取商品、領取碼與兌換狀態',
      onTap: () {
        final String currentShopId = widget.shopId.trim();

        if (currentShopId.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('找不到目前店家資料')));
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !_hasSyncedMember) {
      _hasSyncedMember = true;
      _syncMemberByEmail(user);
    }

    return Scaffold(
      backgroundColor: widget.theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: widget.theme.cardColor,
        foregroundColor: widget.theme.textColor,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '會員中心',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
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
                              fontSize: 11,
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
      body: Stack(
        children: [
          Padding(
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
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final data =
                            snapshot.data!.data() as Map<String, dynamic>?;

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
                            _emergencyNameController.text =
                                emergency['name'] ?? '';
                          }
                          if (_emergencyPhoneController.text.isEmpty) {
                            _emergencyPhoneController.text =
                                emergency['phone'] ?? '';
                          }
                          if (_emergencyRelationController.text.isEmpty) {
                            _emergencyRelationController.text =
                                emergency['relation'] ?? '父母';
                            _emergencyRelation =
                                _emergencyRelationController.text;
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
                          padding: const EdgeInsets.only(bottom: 12),
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

                              _buildSummaryCard(user, data),
                              const SizedBox(height: 18),
                              _buildBlockTitle('我的資料'),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _miniFeatureCard(
                                      icon: Icons.person_outline_rounded,
                                      iconColor: const Color(0xFF6B8FBF),
                                      title: '個人資料',
                                      subtitle: '姓名與電話',
                                      onTap: () => _openProfileEditor(user),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _miniFeatureCard(
                                      icon: Icons.location_on_outlined,
                                      iconColor: const Color(0xFF5AA37A),
                                      title: '常用地址',
                                      subtitle: _fullAddressText().isEmpty
                                          ? '尚未填寫'
                                          : '已設定',
                                      onTap: () => _openAddressEditor(user),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _miniFeatureCard(
                                      icon: Icons.emergency_outlined,
                                      iconColor: const Color(0xFFC45C4A),
                                      title: '緊急聯絡人',
                                      subtitle:
                                          _emergencySummary() == '尚未填寫緊急聯絡人'
                                          ? '尚未填寫'
                                          : '已設定',
                                      onTap: () => _openEmergencyEditor(user),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _buildBlockTitle('我的寵物', subtitle: '管理你的毛孩資料'),
                              StreamBuilder<List<Map<String, dynamic>>>(
                                stream: PetService.instance.streamMyPets(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final List<Map<String, dynamic>> pets =
                                      snapshot.data!;
                                  final List<Widget> cards = <Widget>[
                                    ...pets.map(_petCard),
                                    _addPetDashedCard(),
                                  ];
                                  return GridView.count(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 0.88,
                                    children: cards,
                                  );
                                },
                              ),

                              const SizedBox(height: 18),
                              _buildBlockTitle('訂單中心'),
                              Column(
                                children: [
                                  StreamBuilder<Map<String, dynamic>?>(
                                    stream: ShopService.instance.streamShop(
                                      widget.shopId,
                                    ),
                                    builder:
                                        (
                                          BuildContext context,
                                          AsyncSnapshot<Map<String, dynamic>?>
                                          shopSnap,
                                        ) {
                                          if (!ShopChatService.isEnabled(
                                            shopSnap.data,
                                          )) {
                                            return const SizedBox.shrink();
                                          }
                                          return Column(
                                            children: <Widget>[
                                              StreamBuilder<int>(
                                                stream:
                                                    ChatErrorProbe
                                                        .bindMemberUnread
                                                    ? ShopChatService.instance
                                                          .watchCustomerUnread(
                                                            shopId:
                                                                widget.shopId,
                                                            customerUid:
                                                                user.uid,
                                                            source:
                                                                'MemberChatBadge',
                                                          )
                                                    : Stream<int>.value(0),
                                                builder:
                                                    (
                                                      BuildContext context,
                                                      AsyncSnapshot<int>
                                                      unreadSnap,
                                                    ) {
                                                      final int unread =
                                                          unreadSnap.data ?? 0;
                                                      final String badge =
                                                          ShopChatService.badgeLabel(
                                                            unread,
                                                          );
                                                      return _memberNavTile(
                                                        icon: Icons
                                                            .chat_bubble_outline,
                                                        iconColor: const Color(
                                                          0xFFFF8A00,
                                                        ),
                                                        title: '店家訊息',
                                                        subtitle: badge.isEmpty
                                                            ? '直接與目前店家聊天'
                                                            : '$badge 則未讀訊息',
                                                        onTap: () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute<
                                                              void
                                                            >(
                                                              builder: (_) =>
                                                                  ShopCustomerChatPage(
                                                                    shopId: widget
                                                                        .shopId,
                                                                    shopName: widget
                                                                        .shopName,
                                                                  ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    },
                                              ),
                                            ],
                                          );
                                        },
                                  ),
                                  MemberPointHistoryVisibility(
                                    shopId: widget.shopId,
                                    userId: user.uid,
                                    enabledChild: _buildMyPointsTile(user),
                                    historyChild: _buildMyPointsTile(user),
                                    emptyChild: const SizedBox.shrink(),
                                  ),
                                  _memberNavTile(
                                    icon: Icons.confirmation_number_outlined,
                                    iconColor: const Color(0xFF8A6BBF),
                                    title: '我的優惠券',
                                    subtitle: '查看目前店家的可用與歷史優惠券',
                                    onTap: () {
                                      final currentShopId = widget.shopId
                                          .trim();

                                      if (currentShopId.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
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
                                  _memberNavTile(
                                    icon: Icons.rate_review_outlined,
                                    iconColor: const Color(0xFFC49A3A),
                                    title: '我的評價',
                                    subtitle: '查看住宿評價、店家回覆與修改',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => const MyReviewsPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>
                                  >(
                                    stream: FirebaseFirestore.instance
                                        .collection('shops')
                                        .doc(widget.shopId.trim())
                                        .collection('point_redemptions')
                                        .where('userId', isEqualTo: user.uid)
                                        .limit(1)
                                        .snapshots(),
                                    builder:
                                        (
                                          BuildContext context,
                                          AsyncSnapshot<
                                            QuerySnapshot<Map<String, dynamic>>
                                          >
                                          snapshot,
                                        ) {
                                          final bool hasRedemptionHistory =
                                              snapshot.hasData &&
                                              snapshot.data!.docs.isNotEmpty;

                                          return MemberPointHistoryVisibility(
                                            shopId: widget.shopId,
                                            userId: user.uid,
                                            enabledChild:
                                                _buildMyPointRedemptionTile(),
                                            historyChild: hasRedemptionHistory
                                                ? _buildMyPointRedemptionTile()
                                                : const SizedBox.shrink(),
                                            emptyChild: const SizedBox.shrink(),
                                          );
                                        },
                                  ),
                                  _memberNavTile(
                                    icon: Icons.notifications_active_outlined,
                                    iconColor: const Color(0xFF4A9B6E),
                                    title: '通知設定',
                                    subtitle: '調整訂單、聊天、評價與入住提醒',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const NotificationSettingPage(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('account_delete_requests')
                                    .where('uid', isEqualTo: user.uid)
                                    .orderBy('createdAt', descending: true)
                                    .limit(1)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final doc =
                                      snapshot.data?.docs.isNotEmpty == true
                                      ? snapshot.data!.docs.first
                                      : null;

                                  final data =
                                      doc?.data() as Map<String, dynamic>?;

                                  final status =
                                      (data?['status'] ?? '') as String;

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

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildBlockTitle('帳號管理'),
                                      _memberNavTile(
                                        icon: Icons.delete_outline,
                                        iconColor: const Color(0xFFC45C4A),
                                        title: '申請刪除帳號',
                                        subtitle: statusText.isEmpty
                                            ? '送出後由平台協助處理會員資料與相關紀錄'
                                            : statusText,
                                        enabled: canSubmit,
                                        muted: true,
                                        warning: true,
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
          if (_avatarBusy && _avatarBusyMessage != null)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 14),
                        Text(
                          _avatarBusyMessage ?? '處理中…',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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

  Widget _buildBlockTitle(String title, {String? subtitle, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: widget.theme.textColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.theme.textColor.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildSummaryCard(User user, Map<String, dynamic>? data) {
    final String name = _nameController.text.trim();
    final String phone = _phoneController.text.trim();
    final String email = (user.email ?? '').trim();
    final String customAvatarUrl = (data?['avatarUrl'] ?? '').toString();
    final String customAvatarPath = (data?['avatarStoragePath'] ?? '')
        .toString();
    final String? avatarUrl = resolveMemberAvatarUrl(
      customAvatarUrl: customAvatarUrl,
      authPhotoUrl: user.photoURL,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.theme.cardBorderColor),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              widget.theme.primaryColor.withValues(alpha: 0.14),
              widget.theme.cardColor,
            ),
            widget.theme.cardColor,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            MemberAvatar(
              imageUrl: avatarUrl,
              size: 60,
              showCameraBadge: true,
              loading: _avatarBusy,
              onTap: _avatarBusy
                  ? null
                  : () => _openAvatarActions(
                      customAvatarUrl: customAvatarUrl,
                      customAvatarPath: customAvatarPath,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? '尚未填寫姓名' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.theme.textColor,
                    ),
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.theme.textColor.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.theme.textColor.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: '編輯',
              onPressed: _avatarBusy ? null : () => _openProfileEditor(user),
              icon: Icon(Icons.edit_outlined, color: widget.theme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberNavTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool enabled = true,
    bool warning = false,
    bool muted = false,
  }) {
    final HomeThemeModel theme = widget.theme;
    final Color border = warning ? Colors.red.shade200 : theme.cardBorderColor;
    final Color fill = warning
        ? const Color(0xFFFFF7F6)
        : muted
        ? Color.alphaBlend(
            theme.primaryColor.withValues(alpha: 0.04),
            theme.backgroundColor,
          )
        : theme.cardColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: iconColor.withValues(
                          alpha: warning ? 0.16 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textColor.withValues(alpha: 0.55),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.textColor.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final HomeThemeModel theme = widget.theme;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.cardBorderColor),
          ),
          child: Column(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addPetDashedCard() {
    final HomeThemeModel theme = widget.theme;
    return CustomPaint(
      painter: _DashedRRectPainter(color: theme.cardBorderColor),
      child: Material(
        color: theme.primaryColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _avatarBusy ? null : _openAddPetPage,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.add, color: theme.primaryColor, size: 28),
                const SizedBox(height: 6),
                Text(
                  '新增寵物',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _petCard(Map<String, dynamic> pet) {
    final HomeThemeModel theme = widget.theme;
    final String photoUrl = (pet['photoUrl'] ?? pet['imageUrl'] ?? '')
        .toString()
        .trim();
    final String name = (pet['name'] ?? '未命名').toString();
    final String gender = (pet['gender'] ?? '').toString();
    final String age = (pet['age'] ?? '').toString();
    final String meta = <String>[
      if (gender.isNotEmpty) gender,
      if (age.isNotEmpty) age,
    ].join('・');

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PetDetailPage(pet: pet, theme: theme),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.cardBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: photoUrl.isEmpty
                    ? ColoredBox(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.pets,
                          size: 32,
                          color: theme.primaryColor,
                        ),
                      )
                    : Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return ColoredBox(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.pets,
                              size: 32,
                              color: theme.primaryColor,
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.isEmpty ? _petTypeLabel(pet) : meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textColor.withValues(alpha: 0.55),
                        fontSize: 12,
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
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    const double dash = 5;
    const double gap = 4;
    final Path path = Path()..addRRect(rrect);
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = distance + dash;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
