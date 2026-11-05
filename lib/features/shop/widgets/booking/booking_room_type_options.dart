import 'booking_editorial_design.dart';
import 'booking_appearance_scope.dart';
import 'booking_service_templates.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

/// Displays every room type; capacity and date availability control selection.
class BookingRoomTypeOptions extends StatelessWidget {
  const BookingRoomTypeOptions({
    super.key,
    required this.roomTypes,
    required this.petCount,
    required this.theme,
    required this.onSelect,
    this.selectedRoomTypeId,
    this.onAdjustSelection,
  });
  final List<Map<String, dynamic>> roomTypes;
  final int petCount;
  final HomeThemeModel theme;
  final String? selectedRoomTypeId;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final VoidCallback? onAdjustSelection;
  int _number(Object? value, [int fallback = 0]) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? fallback;
  int _capacity(Map<String, dynamic> type) => _number(type['capacity'], 1);

  List<Map<String, dynamic>> get _displayTypes {
    final fitting = roomTypes
        .where((type) => _capacity(type) >= petCount)
        .toList();
    return fitting.isEmpty ? roomTypes : fitting;
  }

  Widget _notice(String title, String message) => Container(
    key: const ValueKey('booking-room-notice'),
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1E8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE6AC80)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: Color(0xFF995020),
          size: 28,
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF793E1B),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: Color(0xFF793E1B),
          ),
        ),
        if (onAdjustSelection != null) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAdjustSelection,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('返回調整日期／貓咪'),
          ),
        ],
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final style = BookingAppearanceScope.of(context).serviceStyle;
    var maxCapacity = 0;
    for (final type in roomTypes) {
      if (_capacity(type) > maxCapacity) maxCapacity = _capacity(type);
    }
    final fits = roomTypes
        .where((type) => _capacity(type) >= petCount)
        .toList();
    final available = fits.any((type) => _number(type['availableRooms']) > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (style != 'original')
          BookingServiceTemplates.header(
            style,
            theme,
            style == 'premium' ? '為牠安排舒適住宿' : '選擇房型',
            '目前入住 $petCount 隻貓咪，請選擇合適房型',
            '01',
          ),
        if (style == 'original')
          Text(
            '選擇房型',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
        if (style != 'editorial' && style != 'cream') const SizedBox(height: 8),
        if (style != 'editorial' && style != 'cream')
          Text(
            '目前選擇 $petCount 隻貓咪。優先顯示容量符合的房型，已滿房的仍會標示。',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: theme.textColor.withValues(alpha: .8),
            ),
          ),
        const SizedBox(height: 16),
        if (roomTypes.isEmpty)
          _notice('目前尚無可預約房型', '請聯繫店家確認房型開放情況。選好房型後，才能繼續確認預約。')
        else if (fits.isEmpty)
          _notice(
            '目前選擇 $petCount 隻，超過所有房型容量',
            '本店房型最多可入住 $maxCapacity 隻。目前每筆預約可選一個房型，請返回上一步調整入住貓咪；如需分房安排，請先聯繫店家。',
          )
        else if (!available)
          _notice(
            '符合 $petCount 隻入住的房型，在所選日期已滿',
            '房型仍顯示於下方供參考，請返回上一步更換住宿日期，或聯繫店家確認其他安排。',
          ),
        if (style == 'original') ...[
          for (final type in _displayTypes) _card(context, type),
        ] else if (style == 'editorial' || style == 'cream') ...[
          if (_displayTypes.isNotEmpty)
            _templateCard(
              context,
              _displayTypes[_featuredIndex],
              style,
              featured: true,
            ),
          for (var index = 0; index < _displayTypes.length; index++)
            if (index != _featuredIndex)
              _templateCard(context, _displayTypes[index], style),
        ] else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 340 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 21
                  ? 2
                  : 1;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final type in _displayTypes)
                    SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 12) / columns,
                      child: _templateCard(context, type, style),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  int get _featuredIndex {
    final selected = _displayTypes.indexWhere(
      (type) => type['roomTypeId'] == selectedRoomTypeId,
    );
    if (selected >= 0) return selected;
    final available = _displayTypes.indexWhere(
      (type) =>
          _capacity(type) >= petCount && _number(type['availableRooms']) > 0,
    );
    return available >= 0 ? available : 0;
  }

  Widget _photo(Map<String, dynamic> type) {
    final raw = type['images'];
    final url = raw is List && raw.isNotEmpty ? raw.first.toString() : '';
    final fallback = ColoredBox(
      color: theme.primaryColor.withValues(alpha: .08),
      child: Center(
        child: Icon(Icons.bed_outlined, color: theme.primaryColor, size: 40),
      ),
    );
    if (type['_previewAtlas'] == true) {
      return ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 512,
              height: 512,
              child: ClipRect(
                child: OverflowBox(
                  maxWidth: 1536,
                  maxHeight: 1024,
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(
                    'assets/images/home_warm_photo_atlas_v1.png',
                    width: 1536,
                    height: 1024,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return url.isEmpty
        ? fallback
        : Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stack) => fallback,
          );
  }

  Widget _templateCard(
    BuildContext context,
    Map<String, dynamic> type,
    String style, {
    bool featured = false,
  }) {
    final capacity = _capacity(type),
        remaining = _number(type['availableRooms']);
    final fits = capacity >= petCount,
        enabled = capacity >= petCount && remaining > 0;
    final selected = enabled && selectedRoomTypeId == type['roomTypeId'];
    final price =
        _number(type['price']) +
        (fits && petCount > 1
            ? (petCount - 1) * _number(type['extraPrice'])
            : 0);
    final status = !fits
        ? '最多 $capacity 隻 · 超過容量'
        : remaining <= 0
        ? '所選日期已滿房'
        : '可入住 · 剩 $remaining 間';
    if (style == 'editorial') {
      final name = type['name']?.toString() ?? '';
      final caption = Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 5,
          children: [
            Text(
              name,
              style: BookingEditorial.title(
                19,
                context,
              ).copyWith(color: Colors.white),
            ),
            Text(
              'NT\$ $price／晚',
              style: BookingEditorial.body(
                15,
                context,
              ).copyWith(color: Colors.white),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.white, size: 21),
          ],
        ),
      );
      return Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        child: GestureDetector(
          key: ValueKey('booking-room-${type['roomTypeId']}'),
          onTap: enabled ? () => onSelect(type) : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: BookingEditorial.theme(context).backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? BookingEditorial.theme(context).primaryColor
                    : BookingEditorial.theme(context).cardBorderColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: featured
                ? Stack(
                    children: [
                      AspectRatio(aspectRatio: 1.65, child: _photo(type)),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ColoredBox(
                          color: BookingEditorial.theme(
                            context,
                          ).primaryColor.withValues(alpha: .85),
                          child: caption,
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(5),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: SizedBox(
                            width: 100,
                            height: 78,
                            child: _photo(type),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: BookingEditorial.title(18, context),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'NT\$ $price／晚',
                                style: BookingEditorial.body(14, context),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: enabled
                                  ? BookingEditorial.tint(context)
                                  : const Color(0xFFD8D4CB),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              !fits
                                  ? '超過容量'
                                  : enabled
                                  ? '可入住'
                                  : '已滿房',
                              style: BookingEditorial.body(13, context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      );
    }

    if (style == 'cream') {
      final t = BookingEditorial.theme(context);
      final details = Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 10,
              runSpacing: 5,
              children: [
                Text(
                  type['name']?.toString() ?? '',
                  style: BookingEditorial.title(20, context),
                ),
                Icon(
                  selected
                      ? Icons.check_circle
                      : enabled
                      ? Icons.radio_button_unchecked
                      : Icons.lock_outline,
                  color: t.primaryColor,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('NT\$ $price／晚', style: BookingEditorial.title(19, context)),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 5,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: enabled
                        ? t.primaryColor.withValues(alpha: .12)
                        : Colors.grey.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    selected
                        ? '已選擇'
                        : !fits
                        ? '超過容量'
                        : remaining <= 0
                        ? '已滿房'
                        : '可入住',
                    style: BookingEditorial.body(13, context),
                  ),
                ),
                Text(
                  '最多 $capacity 隻',
                  style: BookingEditorial.body(13, context),
                ),
              ],
            ),
          ],
        ),
      );
      return Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        child: GestureDetector(
          key: ValueKey('booking-room-${type['roomTypeId']}'),
          onTap: enabled ? () => onSelect(type) : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: selected ? BookingEditorial.tint(context) : t.cardColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: selected ? t.primaryColor : t.cardBorderColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: featured
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(aspectRatio: 2, child: _photo(type)),
                      details,
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, c) => c.maxWidth < 300
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AspectRatio(
                                aspectRatio: 2.5,
                                child: _photo(type),
                              ),
                              details,
                            ],
                          )
                        : Row(
                            children: [
                              SizedBox(
                                width: 108,
                                height: 140,
                                child: _photo(type),
                              ),
                              Expanded(child: details),
                            ],
                          ),
                  ),
          ),
        ),
      );
    }
    final details = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  type['name']?.toString() ?? '',
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                enabled
                    ? selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked
                    : Icons.lock_outline,
                size: 20,
                color: theme.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'NT\$ $price／晚',
            style: TextStyle(
              fontSize: 17,
              color: theme.primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: TextStyle(
              color: enabled ? theme.textColor : const Color(0xFF9A472A),
              height: 1.4,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
    final body = style == 'editorial' && !featured
        ? Row(
            children: [
              SizedBox(width: 82, height: 96, child: _photo(type)),
              Expanded(child: details),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (style != 'journal')
                AspectRatio(
                  aspectRatio: featured ? 2.4 : 1.5,
                  child: _photo(type),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Icon(
                    Icons.home_outlined,
                    color: theme.primaryColor,
                    size: 32,
                  ),
                ),
              details,
            ],
          );
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      child: GestureDetector(
        key: ValueKey('booking-room-${type['roomTypeId']}'),
        onTap: enabled ? () => onSelect(type) : null,
        child: Container(
          margin: EdgeInsets.only(bottom: style == 'editorial' ? 12 : 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: selected
                ? theme.primaryColor.withValues(alpha: .07)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(style == 'premium' ? 6 : 18),
            border: Border.all(
              color: selected ? theme.primaryColor : theme.cardBorderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> type) {
    final capacity = _capacity(type);
    final overCapacity = petCount > capacity;
    final remaining = _number(type['availableRooms']);
    final full = remaining <= 0;
    final enabled = !overCapacity && !full;
    final selected =
        enabled && selectedRoomTypeId == type['roomTypeId']?.toString();
    final basePrice = _number(type['price']);
    final extraPrice = _number(type['extraPrice']);
    final extraCount = petCount > 1 ? petCount - 1 : 0;
    final nightlyPrice = basePrice + extraCount * extraPrice;
    final status = overCapacity
        ? '超過容量，無法入住'
        : full
        ? '所選日期已滿房'
        : '可入住 · 剩 $remaining 間';
    final statusColor = enabled ? theme.primaryColor : const Color(0xFF9A472A);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      child: GestureDetector(
        key: ValueKey('booking-room-${type['roomTypeId']}'),
        onTap: enabled ? () => onSelect(type) : null,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? theme.primaryColor.withValues(alpha: .07)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? theme.primaryColor : theme.cardBorderColor,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      type['name']?.toString() ?? '未命名房型',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    enabled
                        ? (selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked)
                        : Icons.lock_outline,
                    size: 22,
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '最多 $capacity 隻 · 已選 $petCount 隻',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: theme.textColor.withValues(alpha: .8),
                    ),
                  ),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'NT\$ ${overCapacity ? basePrice : nightlyPrice}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryColor,
                    ),
                  ),
                  Text(
                    overCapacity ? '基本房價／晚' : '每晚',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textColor.withValues(alpha: .75),
                    ),
                  ),
                ],
              ),
              if (!overCapacity && extraCount > 0 && extraPrice > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '基本 NT\$ $basePrice ＋ $extraCount 隻 × NT\$ $extraPrice',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: theme.textColor.withValues(alpha: .75),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
