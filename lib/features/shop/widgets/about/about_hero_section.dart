// 檔案名稱：lib/features/shop/widgets/about/about_hero_section.dart
// 功能說明：從 Firestore 讀取關於我們主標題、介紹文字與圖片
// 🐾 關於我們頁 Hero 大圖區塊
// 並依照首頁版本套用共用主題顏色

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/about_cover_frame_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_cover_backdrop.dart';

class AboutHeroSection extends StatelessWidget {
  const AboutHeroSection({
    super.key,
    required this.shopId,
    required this.theme,
    this.previewTitle,
    this.previewDescription,
    this.previewImageUrl,
    this.previewFrame,
  });

  final String shopId;
  final HomeThemeModel theme;
  final String? previewTitle;
  final String? previewDescription;
  final String? previewImageUrl;
  final AboutCoverFrameSetting? previewFrame;

  bool get _isDraftPreview =>
      previewTitle != null ||
      previewDescription != null ||
      previewImageUrl != null ||
      previewFrame != null;

  @override
  Widget build(BuildContext context) {
    if (_isDraftPreview) {
      return _buildHero(
        title: previewTitle ?? '',
        description: previewDescription ?? '',
        imageUrl: (previewImageUrl ?? '').trim(),
        frame: previewFrame ?? const AboutCoverFrameSetting(),
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> snapshot,
          ) {
            final Map<String, dynamic> shop =
                snapshot.data ?? <String, dynamic>{};

            final String title = (shop['aboutTitle'] ?? '用心照顧每一隻貓咪，讓牠們在這裡安心生活。')
                .toString();
            final String description =
                (shop['aboutDescription'] ??
                        '我們相信，每一隻貓咪都是家人。當您需要暫時離開時，'
                            '我們會像您一樣，用心陪伴與照顧。')
                    .toString();
            final String aboutImageUrl = (shop['aboutImageUrl'] ?? '')
                .toString()
                .trim();

            return _buildHero(
              title: title,
              description: description,
              imageUrl: aboutImageUrl,
              frame: AboutCoverFrameSetting.fromMap(shop),
            );
          },
    );
  }

  Widget _buildHero({
    required String title,
    required String description,
    required String imageUrl,
    required AboutCoverFrameSetting frame,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double height = frame.heightForWidth(constraints.maxWidth);
        final bool compact = height <= 240;
        final bool standard = height <= 330;

        return SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF2A1B12)),
              AboutCoverBackdrop(shopImageUrl: imageUrl, frame: frame),
              Container(
                padding: EdgeInsets.fromLTRB(
                  22,
                  compact ? 20 : (standard ? 36 : 48),
                  22,
                  compact ? 16 : 28,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xB82A1B12),
                      Color(0x572A1B12),
                      Color(0x002A1B12),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 20 : (standard ? 23 : 25),
                        height: 1.35,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 16),
                    Text(
                      description,
                      maxLines: compact ? 2 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 13 : 15,
                        height: 1.55,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 10),
                      Icon(Icons.pets, color: theme.primaryColor, size: 28),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
