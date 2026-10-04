import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_quick_booking_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_entry_card.dart';

/// 新版首頁快速預約。正式前台與外觀預覽共用。
class ModernHomeQuickBookingSection extends StatelessWidget {
  const ModernHomeQuickBookingSection({
    super.key,
    required this.theme,
    required this.setting,
    required this.accommodationAvailable,
    required this.daycareAvailable,
    required this.preview,
    this.onOpenAutomatic,
    this.onOpenAccommodation,
    this.onOpenDaycare,
  });

  final HomeThemeModel theme;
  final HomeQuickBookingSectionSetting setting;
  final bool accommodationAvailable;
  final bool daycareAvailable;
  final bool preview;
  final VoidCallback? onOpenAutomatic;
  final VoidCallback? onOpenAccommodation;
  final VoidCallback? onOpenDaycare;

  bool get _stay => setting.showAccommodation && accommodationAvailable;

  bool get _daycare => setting.showDaycare && daycareAvailable;

  @override
  Widget build(BuildContext context) {
    if (!_stay && !_daycare) {
      if (!preview) {
        return const SizedBox.shrink();
      }
      return _shell(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            kHomeQuickBookingClosedMessage,
            key: const Key('home-quick-booking-closed'),
            style: TextStyle(color: theme.secondaryTextColor, height: 1.4),
          ),
        ),
      );
    }
    return switch (HomeQuickBookingLayouts.migrate(setting.layout)) {
      HomeQuickBookingLayouts.compactCard => _compact(),
      HomeQuickBookingLayouts.singleLine => _single(),
      _ => _split(),
    };
  }

  VoidCallback? _tap(VoidCallback? action) {
    if (preview) {
      return null;
    }
    return action;
  }

  Color get _fill {
    switch (HomeQuickBookingSurfaces.migrate(setting.surfaceStyle)) {
      case HomeQuickBookingSurfaces.translucent:
        return theme.cardColor.withValues(alpha: 0.85);
      case HomeQuickBookingSurfaces.transparent:
        return Colors.transparent;
      default:
        return theme.cardColor;
    }
  }

  CrossAxisAlignment get _crossAlign {
    return HomeQuickBookingTextAligns.migrate(setting.textAlign) ==
            HomeQuickBookingTextAligns.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
  }

  TextAlign get _textAlign {
    return HomeQuickBookingTextAligns.migrate(setting.textAlign) ==
            HomeQuickBookingTextAligns.center
        ? TextAlign.center
        : TextAlign.left;
  }

  Widget _shell({required Widget child, double? height}) {
    return Material(
      color: _fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.cardBorderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(width: double.infinity, height: height, child: child),
    );
  }

  Widget _compact() {
    return _shell(
      height: kModernHomeSmallCardHeight,
      child: InkWell(
        key: const Key('home-quick-booking-card'),
        onTap: _tap(onOpenAutomatic),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: <Widget>[
              if (setting.showIcon) ...<Widget>[
                Icon(
                  Icons.event_available_outlined,
                  color: theme.primaryColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: _crossAlign,
                  children: <Widget>[
                    Text(
                      setting.entryTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: _textAlign,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                    Text(
                      setting.entrySubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: _textAlign,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _single() {
    return _shell(
      height: kModernHomeWideCardHeight,
      child: InkWell(
        key: const Key('home-quick-booking-card'),
        onTap: _tap(onOpenAutomatic),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool showSubtitle = constraints.maxWidth >= 260;
              return Row(
                children: <Widget>[
                  if (setting.showIcon) ...<Widget>[
                    Icon(
                      Icons.calendar_month_outlined,
                      color: theme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: _crossAlign,
                      children: <Widget>[
                        Text(
                          setting.entryTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: _textAlign,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: theme.textColor,
                          ),
                        ),
                        if (showSubtitle)
                          Text(
                            setting.entrySubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: _textAlign,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.secondaryTextColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      setting.entryButton,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _split() {
    final List<_QuickDoor> doors = <_QuickDoor>[
      if (_stay)
        _QuickDoor(
          key: const Key('home-quick-booking-stay'),
          title: '住宿預約',
          icon: Icons.bed_outlined,
          onTap: _tap(onOpenAccommodation),
        ),
      if (_daycare)
        _QuickDoor(
          key: const Key('home-quick-booking-daycare'),
          title: '寵物安親',
          icon: Icons.wb_sunny_outlined,
          onTap: _tap(onOpenDaycare),
        ),
    ];
    return _shell(
      child: Padding(
        key: const Key('home-quick-booking-card'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: _crossAlign,
          children: <Widget>[
            Text(
              setting.entryTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: _textAlign,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              setting.entrySubtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: _textAlign,
              style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool stack =
                    doors.length > 1 && constraints.maxWidth < 280;
                if (doors.length == 1 || stack) {
                  return Column(
                    children: <Widget>[
                      for (
                        int index = 0;
                        index < doors.length;
                        index++
                      ) ...<Widget>[
                        if (index > 0) const SizedBox(height: 8),
                        _door(doors[index]),
                      ],
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(child: _door(doors[0])),
                    const SizedBox(width: 8),
                    Expanded(child: _door(doors[1])),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _door(_QuickDoor door) {
    return Material(
      color: theme.primaryColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.cardBorderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: door.key,
        onTap: door.onTap,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (setting.showIcon) ...<Widget>[
                  Icon(door.icon, size: 18, color: theme.primaryColor),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    door.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
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
}

class _QuickDoor {
  const _QuickDoor({
    required this.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final Key key;
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
}
