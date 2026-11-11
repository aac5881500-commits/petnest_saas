import 'dart:async';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/room_status_palette.dart';
import 'package:petnest_saas/core/services/housekeeping_setting_service.dart';

/// Each mounted shop page owns its subscription; no global palette can leak
/// between shops, browser tabs, embedded rooms or independent accounts.
mixin RoomStatusPaletteState<T extends StatefulWidget> on State<T> {
  String get roomPaletteShopId;
  RoomStatusPalette roomPalette = RoomStatusPalette.defaults;
  StreamSubscription<RoomStatusPalette>? _roomPaletteSubscription;
  String? _roomPaletteShop;
  int _roomPaletteEpoch = 0;
  @protected
  Stream<RoomStatusPalette> roomPaletteStream(String shopId) =>
      HousekeepingSettingService.instance
          .streamSetting(shopId)
          .map((setting) => setting.roomStatusColors);
  void _watchRoomPalette() {
    final shopId = roomPaletteShopId;
    if (_roomPaletteShop == shopId) return;
    _roomPaletteShop = shopId;
    roomPalette = RoomStatusPalette.defaults;
    _roomPaletteSubscription?.cancel();
    final epoch = ++_roomPaletteEpoch;
    _roomPaletteSubscription = roomPaletteStream(shopId).listen(
      (palette) {
        if (mounted && epoch == _roomPaletteEpoch && roomPalette != palette) {
          setState(() => roomPalette = palette);
        }
      },
      onError: (Object error, StackTrace stack) {
        // Keep the last successfully loaded palette during transient outages.
        debugPrint('房況配色讀取失敗：$error');
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _watchRoomPalette();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _watchRoomPalette();
  }

  @override
  void dispose() {
    _roomPaletteEpoch++;
    _roomPaletteSubscription?.cancel();
    super.dispose();
  }
}
