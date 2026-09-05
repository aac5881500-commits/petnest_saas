// 檔案名稱：lib/core/services/payment_gateway_request_service.dart
// 功能說明：讀取店家金流首次設定、修改申請與重新啟用申請紀錄。
// 💳 店家金流申請 Service
// 注意：目前僅提供安全的讀取與查詢功能，
// 送審、核准、退回及敏感資料處理之後交由 Cloud Functions。

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment_gateway_request_model.dart';
import '../models/payment_gateway_status.dart';

class PaymentGatewayRequestService {
  PaymentGatewayRequestService._();

  static final PaymentGatewayRequestService instance =
      PaymentGatewayRequestService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 金流申請集合
  ///
  /// Firestore 路徑：
  /// shop_payment_requests/{requestId}
  CollectionReference<Map<String, dynamic>> get _requestsReference {
    return _firestore.collection('shop_payment_requests');
  }

  /// 一次取得指定金流申請
  ///
  /// 找不到時回傳 null。
  Future<PaymentGatewayRequestModel?> getRequest(String requestId) async {
    final String normalizedRequestId = requestId.trim();

    if (normalizedRequestId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _requestsReference.doc(normalizedRequestId).get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return PaymentGatewayRequestModel.fromMap(id: snapshot.id, data: data);
  }

  /// 即時監聽指定金流申請
  ///
  /// 文件不存在時回傳 null。
  Stream<PaymentGatewayRequestModel?> streamRequest(String requestId) {
    final String normalizedRequestId = requestId.trim();

    if (normalizedRequestId.isEmpty) {
      return Stream<PaymentGatewayRequestModel?>.value(null);
    }

    return _requestsReference.doc(normalizedRequestId).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return PaymentGatewayRequestModel.fromMap(id: snapshot.id, data: data);
    });
  }

  /// 即時監聽指定店家的全部金流申請
  ///
  /// 最新申請排在最前面。
  Stream<List<PaymentGatewayRequestModel>> streamShopRequests({
    required String shopId,
    int limit = 30,
  }) {
    final String normalizedShopId = shopId.trim();
    final int normalizedLimit = limit <= 0 ? 30 : limit;

    if (normalizedShopId.isEmpty) {
      return Stream<List<PaymentGatewayRequestModel>>.value(
        const <PaymentGatewayRequestModel>[],
      );
    }

    return _requestsReference
        .where('shopId', isEqualTo: normalizedShopId)
        .orderBy('createdAt', descending: true)
        .limit(normalizedLimit)
        .snapshots()
        .map(_requestListFromSnapshot);
  }

  /// 一次取得指定店家最新一筆金流申請
  ///
  /// 尚未送出過申請時回傳 null。
  Future<PaymentGatewayRequestModel?> getLatestShopRequest({
    required String shopId,
  }) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return null;
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _requestsReference
            .where('shopId', isEqualTo: normalizedShopId)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final QueryDocumentSnapshot<Map<String, dynamic>> document =
        snapshot.docs.first;

    return PaymentGatewayRequestModel.fromMap(
      id: document.id,
      data: document.data(),
    );
  }

  /// 即時監聽指定店家最新一筆申請
  Stream<PaymentGatewayRequestModel?> streamLatestShopRequest({
    required String shopId,
  }) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<PaymentGatewayRequestModel?>.value(null);
    }

    return _requestsReference
        .where('shopId', isEqualTo: normalizedShopId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }

          final QueryDocumentSnapshot<Map<String, dynamic>> document =
              snapshot.docs.first;

          return PaymentGatewayRequestModel.fromMap(
            id: document.id,
            data: document.data(),
          );
        });
  }

  /// 判斷指定店家是否已有等待審核的申請
  Future<bool> hasPendingRequest({required String shopId}) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return false;
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _requestsReference
            .where('shopId', isEqualTo: normalizedShopId)
            .where('status', isEqualTo: PaymentGatewayReviewStatus.pending)
            .limit(1)
            .get();

    return snapshot.docs.isNotEmpty;
  }

  /// 即時監聽指定店家是否已有等待審核的申請
  Stream<bool> streamHasPendingRequest({required String shopId}) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<bool>.value(false);
    }

    return _requestsReference
        .where('shopId', isEqualTo: normalizedShopId)
        .where('status', isEqualTo: PaymentGatewayReviewStatus.pending)
        .limit(1)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.isNotEmpty;
        });
  }

  /// 平台端即時監聽等待審核的金流申請
  ///
  /// 最早送出的申請排在最前面，方便依序審核。
  Stream<List<PaymentGatewayRequestModel>> streamPendingRequests({
    int limit = 50,
  }) {
    final int normalizedLimit = limit <= 0 ? 50 : limit;

    return _requestsReference
        .where('status', isEqualTo: PaymentGatewayReviewStatus.pending)
        .orderBy('createdAt')
        .limit(normalizedLimit)
        .snapshots()
        .map(_requestListFromSnapshot);
  }

  /// 平台端依狀態監聽金流申請
  ///
  /// 可查詢 approved、rejected、pending。
  Stream<List<PaymentGatewayRequestModel>> streamRequestsByStatus({
    required String status,
    int limit = 50,
  }) {
    final String normalizedStatus = status.trim();
    final int normalizedLimit = limit <= 0 ? 50 : limit;

    if (normalizedStatus.isEmpty) {
      return Stream<List<PaymentGatewayRequestModel>>.value(
        const <PaymentGatewayRequestModel>[],
      );
    }

    return _requestsReference
        .where('status', isEqualTo: normalizedStatus)
        .orderBy('createdAt', descending: true)
        .limit(normalizedLimit)
        .snapshots()
        .map(_requestListFromSnapshot);
  }

  /// 取得指定店家最近一次已核准申請
  ///
  /// 修改金流資料時，可以用來帶入 previousRequestId。
  Future<PaymentGatewayRequestModel?> getLatestApprovedRequest({
    required String shopId,
  }) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return null;
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _requestsReference
            .where('shopId', isEqualTo: normalizedShopId)
            .where('status', isEqualTo: PaymentGatewayReviewStatus.approved)
            .orderBy('reviewedAt', descending: true)
            .limit(1)
            .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final QueryDocumentSnapshot<Map<String, dynamic>> document =
        snapshot.docs.first;

    return PaymentGatewayRequestModel.fromMap(
      id: document.id,
      data: document.data(),
    );
  }

  /// 將 Firestore 查詢結果轉換為申請模型清單
  List<PaymentGatewayRequestModel> _requestListFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> document,
    ) {
      return PaymentGatewayRequestModel.fromMap(
        id: document.id,
        data: document.data(),
      );
    }).toList();
  }
}
