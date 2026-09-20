// 檔案名稱：lib/features/shop/pages/shop_room_type_page.dart
// 功能說明：舊房型管理入口，導向房型與房間整合畫面，並保留數字上限 Formatter。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_rooms_hub.dart';

class ShopRoomTypePage extends StatelessWidget {
  const ShopRoomTypePage({
    super.key,
    required this.shopId,
    this.embeddedInSetupCenter = false,
  });

  final String shopId;
  final bool embeddedInSetupCenter;

  @override
  Widget build(BuildContext context) {
    return ShopRoomTypeRoomsHub(
      shopId: shopId,
      embeddedInSetupCenter: embeddedInSetupCenter,
    );
  }
}

/// 限制最大數字 Formatter
class MaxValueInputFormatter extends TextInputFormatter {
  MaxValueInputFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final int? value = int.tryParse(newValue.text);

    if (value == null) {
      return oldValue;
    }

    if (value > max) {
      return oldValue;
    }

    return newValue;
  }
}
