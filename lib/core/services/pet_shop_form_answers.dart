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

  /// 優先使用子集合文件；沒有時才讀舊欄位 customFormAnswersByShop[shopId]。
  static Map<String, dynamic>? resolve({
    required String shopId,
    Map<String, dynamic>? subcollectionData,
    Map<String, dynamic>? petData,
  }) {
    final String id = shopId.trim();
    if (id.isEmpty) {
      return null;
    }
    if (subcollectionData != null && subcollectionData.isNotEmpty) {
      return Map<String, dynamic>.from(subcollectionData);
    }
    final dynamic legacy = petData?['customFormAnswersByShop'];
    if (legacy is! Map) {
      return null;
    }
    final dynamic shopAnswers = Map<dynamic, dynamic>.from(legacy)[id];
    if (shopAnswers is Map) {
      return Map<String, dynamic>.from(shopAnswers);
    }
    return null;
  }
}
