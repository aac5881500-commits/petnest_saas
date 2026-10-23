// 功能：獨立房型比較，保留來源日期與既有詳細介紹路由，不參與選房或庫存。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import '../widgets/room/room_intro_comparison.dart';
import 'room_type_detail_page.dart';

class ShopRoomComparisonPage extends StatefulWidget {
  const ShopRoomComparisonPage({
    super.key,
    required this.shopId,
    required this.theme,
    this.initialId,
    required this.startDate,
    required this.endDate,
  });
  final String shopId;
  final HomeThemeModel theme;
  final String? initialId;
  final DateTime startDate, endDate;
  @override
  State<ShopRoomComparisonPage> createState() => _ShopRoomComparisonPageState();
}

class _ShopRoomComparisonPageState extends State<ShopRoomComparisonPage> {
  late final _rooms = ShopService.instance.streamRoomTypes(widget.shopId);
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: widget.theme.backgroundColor,
    appBar: AppBar(title: const Text('比較房型')),
    body: StreamBuilder<List<Map<String, dynamic>>>(
      stream: _rooms,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('房型暫時無法載入'));
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: RoomIntroComparison(
                rooms: snapshot.data!,
                theme: widget.theme,
                initialId: widget.initialId,
                onOpen: (room) => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => RoomTypeDetailPage(
                      shopId: widget.shopId,
                      roomType: room,
                      startDate: widget.startDate,
                      endDate: widget.endDate,
                      theme: widget.theme,
                      isIntroMode: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
