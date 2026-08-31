// lib/core/services/payment_service.dart
// 💳 PetNest 共用付款 Service
// 功能：讀取店家金流公開設定、平台全域金流設定與付款交易紀錄，
// 並提供 Classic、Modern 與未來模板共用的付款方式解析入口。
// 注意：Flutter 不得透過此 Service 直接更新付款成功、退款或敏感金流資料。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment_model.dart';
import '../models/payment_setting_model.dart';
import '../models/platform_payment_setting_model.dart';
import 'payment_resolver.dart';
import 'platform_payment_setting_service.dart';

class PaymentService {
  PaymentService._();

  static final PaymentService instance = PaymentService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final PlatformPaymentSettingService _platformPaymentSettingService =
      PlatformPaymentSettingService.instance;

  /// 店家綠界公開設定文件
  ///
  /// Firestore 路徑：
  /// shops/{shopId}/payment_settings/ecpay
  DocumentReference<Map<String, dynamic>> _paymentSettingReference(
    String shopId,
  ) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('payment_settings')
        .doc('ecpay');
  }

  /// 全平台付款交易集合
  ///
  /// Firestore 路徑：
  /// payments/{paymentId}
  CollectionReference<Map<String, dynamic>> get _paymentsReference {
    return _firestore.collection('payments');
  }

  /// 即時監聽店家的綠界公開設定
  ///
  /// 尚未建立設定時，只回傳預設模型，
  /// 不會由 Flutter 自動寫入 Firestore。
  Stream<PaymentSettingModel> streamPaymentSetting(String shopId) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<PaymentSettingModel>.value(
        PaymentSettingModel.initial(shopId: ''),
      );
    }

    return _paymentSettingReference(normalizedShopId).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return PaymentSettingModel.initial(shopId: normalizedShopId);
      }

      return PaymentSettingModel.fromMap(shopId: normalizedShopId, data: data);
    });
  }

  /// 一次取得店家的綠界公開設定
  ///
  /// 尚未建立時回傳預設模型。
  Future<PaymentSettingModel> getPaymentSetting(String shopId) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return PaymentSettingModel.initial(shopId: '');
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _paymentSettingReference(normalizedShopId).get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return PaymentSettingModel.initial(shopId: normalizedShopId);
    }

    return PaymentSettingModel.fromMap(shopId: normalizedShopId, data: data);
  }

  /// 一次取得平台全域金流設定
  Future<PlatformPaymentSettingModel> getPlatformPaymentSetting() {
    return _platformPaymentSettingService.getSetting();
  }

  /// 即時監聽平台全域金流設定
  Stream<PlatformPaymentSettingModel> streamPlatformPaymentSetting() {
    return _platformPaymentSettingService.streamSetting();
  }

  /// 依店家設定與平台設定取得本次可使用的付款方式
  Future<List<String>> resolveAvailableMethods({
    required String shopId,
    required String amountType,
  }) async {
    final String normalizedShopId = shopId.trim();

    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      getPaymentSetting(normalizedShopId),
      getPlatformPaymentSetting(),
    ]);

    final PaymentSettingModel paymentSetting =
        results[0] as PaymentSettingModel;

    final PlatformPaymentSettingModel platformSetting =
        results[1] as PlatformPaymentSettingModel;

    return PaymentResolver.resolveAvailableMethods(
      setting: paymentSetting,
      amountType: amountType,
      platformSetting: platformSetting,
    );
  }

  /// 即時監聽本次可使用的付款方式
  ///
  /// 店家設定或平台全域設定任一方變更時，
  /// 都會重新計算付款方式。
  ///
  /// 使用 [Stream.multi]：每次 listen 各自建立內層訂閱。
  /// 不要回傳單次訂閱的 [StreamController.stream]，
  /// 否則設定頁 StreamBuilder 重建時會丟
  /// `Bad state: Stream has already been listened to`。
  Stream<List<String>> streamAvailableMethods({
    required String shopId,
    required String amountType,
  }) {
    final String normalizedShopId = shopId.trim();

    return Stream<List<String>>.multi((
      MultiStreamController<List<String>> listener,
    ) {
      PaymentSettingModel? currentPaymentSetting;
      PlatformPaymentSettingModel? currentPlatformSetting;

      void emitAvailableMethods() {
        final PaymentSettingModel? paymentSetting = currentPaymentSetting;
        final PlatformPaymentSettingModel? platformSetting =
            currentPlatformSetting;
        if (paymentSetting == null || platformSetting == null) {
          return;
        }
        listener.add(
          PaymentResolver.resolveAvailableMethods(
            setting: paymentSetting,
            amountType: amountType,
            platformSetting: platformSetting,
          ),
        );
      }

      final StreamSubscription<PaymentSettingModel> paymentSettingSubscription =
          streamPaymentSetting(normalizedShopId).listen((
            PaymentSettingModel setting,
          ) {
            currentPaymentSetting = setting;
            emitAvailableMethods();
          }, onError: listener.addError);

      final StreamSubscription<PlatformPaymentSettingModel>
      platformSettingSubscription = streamPlatformPaymentSetting().listen((
        PlatformPaymentSettingModel setting,
      ) {
        currentPlatformSetting = setting;
        emitAvailableMethods();
      }, onError: listener.addError);

      listener.onCancel = () async {
        await paymentSettingSubscription.cancel();
        await platformSettingSubscription.cancel();
      };
    });
  }

  /// 一次判斷本次是否可以建立線上付款
  Future<bool> canCreateOnlinePayment({
    required String shopId,
    required String amountType,
  }) async {
    final String normalizedShopId = shopId.trim();

    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      getPaymentSetting(normalizedShopId),
      getPlatformPaymentSetting(),
    ]);

    final PaymentSettingModel paymentSetting =
        results[0] as PaymentSettingModel;

    final PlatformPaymentSettingModel platformSetting =
        results[1] as PlatformPaymentSettingModel;

    return PaymentResolver.canCreateOnlinePayment(
      setting: paymentSetting,
      amountType: amountType,
      platformSetting: platformSetting,
    );
  }

  /// 一次取得線上付款不可用原因
  ///
  /// 回傳空字串代表線上付款可以正常使用。
  Future<String> resolveOnlinePaymentUnavailableReason({
    required String shopId,
    required String amountType,
  }) async {
    final String normalizedShopId = shopId.trim();

    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      getPaymentSetting(normalizedShopId),
      getPlatformPaymentSetting(),
    ]);

    final PaymentSettingModel paymentSetting =
        results[0] as PaymentSettingModel;

    final PlatformPaymentSettingModel platformSetting =
        results[1] as PlatformPaymentSettingModel;

    return PaymentResolver.resolveOnlinePaymentUnavailableReason(
      setting: paymentSetting,
      amountType: amountType,
      platformSetting: platformSetting,
    );
  }

  /// 一次取得指定付款紀錄
  ///
  /// 找不到付款紀錄時回傳 null。
  Future<PaymentModel?> getPayment(String paymentId) async {
    final String normalizedPaymentId = paymentId.trim();

    if (normalizedPaymentId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _paymentsReference.doc(normalizedPaymentId).get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return PaymentModel.fromMap(id: snapshot.id, data: data);
  }

  /// 即時監聽指定付款紀錄
  ///
  /// 找不到付款紀錄時回傳 null。
  Stream<PaymentModel?> streamPayment(String paymentId) {
    final String normalizedPaymentId = paymentId.trim();

    if (normalizedPaymentId.isEmpty) {
      return Stream<PaymentModel?>.value(null);
    }

    return _paymentsReference.doc(normalizedPaymentId).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return PaymentModel.fromMap(id: snapshot.id, data: data);
    });
  }

  /// 取得指定訂單的付款紀錄
  ///
  /// 最新建立的付款排在最前面。
  Stream<List<PaymentModel>> streamBookingPayments({
    required String shopId,
    required String bookingId,
  }) {
    final String normalizedShopId = shopId.trim();
    final String normalizedBookingId = bookingId.trim();

    if (normalizedShopId.isEmpty || normalizedBookingId.isEmpty) {
      return Stream<List<PaymentModel>>.value(const <PaymentModel>[]);
    }

    return _paymentsReference
        .where('shopId', isEqualTo: normalizedShopId)
        .where('bookingId', isEqualTo: normalizedBookingId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_paymentListFromSnapshot);
  }

  /// 一次取得指定訂單最新的付款紀錄
  ///
  /// 尚未建立付款時回傳 null。
  Future<PaymentModel?> getLatestBookingPayment({
    required String shopId,
    required String bookingId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedBookingId = bookingId.trim();

    if (normalizedShopId.isEmpty || normalizedBookingId.isEmpty) {
      return null;
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _paymentsReference
            .where('shopId', isEqualTo: normalizedShopId)
            .where('bookingId', isEqualTo: normalizedBookingId)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final QueryDocumentSnapshot<Map<String, dynamic>> document =
        snapshot.docs.first;

    return PaymentModel.fromMap(id: document.id, data: document.data());
  }

  /// 即時監聽指定會員在某店家的付款紀錄
  ///
  /// 最新建立的付款排在最前面。
  Stream<List<PaymentModel>> streamMemberPayments({
    required String shopId,
    required String userId,
    int limit = 30,
  }) {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();
    final int normalizedLimit = limit <= 0 ? 30 : limit;

    if (normalizedShopId.isEmpty || normalizedUserId.isEmpty) {
      return Stream<List<PaymentModel>>.value(const <PaymentModel>[]);
    }

    return _paymentsReference
        .where('shopId', isEqualTo: normalizedShopId)
        .where('userId', isEqualTo: normalizedUserId)
        .orderBy('createdAt', descending: true)
        .limit(normalizedLimit)
        .snapshots()
        .map(_paymentListFromSnapshot);
  }

  /// 即時監聽指定店家的付款紀錄
  ///
  /// 供之後店家後台付款管理列表使用。
  Stream<List<PaymentModel>> streamShopPayments({
    required String shopId,
    int limit = 50,
  }) {
    final String normalizedShopId = shopId.trim();
    final int normalizedLimit = limit <= 0 ? 50 : limit;

    if (normalizedShopId.isEmpty) {
      return Stream<List<PaymentModel>>.value(const <PaymentModel>[]);
    }

    return _paymentsReference
        .where('shopId', isEqualTo: normalizedShopId)
        .orderBy('createdAt', descending: true)
        .limit(normalizedLimit)
        .snapshots()
        .map(_paymentListFromSnapshot);
  }

  /// 將 Firestore 查詢結果轉成付款模型清單
  List<PaymentModel> _paymentListFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> document,
    ) {
      return PaymentModel.fromMap(id: document.id, data: document.data());
    }).toList();
  }
}
