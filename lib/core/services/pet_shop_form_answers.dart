// 檔案名稱：lib/core/services/pet_shop_form_answers.dart
// 功能說明：各店家新增寵物表單答案的子集合路徑、寫入欄位與舊 nested map 相容讀取。

class PetShopFormAnswers {
  PetShopFormAnswers._();

  static const String collectionName = 'shop_form_answers';

  static String path({
    required String userId,
    required String petId,
    required String shopId,
  }) {
    final String uid = userId.trim();
    final String id = petId.trim();
    final String shop = shopId.trim();
    return 'user_profiles/$uid/pets/$id/$collectionName/$shop';
  }

  static bool shouldWrite(Map<String, dynamic>? snapshot) {
    if (snapshot == null || snapshot.isEmpty) {
      return false;
    }
    final dynamic answers = snapshot['answers'];
    if (answers is List) {
      return answers.isNotEmpty;
    }
    return true;
  }

  static Map<String, dynamic> documentData({
    required String shopId,
    required Map<String, dynamic> snapshot,
  }) {
    final Map<String, dynamic> data = <String, dynamic>{
      'shopId': shopId.trim(),
    };
    for (final String key in <String>[
      'formId',
      'formType',
      'formVersion',
      'formTitle',
      'submittedAt',
      'answers',
    ]) {
      if (snapshot.containsKey(key)) {
        data[key] = snapshot[key];
      }
    }
    return data;
  }

  static String petIdOf(Map<String, dynamic>? pet) {
    if (pet == null) {
      return '';
    }
    return (pet['petId'] ?? pet['id'] ?? '').toString().trim();
  }

  static String bookingUserId(Map<String, dynamic> booking) {
    return (booking['userId'] ??
            booking['customerUid'] ??
            booking['memberId'] ??
            '')
        .toString()
        .trim();
  }

  static Map<String, dynamic>? _asAnswerMap(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    if (map.isEmpty) {
      return null;
    }
    return map;
  }

  /// 優先子集合文件，再讀 shopFormAnswers、舊 nested map、單店 customFormAnswers。
  static Map<String, dynamic>? resolve({
    required String shopId,
    Map<String, dynamic>? subcollectionData,
    Map<String, dynamic>? petData,
  }) {
    final String id = shopId.trim();
    if (id.isEmpty) {
      return null;
    }
    final Map<String, dynamic>? sub = _asAnswerMap(subcollectionData);
    if (sub != null && (sub['answers'] != null || sub['formId'] != null)) {
      return sub;
    }
    if (petData == null || petData.isEmpty) {
      return sub;
    }
    final Map<String, dynamic>? shopForm = _asAnswerMap(
      petData['shopFormAnswers'],
    );
    if (shopForm != null) {
      if (shopForm['answers'] != null || shopForm['formId'] != null) {
        return shopForm;
      }
      final Map<String, dynamic>? keyed = _asAnswerMap(shopForm[id]);
      if (keyed != null) {
        return keyed;
      }
    }
    final Map<String, dynamic>? legacy = _asAnswerMap(
      petData['customFormAnswersByShop'],
    );
    if (legacy != null) {
      final Map<String, dynamic>? shopAnswers = _asAnswerMap(legacy[id]);
      if (shopAnswers != null) {
        return shopAnswers;
      }
    }
    final Map<String, dynamic>? single = _asAnswerMap(
      petData['customFormAnswers'],
    );
    if (single != null) {
      return single;
    }
    return sub;
  }
}
