// 檔案名稱：lib/core/services/camera_access_service.dart
// 功能說明：呼叫受保護的攝影機讀取與外部品牌分享申請，不直接讀取 devices。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:petnest_saas/core/models/camera_access_policy.dart';

class CameraAccessException implements Exception {
  const CameraAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CustomerRoomCamera {
  const CustomerRoomCamera({
    required this.viewMode,
    required this.name,
    required this.provider,
    required this.providerLabel,
    this.appName = '',
    required this.customerShareNote,
    required this.deviceId,
    required this.shopId,
    required this.roomId,
    required this.roomName,
    required this.bookingKind,
    required this.bookingKindLabel,
    required this.servicePeriodLabel,
    required this.customerName,
    this.url = '',
  });

  final String viewMode;
  final String name;
  final String url;
  final String provider;
  final String providerLabel;
  final String appName;
  final String customerShareNote;
  final String deviceId;
  final String shopId;
  final String roomId;
  final String roomName;
  final String bookingKind;
  final String bookingKindLabel;
  final String servicePeriodLabel;
  final String customerName;

  bool get isExternal => viewMode == 'external_app';
}

class CustomerRoomCameraResult {
  const CustomerRoomCameraResult._({
    required this.visibility,
    this.camera,
    this.message = '',
  });

  const CustomerRoomCameraResult.hidden() : this._(visibility: 'hidden');

  const CustomerRoomCameraResult.ready(CustomerRoomCamera camera)
    : this._(visibility: 'ready', camera: camera);

  const CustomerRoomCameraResult.error(String message)
    : this._(visibility: 'error', message: message);

  final String visibility;
  final CustomerRoomCamera? camera;
  final String message;

  bool get isReady => visibility == 'ready' && camera != null;
  bool get isHidden => visibility == 'hidden';
  bool get isError => visibility == 'error';
}

class CameraAccessService {
  CameraAccessService._();

  static final CameraAccessService instance = CameraAccessService._();

  static const String functionsRegion = 'asia-east1';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseFunctions get _functions {
    return FirebaseFunctions.instanceFor(region: functionsRegion);
  }

  Future<CustomerRoomCameraResult> getCustomerRoomCamera(String bookingId) {
    return _guard(() async {
      final Map<String, dynamic> data = await _call('getCustomerRoomCamera', {
        'bookingId': bookingId,
      });
      final String visibility = (data['visibility'] ?? '').toString();
      if (visibility == 'unsupported') {
        final String message = (data['message'] ?? '').toString().trim();
        return CustomerRoomCameraResult.error(
          message.isEmpty ? '此房間的外部攝影機品牌尚未開放' : message,
        );
      }
      if (visibility != 'ready') {
        return const CustomerRoomCameraResult.hidden();
      }
      final Object? raw = data['camera'];
      if (raw is! Map) {
        return const CustomerRoomCameraResult.hidden();
      }
      final Map<String, dynamic> camera = Map<String, dynamic>.from(raw);
      return CustomerRoomCameraResult.ready(
        CustomerRoomCamera(
          viewMode: (camera['viewMode'] ?? 'web_url').toString(),
          name: (camera['name'] ?? '房間攝影機').toString(),
          url: (camera['url'] ?? '').toString(),
          provider: (camera['provider'] ?? '').toString(),
          providerLabel: (camera['providerLabel'] ?? '').toString(),
          appName: (camera['appName'] ?? '').toString(),
          customerShareNote: (camera['customerShareNote'] ?? '').toString(),
          deviceId: (camera['deviceId'] ?? '').toString(),
          shopId: (camera['shopId'] ?? '').toString(),
          roomId: (camera['roomId'] ?? '').toString(),
          roomName: (camera['roomName'] ?? '').toString(),
          bookingKind: (camera['bookingKind'] ?? '').toString(),
          bookingKindLabel: (camera['bookingKindLabel'] ?? '').toString(),
          servicePeriodLabel: (camera['servicePeriodLabel'] ?? '').toString(),
          customerName: (camera['customerName'] ?? '').toString(),
        ),
      );
    });
  }

  Stream<List<Map<String, dynamic>>> watchMyRequests({
    required String shopId,
    required String bookingId,
  }) {
    final String uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty || shopId.trim().isEmpty) {
      return Stream<List<Map<String, dynamic>>>.error(
        const CameraAccessException('請先登入後再查看分享申請'),
      );
    }
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('camera_access_requests')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                return <String, dynamic>{'id': doc.id, ...doc.data()};
              })
              .where((Map<String, dynamic> item) {
                return (item['bookingId'] ?? '').toString() == bookingId;
              })
              .toList();
        });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchShopActiveRequests(
    String shopId,
  ) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('camera_access_requests')
        .where(
          'status',
          whereIn: const <String>[
            cameraRequestPending,
            cameraRequestNeedsInfo,
            cameraRequestInvited,
            cameraRequestConfirmed,
            cameraRequestRevocationPending,
          ],
        )
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchShopClosedRequests(
    String shopId, {
    int limit = 20,
  }) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('camera_access_requests')
        .where('status', isEqualTo: cameraRequestClosed)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<Map<String, dynamic>> submitRequest({
    required String bookingId,
    required String externalAccount,
  }) {
    return _call('submitCameraAccessRequest', <String, dynamic>{
      'bookingId': bookingId,
      'externalAccount': externalAccount.trim(),
    });
  }

  Future<Map<String, dynamic>> confirmWatching({
    required String shopId,
    required String requestId,
  }) {
    return _call('confirmCustomerCameraWatching', <String, dynamic>{
      'shopId': shopId,
      'requestId': requestId,
    });
  }

  Future<Map<String, dynamic>> shopUpdate({
    required String shopId,
    required String requestId,
    required String action,
    String reason = '',
  }) {
    return _call('updateCameraAccessRequest', <String, dynamic>{
      'shopId': shopId,
      'requestId': requestId,
      'action': action,
      'reason': reason.trim(),
    });
  }

  Future<CustomerRoomCameraResult> _guard(
    Future<CustomerRoomCameraResult> Function() action,
  ) async {
    try {
      return await action();
    } on CameraAccessException catch (error) {
      return CustomerRoomCameraResult.error(error.message);
    } catch (error) {
      return CustomerRoomCameraResult.error(_message(error));
    }
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable(name)
          .call(data);
      final Object? raw = result.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return <String, dynamic>{};
    } catch (error) {
      throw CameraAccessException(_message(error));
    }
  }

  String _message(Object error) {
    if (error is CameraAccessException) {
      return error.message;
    }
    if (error is FirebaseFunctionsException) {
      final String text = (error.message ?? '').trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    if (error is FirebaseException) {
      return '讀取分享申請失敗，請再試一次';
    }
    return '攝影機資料暫時無法讀取，請再試一次';
  }
}
