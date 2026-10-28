import '../widgets/room/room_intro_data_stream.dart';
import '../widgets/room/room_intro_typography.dart';
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
    this.roomTypesStream,
    this.shopStream,
  });
  final Stream<List<Map<String, dynamic>>>? roomTypesStream;
  final Stream<Map<String, dynamic>?>? shopStream;
  final String shopId;
  final HomeThemeModel theme;
  @override
  State<ShopRoomIntroPage> createState() => _ShopRoomIntroPageState();
}

class _ShopRoomIntroPageState extends State<ShopRoomIntroPage> {
  late Stream<List<Map<String, dynamic>>> _types;
  int _attempt = 0;
  void _bind() => _types = roomIntroInitialLoad(
    widget.roomTypesStream ??
        ShopService.instance.streamRoomTypes(widget.shopId),
  );
  void _retry() => setState(() {
    _attempt++;
    _bind();
  });
  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant ShopRoomIntroPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId ||
        oldWidget.roomTypesStream != widget.roomTypesStream) {
      _bind();
    }
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
    key: ValueKey((widget.shopId, _attempt)),
    shopId: widget.shopId,
    shopStream: widget.shopStream,
    child: Builder(
      builder: (context) {
        final scope = RoomIntroAppearanceScope.maybeOf(context)!;
        return RoomIntroTypography(
          look: scope.appearance.list.look,
          child: Scaffold(
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
                  final error = snapshot.error ?? scope.error;
                  debugPrint(
                    'Room intro load failed (${widget.shopId}): $error',
                  );
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined),
                          const SizedBox(height: 12),
                          const Text(
                            '房型介紹暫時無法載入，請確認網路與店家存取狀態。',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('重新載入'),
                          ),
                        ],
                      ),
                    ),
                  );
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
                            endDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    ),
  );
}
