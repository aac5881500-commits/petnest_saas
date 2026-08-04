// lib/core/services/coupon_template_service.dart
// 🎟️ 優惠券模板 Service
// 功能：管理店家建立的優惠券模板，供手動發券、點數兌換與自動贈券共用。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/coupon_template_model.dart';
import '../models/member_coupon_model.dart';

class CouponTemplateService {
  CouponTemplateService._();

  static final CouponTemplateService instance = CouponTemplateService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _templateCollection(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('coupon_templates');
  }

  /// 即時監聽店家的全部優惠券模板
  Stream<List<CouponTemplateModel>> streamTemplates({
    required String shopId,
    bool enabledOnly = false,
  }) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<List<CouponTemplateModel>>.value(
        const <CouponTemplateModel>[],
      );
    }

    return _templateCollection(normalizedShopId).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<CouponTemplateModel> templates = snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> document) {
            return CouponTemplateModel.fromMap(
              id: document.id,
              data: document.data(),
            );
          })
          .where((CouponTemplateModel template) {
            if (!enabledOnly) {
              return true;
            }

            return template.enabled;
          })
          .toList();

      templates.sort((CouponTemplateModel first, CouponTemplateModel second) {
        final int sortResult = first.sortOrder.compareTo(second.sortOrder);

        if (sortResult != 0) {
          return sortResult;
        }

        return second.createdAt.compareTo(first.createdAt);
      });

      return templates;
    });
  }

  /// 一次取得店家的全部優惠券模板
  Future<List<CouponTemplateModel>> getTemplates({
    required String shopId,
    bool enabledOnly = false,
  }) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return const <CouponTemplateModel>[];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _templateCollection(normalizedShopId).get();

    final List<CouponTemplateModel> templates = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> document) {
          return CouponTemplateModel.fromMap(
            id: document.id,
            data: document.data(),
          );
        })
        .where((CouponTemplateModel template) {
          if (!enabledOnly) {
            return true;
          }

          return template.enabled;
        })
        .toList();

    templates.sort((CouponTemplateModel first, CouponTemplateModel second) {
      final int sortResult = first.sortOrder.compareTo(second.sortOrder);

      if (sortResult != 0) {
        return sortResult;
      }

      return second.createdAt.compareTo(first.createdAt);
    });

    return templates;
  }

  /// 取得單一優惠券模板
  Future<CouponTemplateModel?> getTemplate({
    required String shopId,
    required String templateId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedTemplateId = templateId.trim();

    if (normalizedShopId.isEmpty || normalizedTemplateId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _templateCollection(
          normalizedShopId,
        ).doc(normalizedTemplateId).get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return CouponTemplateModel.fromMap(id: snapshot.id, data: data);
  }

  /// 建立優惠券模板
  Future<String> createTemplate({
    required String shopId,
    required String name,
    required MemberCouponType type,
    required MemberCouponApplyTarget applyTarget,
    String description = '',
    num discountValue = 0,
    int minimumAmount = 0,
    int maximumDiscountAmount = 0,
    int freeStayNights = 0,
    String serviceId = '',
    String serviceName = '',
    CouponServiceCategory serviceCategory = CouponServiceCategory.value,
    List<String> roomTypeIds = const <String>[],
    int validDays = 30,
    int usageLimit = 1,
    bool enabled = true,
    int sortOrder = 0,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedName = name.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (normalizedName.isEmpty) {
      throw ArgumentError('請輸入優惠券名稱');
    }

    _validateTemplateContent(
      type: type,
      discountValue: discountValue,
      minimumAmount: minimumAmount,
      maximumDiscountAmount: maximumDiscountAmount,
      freeStayNights: freeStayNights,
      serviceId: serviceId,
      validDays: validDays,
      usageLimit: usageLimit,
    );

    final DateTime now = DateTime.now();
    final String currentUserId = _auth.currentUser?.uid ?? '';

    final DocumentReference<Map<String, dynamic>> reference =
        _templateCollection(normalizedShopId).doc();

    final CouponTemplateModel template = CouponTemplateModel(
      id: reference.id,
      shopId: normalizedShopId,
      name: normalizedName,
      description: description.trim(),
      type: type,
      applyTarget: _effectiveApplyTarget(type: type, applyTarget: applyTarget),
      discountValue: _effectiveDiscountValue(
        type: type,
        discountValue: discountValue,
      ),
      minimumAmount: minimumAmount,
      maximumDiscountAmount: type == MemberCouponType.percent
          ? maximumDiscountAmount
          : 0,
      freeStayNights: type == MemberCouponType.freeStay ? freeStayNights : 0,
      serviceId: type == MemberCouponType.freeService ? serviceId.trim() : '',
      serviceName: type == MemberCouponType.freeService
          ? serviceName.trim()
          : '',
      serviceCategory: serviceCategory,
      roomTypeIds: _normalizeRoomTypeIds(roomTypeIds),
      validDays: validDays,
      usageLimit: usageLimit,
      enabled: enabled,
      sortOrder: sortOrder,
      createdBy: currentUserId,
      updatedBy: currentUserId,
      createdAt: now,
      updatedAt: now,
    );

    await reference.set(template.toMap());

    return reference.id;
  }

  /// 修改優惠券模板
  Future<void> updateTemplate({
    required String shopId,
    required String templateId,
    required String name,
    required MemberCouponType type,
    required MemberCouponApplyTarget applyTarget,
    String description = '',
    num discountValue = 0,
    int minimumAmount = 0,
    int maximumDiscountAmount = 0,
    int freeStayNights = 0,
    String serviceId = '',
    String serviceName = '',
    CouponServiceCategory serviceCategory = CouponServiceCategory.value,
    List<String> roomTypeIds = const <String>[],
    int validDays = 30,
    int usageLimit = 1,
    bool enabled = true,
    int sortOrder = 0,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedTemplateId = templateId.trim();
    final String normalizedName = name.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (normalizedTemplateId.isEmpty) {
      throw ArgumentError('缺少優惠券模板 ID');
    }

    if (normalizedName.isEmpty) {
      throw ArgumentError('請輸入優惠券名稱');
    }

    _validateTemplateContent(
      type: type,
      discountValue: discountValue,
      minimumAmount: minimumAmount,
      maximumDiscountAmount: maximumDiscountAmount,
      freeStayNights: freeStayNights,
      serviceId: serviceId,
      validDays: validDays,
      usageLimit: usageLimit,
    );

    final DocumentReference<Map<String, dynamic>> reference =
        _templateCollection(normalizedShopId).doc(normalizedTemplateId);

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await reference
        .get();

    if (!snapshot.exists) {
      throw StateError('找不到優惠券模板');
    }

    await reference.update(<String, dynamic>{
      'name': normalizedName,
      'description': description.trim(),
      'type': type.name,
      'applyTarget': _effectiveApplyTarget(
        type: type,
        applyTarget: applyTarget,
      ).name,
      'discountValue': _effectiveDiscountValue(
        type: type,
        discountValue: discountValue,
      ),
      'minimumAmount': minimumAmount,
      'maximumDiscountAmount': type == MemberCouponType.percent
          ? maximumDiscountAmount
          : 0,
      'freeStayNights': type == MemberCouponType.freeStay ? freeStayNights : 0,
      'serviceId': type == MemberCouponType.freeService ? serviceId.trim() : '',
      'serviceName': type == MemberCouponType.freeService
          ? serviceName.trim()
          : '',
      'serviceCategory': serviceCategory.name,
      'roomTypeIds': _normalizeRoomTypeIds(roomTypeIds),
      'validDays': validDays,
      'usageLimit': usageLimit,
      'enabled': enabled,
      'sortOrder': sortOrder,
      'updatedBy': _auth.currentUser?.uid ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 開啟或停用優惠券模板
  Future<void> updateEnabled({
    required String shopId,
    required String templateId,
    required bool enabled,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedTemplateId = templateId.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (normalizedTemplateId.isEmpty) {
      throw ArgumentError('缺少優惠券模板 ID');
    }

    await _templateCollection(
      normalizedShopId,
    ).doc(normalizedTemplateId).update(<String, dynamic>{
      'enabled': enabled,
      'updatedBy': _auth.currentUser?.uid ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 刪除優惠券模板
  ///
  /// 只會刪除模板，不會刪除會員已經領到的優惠券。
  Future<void> deleteTemplate({
    required String shopId,
    required String templateId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedTemplateId = templateId.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (normalizedTemplateId.isEmpty) {
      throw ArgumentError('缺少優惠券模板 ID');
    }

    await _templateCollection(
      normalizedShopId,
    ).doc(normalizedTemplateId).delete();
  }

  void _validateTemplateContent({
    required MemberCouponType type,
    required num discountValue,
    required int minimumAmount,
    required int maximumDiscountAmount,
    required int freeStayNights,
    required String serviceId,
    required int validDays,
    required int usageLimit,
  }) {
    if (minimumAmount < 0) {
      throw ArgumentError('最低消費金額不可小於 0');
    }

    if (maximumDiscountAmount < 0) {
      throw ArgumentError('最高折抵金額不可小於 0');
    }

    if (validDays < 0) {
      throw ArgumentError('有效天數不可小於 0');
    }

    if (usageLimit <= 0) {
      throw ArgumentError('可使用次數必須大於 0');
    }

    switch (type) {
      case MemberCouponType.fixedAmount:
        if (discountValue <= 0) {
          throw ArgumentError('固定金額券的折抵金額必須大於 0');
        }

      case MemberCouponType.percent:
        if (discountValue <= 0 || discountValue > 100) {
          throw ArgumentError('百分比券必須設定 1 到 100 的折扣百分比');
        }

      case MemberCouponType.freeStay:
        if (freeStayNights <= 0) {
          throw ArgumentError('免費住宿券的住宿晚數必須大於 0');
        }

      case MemberCouponType.freeService:
        if (serviceId.trim().isEmpty) {
          throw ArgumentError('免費服務券必須指定加購服務');
        }
    }
  }

  MemberCouponApplyTarget _effectiveApplyTarget({
    required MemberCouponType type,
    required MemberCouponApplyTarget applyTarget,
  }) {
    switch (type) {
      case MemberCouponType.freeStay:
        return MemberCouponApplyTarget.room;

      case MemberCouponType.freeService:
        return MemberCouponApplyTarget.service;

      case MemberCouponType.fixedAmount:
      case MemberCouponType.percent:
        return applyTarget;
    }
  }

  num _effectiveDiscountValue({
    required MemberCouponType type,
    required num discountValue,
  }) {
    if (type == MemberCouponType.freeStay ||
        type == MemberCouponType.freeService) {
      return 0;
    }

    return discountValue;
  }

  List<String> _normalizeRoomTypeIds(List<String> roomTypeIds) {
    return roomTypeIds
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList();
  }
}
