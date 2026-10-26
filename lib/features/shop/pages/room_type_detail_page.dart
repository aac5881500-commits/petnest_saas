import '../widgets/room/room_intro_typography.dart';
import 'package:petnest_saas/core/models/room_intro_look.dart';
import '../widgets/room/room_intro_facts.dart';
import '../widgets/room/room_intro_related.dart';
import 'shop_room_comparison_page.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_appearance_scope.dart';
// 檔案名稱：lib/features/shop/pages/room_type_detail_page.dart
// 功能說明：前台房型詳細頁，內容區塊與後台預覽共用。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_page.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_type_detail_content.dart';

class RoomTypeDetailPage extends StatelessWidget {
  const RoomTypeDetailPage({
    super.key,
    required this.shopId,
    required this.roomType,
    required this.startDate,
    required this.endDate,
    required this.theme,
    this.isIntroMode = false,
  });

  final String shopId;
  final Map<String, dynamic> roomType;
  final DateTime startDate;
  final DateTime endDate;
  final HomeThemeModel theme;
  final bool isIntroMode;

  @override
  Widget build(BuildContext context) => isIntroMode
      ? RoomIntroAppearanceHost(
          shopId: shopId,
          child: Builder(builder: _page),
        )
      : _page(context);

  Widget _page(BuildContext context) {
    final look = isIntroMode
        ? RoomIntroAppearanceScope.maybeOf(context)?.appearance.detail.look ??
              const RoomIntroLook()
        : const RoomIntroLook();
    final String title = SafeParse.parseString(
      roomType['name'],
      fallback: '房型介紹',
    );
    return RoomIntroTypography(
      look: look,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        appBar: AppBar(
          backgroundColor: theme.backgroundColor,
          foregroundColor: theme.textColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
          centerTitle: true,
        ),
        body: _detailBody(context),
        bottomNavigationBar: RoomTypeDetailBookBar(
          theme: theme,
          isIntroMode: isIntroMode,
          basePrice: isIntroMode ? RoomIntroFacts(roomType).price : null,
          onBook: _openBooking(context),
          onSelectOptions: () => Navigator.pop(context, roomType),
        ),
      ),
    );
  }

  Widget _detailBody(BuildContext context) => RoomTypeDetailContent(
    roomType: roomType,
    theme: theme,
    isIntroMode: isIntroMode,
    related: isIntroMode
        ? RoomIntroRelated(
            shopId: shopId,
            theme: theme,
            compare: Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.compare_arrows),
                label: const Text('比較房型'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ShopRoomComparisonPage(
                      shopId: shopId,
                      theme: theme,
                      initialId: roomType['id']?.toString(),
                      startDate: startDate,
                      endDate: endDate,
                    ),
                  ),
                ),
              ),
            ),
          )
        : null,
    startDate: startDate,
    endDate: endDate,
  );

  VoidCallback _openBooking(BuildContext context) => () {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ShopBookingPage(
          shopId: shopId,
          theme: theme,
          useModernDrawer: theme != HomeThemeModel.classicDefault,
        ),
      ),
    );
  };
}
