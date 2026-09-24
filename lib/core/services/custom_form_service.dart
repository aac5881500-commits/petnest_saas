// 檔案名稱：lib/core/services/custom_form_service.dart
// 功能說明：店家自訂表單 Firestore Service
// 路徑：shops/{shopId}/custom_forms/{pet_profile|booking_submit|admin_create}

import 'dart:convert';
import 'package:petnest_saas/core/models/custom_form_default_templates.dart';
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
  /// 新增寵物表單已停用：App 不再讀取該文件。
  Stream<CustomFormModel> streamForm({
    required String shopId,
    required CustomFormType formType,
  }) {
    final String normalizedShopId = shopId.trim();
    if (formType == CustomFormType.petProfile) {
      return Stream<CustomFormModel>.value(
        CustomFormModel.empty(shopId: normalizedShopId, formType: formType),
      );
    }
    if (normalizedShopId.isEmpty) {
      return Stream<CustomFormModel>.value(
        CustomFormModel.empty(shopId: '', formType: formType),
      );
    }
    return _formRef(
      shopId: normalizedShopId,
      formType: formType,
    ).snapshots().map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
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
    });
  }

  Future<CustomFormModel> getForm({
    required String shopId,
    required CustomFormType formType,
  }) async {
    final String normalizedShopId = shopId.trim();
    if (normalizedShopId.isEmpty) {
      return CustomFormModel.empty(shopId: '', formType: formType);
    }
    if (formType == CustomFormType.petProfile) {
      return CustomFormModel.empty(
        shopId: normalizedShopId,
        formType: formType,
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _formRef(
      shopId: normalizedShopId,
      formType: formType,
    ).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return CustomFormDefaultTemplates.create(
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
    if (form.formType == CustomFormType.petProfile) {
      return;
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

  /// 前台會員讀取。rules 不允許讀未啟用表單，permission-denied 視為未開啟。
  Future<CustomFormFrontLoadResult> loadFormForCustomer({
    required String shopId,
    required CustomFormType formType,
  }) async {
    if (formType == CustomFormType.petProfile) {
      return CustomFormFrontLoadResult.unavailable();
    }
    try {
      final CustomFormModel form = await getForm(
        shopId: shopId,
        formType: formType,
      );
      return CustomFormFrontLoadResult.success(form);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' || error.code == 'not-found') {
        return CustomFormFrontLoadResult.unavailable();
      }
      return CustomFormFrontLoadResult.failed(error.message ?? error.code);
    } catch (error) {
      return CustomFormFrontLoadResult.failed(error.toString());
    }
  }

  bool _sameContent(CustomFormModel a, CustomFormModel b) {
    return jsonEncode(a.contentSnapshot()) == jsonEncode(b.contentSnapshot());
  }
}

class CustomFormFrontLoadResult {
  const CustomFormFrontLoadResult._({
    required this.form,
    required this.failed,
    this.errorMessage = '',
  });

  factory CustomFormFrontLoadResult.success(CustomFormModel form) {
    return CustomFormFrontLoadResult._(form: form, failed: false);
  }

  factory CustomFormFrontLoadResult.unavailable() {
    return const CustomFormFrontLoadResult._(form: null, failed: false);
  }

  factory CustomFormFrontLoadResult.failed(String message) {
    return CustomFormFrontLoadResult._(
      form: null,
      failed: true,
      errorMessage: message,
    );
  }

  final CustomFormModel? form;
  final bool failed;
  final String errorMessage;
}
