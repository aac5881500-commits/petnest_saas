import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

/// 版型選擇卡上的迷你示意圖，只用 Widget 畫，不使用圖片。
class RoomSectionLayoutPreview extends StatelessWidget {
  const RoomSectionLayoutPreview({
    super.key,
    required this.layout,
    required this.theme,
  });

  final String layout;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.cardBorderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: switch (layout) {
            HomeRoomSectionLayouts.cardGrid => _cardGrid(),
            HomeRoomSectionLayouts.simpleEntry => _simple(),
            _ => _horizontal(),
          },
        ),
      ),
    );
  }

  Widget _block({double? width, double height = 18, bool wide = false}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: wide ? 0.28 : 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.cardBorderColor),
      ),
    );
  }

  Widget _horizontal() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double card = constraints.maxWidth * 0.42;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: 0,
            maxWidth: constraints.maxWidth * 1.5,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: card,
                  child: _block(height: double.infinity),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: card,
                  child: _block(height: double.infinity),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: card,
                  child: _block(height: double.infinity),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _simple() {
    return Row(
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.bed_outlined, size: 16, color: theme.primaryColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _block(width: 72, height: 8),
              const SizedBox(height: 6),
              _block(width: 108, height: 6),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: theme.primaryColor, size: 18),
      ],
    );
  }

  Widget _cardGrid() {
    return Column(
      children: <Widget>[
        Expanded(child: _block(height: double.infinity, wide: true)),
        const SizedBox(height: 6),
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(child: _block(height: double.infinity)),
              const SizedBox(width: 6),
              Expanded(child: _block(height: double.infinity)),
            ],
          ),
        ),
      ],
    );
  }
}
