import 'room_intro_features.dart';
import 'room_intro_surface.dart';
import 'room_detail_browser.dart';
import 'room_intro_facts.dart';
import 'package:petnest_saas/core/models/room_intro_appearance.dart';
import 'room_intro_appearance_scope.dart';
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
    this.appearance,
    this.related,
  });

  final Widget? related;
  final RoomDetailAppearance? appearance;
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
  RoomDetailAppearance get _appearance =>
      widget.appearance ??
      (widget.isIntroMode
          ? RoomIntroAppearanceScope.maybeOf(context)?.appearance.detail
          : null) ??
      const RoomDetailAppearance();

  int get _imageCount {
    final List<String> urls = _networkImages;
    return urls.length + widget.localImages.length;
  }

  List<String> get _networkImages {
    return roomPhotoUrls(widget.roomType['images']);
  }

  @override
  void didUpdateWidget(RoomTypeDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomType['id'] != widget.roomType['id'] ||
        _currentIndex >= _imageCount) {
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
    final Widget body = LayoutBuilder(
      builder: (context, constraints) {
        final side =
            _appearance.layout == 'sideBySide' && constraints.maxWidth >= 760;
        return SingleChildScrollView(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ([
                    'tabs',
                    'panel',
                    'anchors',
                    'lodging',
                  ].contains(_appearance.layout))
                    RoomDetailBrowser(
                      layout: _appearance.layout,
                      photo: _buildPhotos(theme),
                      basic: _buildBasic(theme),
                      sections: _moreSections(theme),
                      related: widget.related,
                    )
                  else if (side)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildPhotos(theme)),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildBasic(theme),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildPhotos(theme),
                    _buildBasic(theme),
                  ],
                  if (![
                    'tabs',
                    'panel',
                    'anchors',
                    'lodging',
                  ].contains(_appearance.layout))
                    _buildMore(theme),
                  if (![
                        'tabs',
                        'panel',
                        'anchors',
                        'lodging',
                      ].contains(_appearance.layout) &&
                      widget.related != null)
                    widget.related!,
                  if (!widget.isIntroMode) _buildStayDates(theme),
                  if (!widget.isIntroMode) _buildPriceQuote(theme),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!widget.showChrome) {
      return RoomIntroSurface(
        look: _appearance.look,
        theme: theme,
        child: _styled(body),
      );
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
        Expanded(
          child: RoomIntroSurface(
            look: _appearance.look,
            theme: theme,
            child: _styled(body),
          ),
        ),
        RoomTypeDetailBookBar(
          theme: theme,
          isIntroMode: widget.isIntroMode,
          previewOnly: widget.previewOnly,
          basePrice: widget.isIntroMode
              ? RoomIntroFacts(widget.roomType).price
              : null,
          onBook: widget.onBook,
          onSelectOptions: widget.onSelectOptions,
        ),
      ],
    );
  }

  Widget _styled(Widget child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(
        MediaQuery.textScalerOf(context).scale(1) * _appearance.look.scale,
      ),
    ),
    child: child,
  );
  Widget _buildPhotos(HomeThemeModel theme) {
    final count = _imageCount;
    final fit = _appearance.imageFit == 'contain'
        ? BoxFit.contain
        : BoxFit.cover;
    final main = ClipRRect(
      borderRadius: BorderRadius.circular(_appearance.cornerRadius),
      child: LayoutBuilder(
        builder: (context, c) => AspectRatio(
          aspectRatio: roomImageRatio(
            _appearance.imageAspect,
          ).clamp(c.maxWidth / 340, double.infinity),
          child: count == 0
              ? ColoredBox(
                  color: theme.cardColor,
                  child: const Center(child: Text('尚無圖片')),
                )
              : GestureDetector(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => Dialog(
                      child: SizedBox(
                        width: 900,
                        height: MediaQuery.sizeOf(context).height * .8,
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                tooltip: '關閉大圖',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                            Expanded(
                              child: InteractiveViewer(
                                child: _imageAt(
                                  _currentIndex,
                                  theme,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  onHorizontalDragEnd: (details) {
                    if (count > 1 &&
                        (details.primaryVelocity ?? 0).abs() > 80) {
                      setState(
                        () => _currentIndex =
                            (_currentIndex +
                                ((details.primaryVelocity ?? 0) < 0 ? 1 : -1) +
                                count) %
                            count,
                      );
                    }
                  },
                  child: _imageAt(_currentIndex, theme, fit: fit),
                ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          main,
          if (count > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '上一張照片',
                  onPressed: () => setState(
                    () => _currentIndex = (_currentIndex - 1 + count) % count,
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${_currentIndex + 1} / $count'),
                IconButton(
                  tooltip: '下一張照片',
                  onPressed: () => setState(
                    () => _currentIndex = (_currentIndex + 1) % count,
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          if (_appearance.showThumbnails && count > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: count,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => setState(() => _currentIndex = index),
                  child: Container(
                    width: 82,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _currentIndex == index
                            ? theme.primaryColor
                            : theme.cardBorderColor,
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _imageAt(index, theme, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ],
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

  Widget _section(HomeThemeModel theme, Widget child) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      0,
      16,
      roomSectionGap(_appearance.spacing),
    ),
    child: Container(
      padding: EdgeInsets.all(
        _appearance.layout == 'compact' ? 12 : _appearance.look.padding + 4,
      ),
      decoration: BoxDecoration(
        color: _appearance.surface == 'transparent'
            ? Colors.transparent
            : _appearance.surface == 'pale'
            ? theme.primaryColor.withValues(alpha: .06)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(_appearance.cornerRadius),
        border: _appearance.look.border
            ? Border.all(color: theme.cardBorderColor)
            : null,
        boxShadow: _appearance.look.shadow
            ? [
                const BoxShadow(
                  color: Color(0x15000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: child,
    ),
  );

  Widget _buildBasic(HomeThemeModel theme) {
    final name = SafeParse.parseString(
      widget.roomType['name'],
      fallback: '房型名稱',
    );
    final price = RoomIntroFacts.number(widget.roomType['price']);
    final capacity = RoomIntroFacts.number(
      widget.roomType['capacity'],
      positive: true,
    );
    final extra = RoomIntroFacts.number(widget.roomType['extraPrice']) ?? 0;
    final info = [
      Text(
        price == null ? '尚未填寫每晚價格' : 'NT\$ $price / 晚',
        style: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      Text(
        capacity == null ? '尚未填寫容納寵物數' : '可住 $capacity 隻',
        style: TextStyle(color: theme.secondaryTextColor),
      ),
      if (extra > 0)
        Text(
          '每多一隻 +$extra 元',
          style: TextStyle(
            color: theme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
    ];
    return _section(
      theme,
      Column(
        crossAxisAlignment: _appearance.look.align == 'center'
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          if (_appearance.layout == 'compact')
            Wrap(spacing: 16, runSpacing: 8, children: info)
          else ...[
            for (final item in info)
              Padding(padding: const EdgeInsets.only(bottom: 4), child: item),
          ],
        ],
      ),
    );
  }

  Map<String, Widget> _moreSections(HomeThemeModel theme) {
    final description = SafeParse.parseString(
      widget.roomType['description'],
    ).trim();
    final features = RoomIntroFacts(widget.roomType).featureKeys;
    final dims = <String, Object>{
      for (final pair in {
        '寬': widget.roomType['width'],
        '深': widget.roomType['depth'],
        '高': widget.roomType['height'],
      }.entries)
        if (_dimension(pair.value) != null) pair.key: pair.value as Object,
    };
    Widget section(String title, Widget content) => _section(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          SizedBox(height: roomSectionGap(_appearance.spacing)),
          content,
        ],
      ),
    );
    final parts = <Widget>[
      if (description.isNotEmpty)
        section(
          '房型介紹',
          Text(
            description,
            textAlign: _appearance.look.align == 'center'
                ? TextAlign.center
                : TextAlign.start,
            style: TextStyle(height: 1.5, color: theme.textColor),
          ),
        ),
      if (features.isNotEmpty)
        section(
          '設備與特色',
          widget.isIntroMode
              ? RoomIntroFeatures(room: widget.roomType, theme: theme)
              : RoomFeatureTags(features: features, theme: theme),
        ),
    ];
    return {
      if (_appearance.look.showDimensions && dims.isNotEmpty)
        '房間尺寸': section(
          '房間尺寸',
          _appearance.dimensionsStyle == 'line'
              ? Text(
                  dims.entries.map((e) => '${e.key} ${e.value} cm').join('　'),
                  style: TextStyle(color: theme.textColor),
                )
              : Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    for (final e in dims.entries)
                      _sizeItem(e.key, e.value, theme),
                  ],
                ),
        ),
      if (description.isNotEmpty &&
          features.isNotEmpty &&
          _appearance.contentOrder == 'featuresFirst') ...{
        '設備與特色': parts.last,
        '房型介紹': parts.first,
      } else ...{
        if (description.isNotEmpty) '房型介紹': parts.first,
        if (features.isNotEmpty) '設備與特色': parts.last,
      },
    };
  }

  Widget _buildMore(HomeThemeModel theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: _moreSections(theme).values.toList(),
  );

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

  Widget _sizeItem(String label, Object? value, HomeThemeModel theme) {
    final num? parsed = _dimension(value);
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

  num? _dimension(Object? value) {
    return RoomIntroFacts.number(value, positive: true);
  }
}

class RoomTypeDetailBookBar extends StatelessWidget {
  const RoomTypeDetailBookBar({
    super.key,
    required this.theme,
    required this.isIntroMode,
    this.previewOnly = false,
    this.onBook,
    this.basePrice,
    this.onSelectOptions,
  });

  final String? basePrice;
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
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (basePrice != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '基本價格：$basePrice',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () {
                      if (previewOnly) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('目前為後台預覽模式')),
                        );
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
