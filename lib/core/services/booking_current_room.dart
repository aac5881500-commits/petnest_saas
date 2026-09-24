// 檔案名稱：lib/core/services/booking_current_room.dart
// 功能說明：從訂單最新欄位讀取目前房型／實體房間，不依操作紀錄推斷

import 'package:petnest_saas/core/services/shop_room_name_lookup.dart';

enum BookingCurrentRoomAudience { staff, customer }

class BookingCurrentRoom {
  const BookingCurrentRoom({
    required this.roomTypeName,
    required this.physicalRoomLabel,
    required this.hasPhysicalRoom,
    this.shopId = '',
    this.roomId = '',
  });

  final String roomTypeName;
  final String physicalRoomLabel;
  final bool hasPhysicalRoom;
  final String shopId;
  final String roomId;

  static bool isPlaceholder(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ||
        trimmed == '---' ||
        trimmed == '-' ||
        trimmed == '—' ||
        trimmed.toLowerCase() == 'null';
  }

  static String _text(dynamic raw) {
    if (raw == null) {
      return '';
    }
    return raw.toString().trim();
  }

  static String _firstReal(List<dynamic> candidates) {
    for (final dynamic raw in candidates) {
      final String text = _text(raw);
      if (!isPlaceholder(text)) {
        return text;
      }
    }
    return '';
  }

  factory BookingCurrentRoom.fromBooking(Map<String, dynamic> data) {
    final String typeName = _firstReal(<dynamic>[
      data['roomTypeName'],
      data['roomTypeNameSnapshot'],
      data['requestedRoomTypeName'],
    ]);
    final String rawName = _firstReal(<dynamic>[
      data['roomName'],
      data['roomNumber'],
      data['roomNumberSnapshot'],
    ]);
    final String roomId = _firstReal(<dynamic>[data['roomId']]);
    final bool nameIsId = ShopRoomNameLookup.looksLikeDocumentId(rawName);
    final String displayName = nameIsId ? '' : rawName;
    final bool hasPhysical =
        displayName.isNotEmpty || roomId.isNotEmpty || nameIsId;
    return BookingCurrentRoom(
      roomTypeName: typeName,
      physicalRoomLabel: displayName,
      hasPhysicalRoom: hasPhysical,
      shopId: _text(data['shopId']),
      roomId: nameIsId && roomId.isEmpty ? rawName : roomId,
    );
  }

  bool get needsRoomNameLookup =>
      hasPhysicalRoom && physicalRoomLabel.isEmpty && roomId.isNotEmpty;

  String typeDisplay() {
    return roomTypeName.isEmpty ? '未指定' : roomTypeName;
  }

  String physicalDisplay(
    BookingCurrentRoomAudience audience, {
    String resolvedRoomName = '',
  }) {
    final String resolved = resolvedRoomName.trim();
    if (resolved.isNotEmpty) {
      return resolved;
    }
    if (physicalRoomLabel.isNotEmpty) {
      return physicalRoomLabel;
    }
    if (hasPhysicalRoom && roomId.isNotEmpty) {
      return ShopRoomNameLookup.missingLabel;
    }
    if (audience == BookingCurrentRoomAudience.staff) {
      return '尚未分配實體房間';
    }
    return '房間將由店家安排';
  }
}
