// 檔案名稱：lib/core/services/custom_form_service.dart
// 功能說明：店家自訂表單 Firestore Service
// 路徑：shops/{shopId}/custom_forms/{pet_profile|booking_submit}

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';

class CustomFormService {
  CustomFormService._();

  static final CustomFormService instance = CustomFormService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _formRef({
    required String shopId,
    required CustomFormType formType,
  }) {
    return _firestore
        .collection('shops')
        .doc(shopId.trim())
        .collection('custom_forms')
        .doc(formType.storageId);
  }

  /// 讀取表單。文件不存在時回傳預設空表單，不丟錯。
  Future<CustomFormModel> getForm({
    required String shopId,
    required CustomFormType formType,
  }) async {
    final String normalizedShopId = shopId.trim();
    if (normalizedShopId.isEmpty) {
      return CustomFormModel.empty(shopId: '', formType: formType);
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _formRef(
      shopId: normalizedShopId,
      formType: formType,
    ).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return CustomFormModel.empty(
        shopId: normalizedShopId,
        formType: formType,
      );
    }

    return CustomFormModel.fromMap(
      shopId: normalizedShopId,
      formType: formType,
      id: snapshot.id,
      data: snapshot.data(),
    );
  }

  Future<void> saveForm({required CustomFormModel form}) async {
    final String shopId = form.shopId.trim();
    if (shopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    final DocumentReference<Map<String, dynamic>> ref = _formRef(
      shopId: shopId,
      formType: form.formType,
    );

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await ref.get();
    final CustomFormModel existing = snapshot.exists
        ? CustomFormModel.fromMap(
            shopId: shopId,
            formType: form.formType,
            id: snapshot.id,
            data: snapshot.data(),
          )
        : CustomFormModel.empty(shopId: shopId, formType: form.formType);

    final bool isNew = !snapshot.exists;
    final bool contentChanged = !_sameContent(existing, form);
    final int nextVersion = isNew
        ? 1
        : (contentChanged ? existing.version + 1 : existing.version);

    final Map<String, dynamic> payload = form.toFirestoreMap(
      version: nextVersion,
    );
    payload['updatedAt'] = FieldValue.serverTimestamp();

    if (isNew) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    } else {
      final dynamic createdAt = snapshot.data()?['createdAt'];
      if (createdAt != null) {
        payload['createdAt'] = createdAt;
      } else {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }
    }

    await ref.set(payload);
  }

  bool _sameContent(CustomFormModel a, CustomFormModel b) {
    return jsonEncode(a.contentSnapshot()) == jsonEncode(b.contentSnapshot());
  }
}
