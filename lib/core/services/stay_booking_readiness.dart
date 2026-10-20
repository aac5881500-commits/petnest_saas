import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';

/// Configuration readiness only; date inventory remains the booking service's job.
class StayBookingReadiness {
  /// Missing data is not an explicit instruction to open accommodation.
  static bool requested(Map<String, dynamic> shop) =>
      DaycareBool.parse(shop['bookingEnabled']);
  factory StayBookingReadiness(
    List<Map<String, dynamic>> types,
    List<Map<String, dynamic>> rooms, {
    String? shopId,
  }) {
    bool belongs(Map<String, dynamic> item) {
      final owner = (item['shopId'] ?? '').toString().trim();
      return shopId == null || owner.isEmpty || owner == shopId;
    }

    final ids = types
        .where(belongs)
        .map((type) => (type['id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return StayBookingReadiness._(
      ids.length,
      rooms
          .where(
            (room) =>
                belongs(room) &&
                ids.contains((room['roomTypeId'] ?? '').toString().trim()),
          )
          .toList(),
    );
  }

  StayBookingReadiness._(this.typeCount, this.rooms);

  final int typeCount;
  final List<Map<String, dynamic>> rooms;
  int get usableCount => rooms
      .where((room) => !DaycareOccupancyService.isRoomDocumentUnsellable(room))
      .length;
  bool get ready => typeCount > 0 && usableCount > 0;
  static bool canBatchEnable(Map<String, dynamic> room) =>
      !DaycareOccupancyService.isRoomEnabled(room) &&
      !DaycareOccupancyService.isPermanentStatusUnsellable(
        DaycareOccupancyService.permanentStatusOf(room),
      );
  String get action => typeCount == 0
      ? '建立第一個房型'
      : rooms.isEmpty
      ? '建立實際房間'
      : '啟用可預約房間';
  String get reason => typeCount == 0
      ? '尚未建立房型'
      : rooms.isEmpty
      ? '房型底下尚未建立實際房間'
      : '沒有已啟用且可提供住宿的房間；請確認永久維修或停用狀態';

  static Future<StayBookingReadiness> load(String shopId) async {
    final shop = FirebaseFirestore.instance.collection('shops').doc(shopId);
    final snapshots = await Future.wait([
      shop
          .collection('room_types')
          .get(const GetOptions(source: Source.server)),
      shop.collection('rooms').get(const GetOptions(source: Source.server)),
    ]);
    return StayBookingReadiness(
      snapshots[0].docs.map((d) => {...d.data(), 'id': d.id}).toList(),
      snapshots[1].docs.map((d) => {...d.data(), 'id': d.id}).toList(),
      shopId: shopId,
    );
  }

  static Stream<StayBookingReadiness> watch(String shopId) {
    final shop = FirebaseFirestore.instance.collection('shops').doc(shopId);
    late StreamController<StayBookingReadiness> controller;
    StreamSubscription? typesSub;
    StreamSubscription? roomsSub;
    List<Map<String, dynamic>>? types;
    List<Map<String, dynamic>>? rooms;
    void emit() {
      if (types != null && rooms != null) {
        controller.add(StayBookingReadiness(types!, rooms!, shopId: shopId));
      }
    }

    controller = StreamController<StayBookingReadiness>(
      onListen: () {
        typesSub = shop
            .collection('room_types')
            .snapshots()
            .listen(
              (snapshot) {
                types = snapshot.docs
                    .map((d) => {...d.data(), 'id': d.id})
                    .toList();
                emit();
              },
              onError: (Object error, StackTrace stack) {
                types = null;
                controller.addError(error, stack);
              },
            );
        roomsSub = shop
            .collection('rooms')
            .snapshots()
            .listen(
              (snapshot) {
                rooms = snapshot.docs
                    .map((d) => {...d.data(), 'id': d.id})
                    .toList();
                emit();
              },
              onError: (Object error, StackTrace stack) {
                rooms = null;
                controller.addError(error, stack);
              },
            );
      },
      onCancel: () async {
        await typesSub?.cancel();
        await roomsSub?.cancel();
      },
    );
    return controller.stream;
  }
}

/// The caller supplies one atomic write for the room operation and stay switch.
/// Re-read after a dialog so confirmation never authorizes a different action.
Future<bool> applyStayRoomChange({
  required Set<String> affectedIds,
  required Future<StayBookingReadiness> Function() load,
  required Future<bool> Function() bookingEnabled,
  required Future<bool> Function() confirmLast,
  required Future<void> Function(bool closeStay) commit,
}) async {
  bool losesLast(StayBookingReadiness state) =>
      state.ready &&
      !state.rooms.any(
        (room) =>
            !affectedIds.contains(room['id']) &&
            !DaycareOccupancyService.isRoomDocumentUnsellable(room),
      );
  final before = await load();
  final needsConfirmation = losesLast(before) && await bookingEnabled();
  if (needsConfirmation && !await confirmLast()) return false;
  final latest = await load();
  final close = losesLast(latest) && await bookingEnabled();
  if (close && !needsConfirmation) {
    throw StateError('房間狀態已變更，請重新操作以確認最後一間房間');
  }
  await commit(close);
  return true;
}
