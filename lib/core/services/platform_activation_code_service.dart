// 檔案名稱：lib/core/services/platform_activation_code_service.dart
// 功能說明：建立激活碼、驗證激活碼、查詢激活碼
// 🎟️ 平台激活碼服務

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlatformActivationCodeService {
  PlatformActivationCodeService._();

  static final instance = PlatformActivationCodeService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _activationCodes =>
      _firestore.collection('activation_codes');

  /// 🔥 建立激活碼
  Future<void> createCode({
    required String code,
    required int maxUses,
    required int freeDays,
    required String module,
    String type = 'shop_create',
    String plan = 'basic',
  }) async {
    final user = _auth.currentUser;

    final exists = await getCode(code);

    if (exists != null) {
      throw Exception('此激活碼已存在');
    }

    await _activationCodes.add({
      'code': code.trim(),

      /// 類型
      'type': type,

      /// 開通方案
      'plan': plan,

      /// 鎖定模板
      'module': module,

      /// 使用次數
      'maxUses': maxUses,
      'usedCount': 0,

      /// 啟用狀態
      'enabled': true,

      /// 免費天數
      'freeDays': freeDays,

      /// 使用紀錄
      'usedShopIds': [],
      'usedByUids': [],

      /// 預留欄位
      'memo': '',
      'expireAt': null,
      'allowBusinessTypes': [module],
      'onlyNewUser': false,

      /// 建立資訊
      'createdByUid': user?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 🔍 取得激活碼
  Future<Map<String, dynamic>?> getCode(String code) async {
    final snapshot = await _activationCodes
        .where('code', isEqualTo: code.trim())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;

    return {'id': doc.id, ...doc.data()};
  }

  /// ✅ 驗證激活碼
  Future<String?> validateCode(String code) async {
    final data = await getCode(code);

    /// 找不到
    if (data == null) {
      return '找不到此激活碼';
    }

    /// 已停用
    if (data['enabled'] != true) {
      return '此激活碼已停用';
    }

    final maxUses = data['maxUses'] ?? 0;

    final usedCount = data['usedCount'] ?? 0;

    /// 超過次數
    if (usedCount >= maxUses) {
      return '此激活碼已達使用上限';
    }

    return null;
  }

  /// 🔄 切換激活碼啟用狀態
  Future<void> updateCodeEnabled({
    required String codeId,
    required bool enabled,
  }) async {
    await _activationCodes.doc(codeId).update({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
