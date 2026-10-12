// 檔案名稱：lib/core/services/shop_deletion_service.dart
// 功能說明：呼叫最高管理員店家刪除預覽、工作、批次與驗證 Functions。

import 'package:cloud_functions/cloud_functions.dart';

abstract interface class ShopDeletionGateway {
  Future<Map<String, dynamic>> preview(String shopId);

  Future<Map<String, dynamic>> createJob({
    required String shopId,
    required String mode,
    required String reason,
    required String typedShopCode,
    required bool irreversibleAcknowledged,
    required bool testDataConfirmed,
  });

  Future<Map<String, dynamic>> getJob({String? shopId, String? jobId});

  Future<Map<String, dynamic>> runBatch(String jobId);

  Future<Map<String, dynamic>> verify(String jobId);
}

class ShopDeletionService implements ShopDeletionGateway {
  ShopDeletionService._();

  static final ShopDeletionService instance = ShopDeletionService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-east1',
  );

  @override
  Future<Map<String, dynamic>> preview(String shopId) {
    return _call('previewShopDeletion', <String, dynamic>{'shopId': shopId});
  }

  @override
  Future<Map<String, dynamic>> createJob({
    required String shopId,
    required String mode,
    required String reason,
    required String typedShopCode,
    required bool irreversibleAcknowledged,
    required bool testDataConfirmed,
  }) {
    return _call('createShopDeletionJob', <String, dynamic>{
      'shopId': shopId,
      'mode': mode,
      'reason': reason,
      'typedShopCode': typedShopCode,
      'irreversibleAcknowledged': irreversibleAcknowledged,
      'testDataConfirmed': testDataConfirmed,
    });
  }

  @override
  Future<Map<String, dynamic>> getJob({String? shopId, String? jobId}) {
    return _call('getShopDeletionJob', <String, dynamic>{
      if (shopId != null && shopId.isNotEmpty) 'shopId': shopId,
      if (jobId != null && jobId.isNotEmpty) 'jobId': jobId,
    });
  }

  @override
  Future<Map<String, dynamic>> runBatch(String jobId) {
    return _call('runShopDeletionBatch', <String, dynamic>{'jobId': jobId});
  }

  @override
  Future<Map<String, dynamic>> verify(String jobId) {
    return _call('verifyShopDeletion', <String, dynamic>{'jobId': jobId});
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable(name)
          .call<dynamic>(data);
      final dynamic raw = result.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      throw const ShopDeletionException('後端回傳格式不正確。');
    } on FirebaseFunctionsException catch (error) {
      final dynamic details = error.details;
      final Map<String, dynamic> detailMap = details is Map
          ? Map<String, dynamic>.from(details)
          : const <String, dynamic>{};
      final List<String> blockers = detailMap['blockers'] is List
          ? List<dynamic>.from(
              detailMap['blockers'] as List,
            ).map((dynamic value) => value.toString()).toList()
          : const <String>[];
      final String rawMessage = error.message?.trim() ?? '';
      final bool genericNotFound =
          error.code == 'not-found' &&
          (rawMessage.isEmpty || rawMessage.toUpperCase() == 'NOT FOUND');
      final String message = genericNotFound
          ? '$name 尚未部署到目前 Firebase 專案或區域。'
                '請確認 petnest-saas／asia-east1 的 Functions 部署狀態。'
          : rawMessage.isNotEmpty
          ? rawMessage
          : '店家刪除操作失敗，請稍後再試。';
      throw ShopDeletionException(
        message,
        code: error.code,
        blockers: blockers,
        scanId: '${detailMap['scanId'] ?? ''}',
        stage: '${detailMap['stage'] ?? ''}',
        retryable: detailMap['retryable'] == true,
      );
    }
  }
}

class ShopDeletionException implements Exception {
  const ShopDeletionException(
    this.message, {
    this.code = '',
    this.blockers = const <String>[],
    this.scanId = '',
    this.stage = '',
    this.retryable = false,
  });

  final String message;
  final String code;
  final List<String> blockers;
  final String scanId;
  final String stage;
  final bool retryable;

  @override
  String toString() {
    final String suffix = <String>[
      if (code.isNotEmpty) '錯誤類型：$code',
      if (stage.isNotEmpty) '階段：$stage',
      if (scanId.isNotEmpty) '掃描識別碼：$scanId',
    ].join('｜');
    return suffix.isEmpty ? message : '$message\n$suffix';
  }
}
