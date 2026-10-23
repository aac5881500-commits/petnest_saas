// 功能：穩定讀取所屬店家的房型內頁外觀，供正式頁與既有編輯預覽共用。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/room_intro_appearance.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class RoomIntroAppearanceScope extends InheritedWidget {
  const RoomIntroAppearanceScope({
    super.key,
    required this.appearance,
    required this.theme,
    required super.child,
    this.ready = true,
    this.error,
    this.shopData,
  });
  final RoomIntroAppearance appearance;
  final HomeThemeModel theme;
  final bool ready;
  final Object? error;
  final Map<String, dynamic>? shopData;
  static RoomIntroAppearanceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RoomIntroAppearanceScope>();
  @override
  bool updateShouldNotify(RoomIntroAppearanceScope oldWidget) =>
      appearance != oldWidget.appearance ||
      theme != oldWidget.theme ||
      ready != oldWidget.ready ||
      error != oldWidget.error ||
      shopData != oldWidget.shopData;
}

class RoomIntroAppearanceHost extends StatefulWidget {
  const RoomIntroAppearanceHost({
    super.key,
    required this.shopId,
    required this.child,
    this.shopStream,
  });
  final String shopId;
  final Widget child;
  final Stream<Map<String, dynamic>?>? shopStream;
  @override
  State<RoomIntroAppearanceHost> createState() =>
      _RoomIntroAppearanceHostState();
}

class _RoomIntroAppearanceHostState extends State<RoomIntroAppearanceHost> {
  late Stream<Map<String, dynamic>?> _stream;
  void _bind() => _stream =
      widget.shopStream ?? ShopService.instance.streamShop(widget.shopId);
  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant RoomIntroAppearanceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId ||
        oldWidget.shopStream != widget.shopStream) {
      _bind();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>?>(
    key: ValueKey(widget.shopId),
    stream: _stream,
    builder: (context, snapshot) {
      final home = snapshot.data?['homeAppearance'];
      final modern = home is Map ? home['modern'] : null;
      final colors = modern is Map ? modern['themeColors'] : null;
      final theme = home is Map && home['layout'] == 'modern'
          ? HomeThemeModel.fromMap(
              colors,
              fallback: HomeThemeModel.modernDefault,
            )
          : HomeThemeModel.fromClassicSettings(
              rawData: home is Map ? home['classic'] ?? home : null,
            );
      return RoomIntroAppearanceScope(
        shopData: snapshot.data,
        ready: snapshot.hasData,
        error:
            snapshot.error ??
            (snapshot.connectionState == ConnectionState.active &&
                    !snapshot.hasData
                ? '找不到店家'
                : null),
        appearance: RoomIntroAppearance.fromShop(snapshot.data),
        theme: theme,
        child: widget.child,
      );
    },
  );
}
