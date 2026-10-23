import '../widgets/room/room_intro_surface.dart';
import 'shop_room_comparison_page.dart';
// 檔案名稱：lib/features/shop/pages/shop_room_intro_page.dart
// 功能說明：前台房間介紹頁
// 顯示店家的房型介紹，讀取 Firestore 房型資料，點擊可進房型詳細頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/room_type_detail_page.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_appearance_scope.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_list.dart';

class ShopRoomIntroPage extends StatefulWidget {
  const ShopRoomIntroPage({
    super.key,
    required this.shopId,
    required this.theme,
  });
  final String shopId;
  final HomeThemeModel theme;
  @override
  State<ShopRoomIntroPage> createState() => _ShopRoomIntroPageState();
}

class _ShopRoomIntroPageState extends State<ShopRoomIntroPage> {
  late Stream<List<Map<String, dynamic>>> _types;
  void _bind() => _types = ShopService.instance.streamRoomTypes(widget.shopId);
  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant ShopRoomIntroPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) _bind();
  }

  void _open(Map<String, dynamic> room) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RoomTypeDetailPage(
        shopId: widget.shopId,
        roomType: room,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        theme: widget.theme,
        isIntroMode: true,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => RoomIntroAppearanceHost(
    shopId: widget.shopId,
    child: Builder(
      builder: (context) {
        final scope = RoomIntroAppearanceScope.maybeOf(context)!;
        return Scaffold(
          backgroundColor: widget.theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: widget.theme.backgroundColor,
            foregroundColor: widget.theme.textColor,
            title: Text(scope.appearance.list.title),
            centerTitle: true,
          ),
          body: StreamBuilder<List<Map<String, dynamic>>>(
            key: ValueKey(widget.shopId),
            stream: _types,
            builder: (context, snapshot) {
              if (snapshot.hasError || scope.error != null) {
                return const Center(child: Text('房型介紹暫時無法載入，請稍後再試。'));
              }
              if (!scope.ready ||
                  snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return RoomIntroSurface(
                look: scope.appearance.list.look,
                theme: widget.theme,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: RoomIntroList(
                    rooms: snapshot.data ?? const [],
                    setting: scope.appearance.list,
                    showComparison: scope.appearance.showComparison,
                    theme: widget.theme,
                    onOpen: _open,
                    onCompare: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ShopRoomComparisonPage(
                          shopId: widget.shopId,
                          theme: widget.theme,
                          startDate: DateTime.now(),
                          endDate: DateTime.now().add(const Duration(days: 1)),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
