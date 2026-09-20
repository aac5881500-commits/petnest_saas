// 檔案名稱：lib/features/shop/widgets/shop_room_type_live_preview.dart
// 功能說明：後台即時預覽容器，共用前台房型介紹內容，不寫入 Firestore。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_type_detail_content.dart';

class ShopRoomTypeDraft {
  const ShopRoomTypeDraft({
    required this.name,
    required this.description,
    required this.priceText,
    required this.capacityText,
    required this.extraPriceText,
    required this.totalRoomsText,
    required this.widthText,
    required this.depthText,
    required this.heightText,
    required this.featureKeys,
    required this.customFeatures,
    required this.existingImageUrls,
    required this.pendingImageBytes,
  });

  final String name;
  final String description;
  final String priceText;
  final String capacityText;
  final String extraPriceText;
  final String totalRoomsText;
  final String widthText;
  final String depthText;
  final String heightText;
  final List<String> featureKeys;
  final List<Map<String, String>> customFeatures;
  final List<String> existingImageUrls;
  final List<Uint8List> pendingImageBytes;

  int? get price => int.tryParse(priceText.trim());
  int? get capacity => int.tryParse(capacityText.trim());
  int? get extraPrice => int.tryParse(extraPriceText.trim());
  int? get width => int.tryParse(widthText.trim());
  int? get depth => int.tryParse(depthText.trim());
  int? get height => int.tryParse(heightText.trim());

  factory ShopRoomTypeDraft.fromRoomType(Map<String, dynamic> item) {
    final List<String> urls = SafeParse.parseList(item['images'])
        .map((dynamic e) => e.toString())
        .where((String url) => url.isNotEmpty)
        .toList();
    final List<String> keys = SafeParse.parseList(item['features'])
        .map((dynamic e) => e.toString())
        .where((String value) => value.isNotEmpty)
        .toList();
    final List<Map<String, String>> custom =
        SafeParse.parseMapList(item['customFeatures']).map((
          Map<String, dynamic> raw,
        ) {
          return <String, String>{
            'icon': SafeParse.parseString(raw['icon']),
            'name': SafeParse.parseString(raw['name']),
          };
        }).toList();
    String numText(Object? raw) {
      if (raw == null) {
        return '';
      }
      final int value = SafeParse.parseInt(raw);
      return value == 0 && (raw is String && raw.trim().isEmpty)
          ? ''
          : (raw.toString().trim().isEmpty ? '' : value.toString());
    }

    return ShopRoomTypeDraft(
      name: SafeParse.parseString(item['name']),
      description: SafeParse.parseString(item['description']),
      priceText: numText(item['price']),
      capacityText: numText(item['capacity']),
      extraPriceText: numText(item['extraPrice']),
      totalRoomsText: numText(item['totalRooms']),
      widthText: numText(item['width']),
      depthText: numText(item['depth']),
      heightText: numText(item['height']),
      featureKeys: keys,
      customFeatures: custom,
      existingImageUrls: urls,
      pendingImageBytes: const <Uint8List>[],
    );
  }

  Map<String, dynamic> toPreviewRoomType() {
    return <String, dynamic>{
      'name': name.trim().isEmpty ? '房型名稱' : name.trim(),
      'description': description,
      'price': price,
      'capacity': capacity,
      'extraPrice': extraPrice ?? 0,
      'width': width,
      'depth': depth,
      'height': height,
      'features': featureKeys,
      'customFeatures': customFeatures,
      'images': existingImageUrls,
    };
  }
}

class ShopRoomTypeLivePreview extends StatelessWidget {
  const ShopRoomTypeLivePreview({
    super.key,
    required this.draft,
    this.theme = HomeThemeModel.classicDefault,
    this.showFrameChrome = true,
  });

  final ShopRoomTypeDraft draft;
  final HomeThemeModel theme;
  final bool showFrameChrome;

  static const double readingWidth = 420;

  @override
  Widget build(BuildContext context) {
    final Widget phone = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: readingWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.cardBorderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: RoomTypeDetailContent(
              roomType: draft.toPreviewRoomType(),
              theme: theme,
              localImages: draft.pendingImageBytes,
              isIntroMode: true,
              previewOnly: true,
              showChrome: true,
            ),
          ),
        ),
      ),
    );
    if (!showFrameChrome) {
      return phone;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '顧客看到的房型介紹',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '即時預覽，儲存後才會套用',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: theme.textColor.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: phone),
      ],
    );
  }
}
