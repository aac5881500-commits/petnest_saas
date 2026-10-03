// 檔案名稱：lib/core/services/camera_access_service.dart
// 功能說明：呼叫受保護的攝影機讀取與分享申請。顧客只聽訂單、店家總開關與房間訊號。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:petnest_saas/core/models/camera_access_policy.dart';
import 'package:petnest_saas/core/models/camera_entry_watch.dart';

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

  const CustomerRoomCameraResult.unsupported(String message)
    : this._(visibility: 'unsupported', message: message);

  final String visibility;
  final CustomerRoomCamera? camera;
  final String message;

  bool get isReady => visibility == 'ready' && camera != null;
  bool get isHidden => visibility == 'hidden';
  bool get isError => visibility == 'error';
  bool get isUnsupported => visibility == 'unsupported';
}

enum CustomerCameraEntryKind { none, retry, unsupported, ready }

class CustomerCameraEntryPresentation {
  const CustomerCameraEntryPresentation({
    required this.kind,
    required this.label,
  });

  final CustomerCameraEntryKind kind;
  final String label;

  bool get showsCamera => kind != CustomerCameraEntryKind.none;
}

CustomerCameraEntryPresentation customerCameraEntryPresentation(
  CustomerRoomCameraResult? result,
) {
  if (result == null || result.isHidden) {
    return const CustomerCameraEntryPresentation(
      kind: CustomerCameraEntryKind.none,
      label: '',
    );
  }
  if (result.isUnsupported) {
    return const CustomerCameraEntryPresentation(
      kind: CustomerCameraEntryKind.unsupported,
      label: '品牌尚未開放',
    );
  }
  if (result.isError) {
    final String label = result.message.trim().isEmpty
        ? '重新讀取'
        : result.message.trim();
    return CustomerCameraEntryPresentation(
      kind: CustomerCameraEntryKind.retry,
      label: label,
    );
  }
  final CustomerRoomCamera? camera = result.camera;
  if (!result.isReady || camera == null) {
    return const CustomerCameraEntryPresentation(
      kind: CustomerCameraEntryKind.none,
      label: '',
    );
  }
  return CustomerCameraEntryPresentation(
    kind: CustomerCameraEntryKind.ready,
    label: customerCameraEntryTitle(
      viewMode: camera.viewMode,
      provider: camera.provider,
    ),
  );
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

  Future<CustomerRoomCameraResult> getCustomerRoomCamera(
    String bookingId,
  ) async {
    if (_auth.currentUser == null) {
      _logCameraFailure(code: 'unauthenticated');
      return const CustomerRoomCameraResult.error('請重新登入後再試');
    }
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('getCustomerRoomCamera')
          .call(<String, dynamic>{'bookingId': bookingId});
      final Object? raw = result.data;
      final Map<String, dynamic> data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      return _cameraResult(data);
    } on FirebaseFunctionsException catch (error) {
      _logCameraFailure(code: error.code, message: error.message ?? '');
      return CustomerRoomCameraResult.error(
        customerCameraFailureMessage(
          code: error.code,
          message: error.message ?? '',
        ),
      );
    } catch (error) {
      _logCameraFailure(code: 'unknown', message: error.toString());
      return const CustomerRoomCameraResult.error('攝影機暫時無法讀取，請再試一次');
    }
  }

  Stream<CameraEntryWatch> watchCustomerCameraEntry(String bookingId) {
    late StreamController<CameraEntryWatch> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? bookingSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? shopSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? roomSub;
    StreamSubscription<User?>? authSub;
    String shopId = '';
    String roomId = '';
    Map<String, dynamic>? booking;
    bool shopOn = true;
    int revision = 0;

    void emit() {
      if (booking == null || controller.isClosed) {
        return;
      }
      controller.add(
        CameraEntryWatch(
          bookingId: bookingId,
          shopId: shopId,
          roomId: (booking!['roomId'] ?? '').toString().trim(),
          serviceOpen: cameraServiceOpen(booking),
          shopCameraOn: shopOn,
          roomRevision: revision,
        ),
      );
    }

    void listenRoom(String nextShop, String nextRoom) {
      roomSub?.cancel();
      roomSub = null;
      roomId = nextRoom;
      revision = 0;
      if (nextShop.isEmpty || nextRoom.isEmpty) {
        return;
      }
      roomSub = _firestore
          .collection('shops')
          .doc(nextShop)
          .collection('rooms')
          .doc(nextRoom)
          .snapshots()
          .listen((DocumentSnapshot<Map<String, dynamic>> snap) {
            revision = cameraRoomRevisionOf(snap.data());
            emit();
          }, onError: controller.addError);
    }

    void listenShop(String nextShop) {
      shopSub?.cancel();
      shopSub = null;
      shopId = nextShop;
      shopOn = true;
      if (nextShop.isEmpty) {
        return;
      }
      shopSub = _firestore.collection('shops').doc(nextShop).snapshots().listen(
        (DocumentSnapshot<Map<String, dynamic>> snap) {
          shopOn = shopCameraSectionOn(snap.data());
          emit();
        },
        onError: controller.addError,
      );
    }

    controller = StreamController<CameraEntryWatch>(
      onListen: () {
        authSub = _auth.authStateChanges().listen((User? user) {
          if (user == null && !controller.isClosed) {
            controller.addError(const CameraAccessException('請重新登入後再試'));
          }
        });
        bookingSub = _firestore
            .collection('bookings')
            .doc(bookingId)
            .snapshots()
            .listen((DocumentSnapshot<Map<String, dynamic>> snap) {
              booking = snap.data() ?? <String, dynamic>{};
              final String nextShop = (booking!['shopId'] ?? '')
                  .toString()
                  .trim();
              final String nextRoom = (booking!['roomId'] ?? '')
                  .toString()
                  .trim();
              if (nextShop != shopId) {
                listenShop(nextShop);
                listenRoom(nextShop, nextRoom);
              } else if (nextRoom != roomId) {
                listenRoom(nextShop, nextRoom);
              }
              emit();
            }, onError: controller.addError);
      },
      onCancel: () async {
        await bookingSub?.cancel();
        await shopSub?.cancel();
        await roomSub?.cancel();
        await authSub?.cancel();
      },
    );
    return controller.stream;
  }

  CustomerRoomCameraResult _cameraResult(Map<String, dynamic> data) {
    final String visibility = (data['visibility'] ?? '').toString();
    if (visibility == 'unsupported') {
      final String message = (data['message'] ?? '').toString().trim();
      return CustomerRoomCameraResult.unsupported(
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
  }

  void _logCameraFailure({required String code, String message = ''}) {
    debugPrint(
      cameraCallableDiagnostic(
        name: 'getCustomerRoomCamera',
        region: functionsRegion,
        code: code,
        message: message,
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> watchMyRequests({
    required String shopId,
    required String bookingId,
  }) {
    final String uid = _auth.currentUser?.uid ?? '';
    final String shop = shopId.trim();
    if (uid.isEmpty || shop.isEmpty) {
      _logWatchMyRequests(
        code: uid.isEmpty ? 'unauthenticated' : 'invalid-argument',
        uid: uid,
        shopId: shop,
        bookingId: bookingId,
      );
      return Stream<List<Map<String, dynamic>>>.error(
        const CameraAccessException('請先登入後再查看分享申請'),
      );
    }
    // 只查自己的 userId。沒有文件時快照是空清單，不是錯誤。
    return _firestore
        .collection('shops')
        .doc(shop)
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
        })
        .handleError((Object error, StackTrace stack) {
          final String code = error is FirebaseException
              ? error.code
              : 'unknown';
          _logWatchMyRequests(
            code: code,
            uid: uid,
            shopId: shop,
            bookingId: bookingId,
            message: error is FirebaseException ? (error.message ?? '') : '',
          );
          Error.throwWithStackTrace(error, stack);
        });
  }

  void _logWatchMyRequests({
    required String code,
    required String uid,
    required String shopId,
    required String bookingId,
    String message = '',
  }) {
    final String safe = message
        .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '[url]')
        .replaceAll(RegExp(r'\S+@\S+'), '[account]');
    debugPrint(
      'watchMyRequests code=$code uid=$uid query=userId==uid '
      'shopId=$shopId bookingId=$bookingId message=$safe',
    );
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
