// 檔案名稱：lib/features/shop/widgets/room/room_type_detail_content.dart
// 功能說明：前台房型介紹內容區塊，供客戶頁、後台預覽與編輯預覽共用。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_feature_tags.dart';

class RoomTypeDetailContent extends StatefulWidget {
  const RoomTypeDetailContent({
    super.key,
    required this.roomType,
    required this.theme,
    this.localImages = const <Uint8List>[],
    this.isIntroMode = true,
    this.previewOnly = false,
    this.showChrome = false,
    this.startDate,
    this.endDate,
    this.onBook,
    this.onSelectOptions,
  });

  final Map<String, dynamic> roomType;
  final HomeThemeModel theme;
  final List<Uint8List> localImages;
  final bool isIntroMode;
  final bool previewOnly;
  final bool showChrome;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback? onBook;
  final VoidCallback? onSelectOptions;

  @override
  State<RoomTypeDetailContent> createState() => _RoomTypeDetailContentState();
}

class _RoomTypeDetailContentState extends State<RoomTypeDetailContent> {
  int _currentIndex = 0;

  int get _imageCount {
    final List<String> urls = _networkImages;
    return urls.length + widget.localImages.length;
  }

  List<String> get _networkImages {
    return SafeParse.parseList(widget.roomType['images'])
        .map((dynamic e) => e.toString())
        .where((String url) => url.isNotEmpty)
        .toList();
  }

  @override
  void didUpdateWidget(RoomTypeDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentIndex >= _imageCount) {
      _currentIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final HomeThemeModel theme = widget.theme;
    final String name = SafeParse.parseString(
      widget.roomType['name'],
      fallback: '房型介紹',
    );
    final Widget body = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildPhotos(theme),
          _buildInfo(theme),
          if (!widget.isIntroMode) _buildStayDates(theme),
          if (!widget.isIntroMode) _buildPriceQuote(theme),
          const SizedBox(height: 24),
        ],
      ),
    );

    if (!widget.showChrome) {
      return body;
    }

    return Column(
      children: <Widget>[
        Material(
          color: theme.backgroundColor,
          child: SizedBox(
            height: 52,
            child: Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: theme.textColor,
                  onPressed: () {},
                ),
                Expanded(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
        Expanded(child: body),
        RoomTypeDetailBookBar(
          theme: theme,
          isIntroMode: widget.isIntroMode,
          previewOnly: widget.previewOnly,
          onBook: widget.onBook,
          onSelectOptions: widget.onSelectOptions,
        ),
      ],
    );
  }

  Widget _buildPhotos(HomeThemeModel theme) {
    final int count = _imageCount;
    if (count == 0) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          height: 240,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.cardBorderColor),
          ),
          child: Center(
            child: Text(
              '尚無圖片',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.6)),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 260,
              width: double.infinity,
              child: _imageAt(_currentIndex, theme, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: count,
              itemBuilder: (BuildContext context, int index) {
                final bool selected = _currentIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() => _currentIndex = index);
                  },
                  child: Container(
                    width: 82,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? theme.primaryColor
                            : theme.cardBorderColor,
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _imageAt(index, theme, fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageAt(int index, HomeThemeModel theme, {required BoxFit fit}) {
    final List<String> urls = _networkImages;
    if (index < urls.length) {
      return Image.network(
        urls[index],
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
              return ColoredBox(
                color: theme.cardColor,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: theme.textColor.withValues(alpha: 0.5),
                ),
              );
            },
      );
    }
    final int localIndex = index - urls.length;
    if (localIndex >= 0 && localIndex < widget.localImages.length) {
      return Image.memory(
        widget.localImages[localIndex],
        fit: fit,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return ColoredBox(color: theme.cardColor);
  }

  Widget _buildInfo(HomeThemeModel theme) {
    final String name = SafeParse.parseString(
      widget.roomType['name'],
      fallback: '房型名稱',
    );
    final int? price = _optionalInt(widget.roomType['price']);
    final int? capacity = _optionalInt(widget.roomType['capacity']);
    final int extra = SafeParse.parseInt(widget.roomType['extraPrice']);
    final String description = SafeParse.parseString(
      widget.roomType['description'],
    );
    final List<String> features = <String>[
      ...SafeParse.parseList(
        widget.roomType['features'],
      ).map((dynamic e) => e.toString()),
      ...SafeParse.parseMapList(widget.roomType['customFeatures'])
          .map((Map<String, dynamic> e) {
            final String icon = SafeParse.parseString(e['icon']);
            final String label = SafeParse.parseString(e['name']);
            if (label.isEmpty) {
              return '';
            }
            return icon.isEmpty ? label : '$icon $label';
          })
          .where((String value) => value.isNotEmpty),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.cardBorderColor),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              price == null ? '尚未填寫每晚價格' : 'NT\$ $price / 晚',
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              capacity == null ? '尚未填寫容納寵物數' : '可住 $capacity 隻',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.65)),
            ),
            if (extra > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '每多一隻 +$extra 元',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (features.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              RoomFeatureTags(features: features, theme: theme),
            ],
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Icon(Icons.straighten, size: 16, color: theme.primaryColor),
                const SizedBox(width: 6),
                Text(
                  '房間尺寸',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.cardBorderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  _sizeItem('寬', widget.roomType['width'], theme),
                  _sizeItem('深', widget.roomType['depth'], theme),
                  _sizeItem('高', widget.roomType['height'], theme),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '房型介紹',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.cardBorderColor),
              ),
              child: Text(
                description.isEmpty ? '尚未填寫介紹' : description,
                style: TextStyle(
                  height: 1.5,
                  color: theme.textColor.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStayDates(HomeThemeModel theme) {
    final DateTime? start = widget.startDate;
    final DateTime? end = widget.endDate;
    if (start == null || end == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.cardBorderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _dateCol('入住時間', '${start.month}月${start.day}日', theme),
            _dateCol('退房時間', '${end.month}月${end.day}日', theme),
          ],
        ),
      ),
    );
  }

  Widget _dateCol(String label, String value, HomeThemeModel theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(color: theme.textColor.withValues(alpha: 0.68)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: theme.primaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceQuote(HomeThemeModel theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.cardBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '1晚房價',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.68)),
            ),
            const SizedBox(height: 4),
            Text(
              'TWD ${widget.roomType['price'] ?? ''}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '含稅費與其他費用',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.58)),
            ),
          ],
        ),
      ),
    );
  }

  int? _optionalInt(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is String && raw.trim().isEmpty) {
      return null;
    }
    return SafeParse.parseInt(raw);
  }

  Widget _sizeItem(String label, Object? value, HomeThemeModel theme) {
    final int? parsed = _optionalInt(value);
    return Column(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.textColor.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          parsed == null || parsed <= 0 ? '—' : '$parsed cm',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
      ],
    );
  }
}

class RoomTypeDetailBookBar extends StatelessWidget {
  const RoomTypeDetailBookBar({
    super.key,
    required this.theme,
    required this.isIntroMode,
    this.previewOnly = false,
    this.onBook,
    this.onSelectOptions,
  });

  final HomeThemeModel theme;
  final bool isIntroMode;
  final bool previewOnly;
  final VoidCallback? onBook;
  final VoidCallback? onSelectOptions;

  @override
  Widget build(BuildContext context) {
    final String label = isIntroMode ? '我要預約' : '查看您的選項';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.cardBorderColor)),
      ),
      child: ElevatedButton(
        onPressed: () {
          if (previewOnly) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('目前為後台預覽模式')));
            return;
          }
          if (isIntroMode) {
            onBook?.call();
          } else {
            onSelectOptions?.call();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
