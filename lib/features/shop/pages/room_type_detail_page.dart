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
  Widget build(BuildContext context) {
    final String title = SafeParse.parseString(
      roomType['name'],
      fallback: '房型介紹',
    );
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w800, color: theme.textColor),
        ),
        centerTitle: true,
      ),
      body: RoomTypeDetailContent(
        roomType: roomType,
        theme: theme,
        isIntroMode: isIntroMode,
        startDate: startDate,
        endDate: endDate,
      ),
      bottomNavigationBar: RoomTypeDetailBookBar(
        theme: theme,
        isIntroMode: isIntroMode,
        onBook: () {
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
        },
        onSelectOptions: () {
          Navigator.pop(context, roomType);
        },
      ),
    );
  }
}
