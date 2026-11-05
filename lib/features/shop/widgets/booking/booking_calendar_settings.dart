import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/shared/widgets/booking_calendar.dart';
import 'booking_calendar_dialog.dart';
import 'front_calendar_payload.dart';

/// Uses the customer calendar itself so selections match the saved settings.
class BookingCalendarSettings extends StatefulWidget {
  const BookingCalendarSettings({
    super.key,
    required this.appearance,
    required this.enabled,
    required this.onStyle,
    required this.onPresentation,
    required this.onDensity,
    required this.pageTheme,
    required this.onColors,
  });
  final BookingPageAppearance appearance;
  final HomeThemeModel pageTheme;
  final void Function(String, int, int) onColors;
  final bool enabled;
  final ValueChanged<String> onStyle, onPresentation, onDensity;
  @override
  State<BookingCalendarSettings> createState() =>
      _BookingCalendarSettingsState();
}

class _BookingCalendarSettingsState extends State<BookingCalendarSettings> {
  late final DateTime today = DateUtils.dateOnly(DateTime.now());
  late DateTime month = DateTime(today.year, today.month);
  DateTime? start, end;
  String? _category;
  Color? get background =>
      widget.appearance.calendarBackgroundFor(widget.pageTheme) == null
      ? null
      : Color(widget.appearance.calendarBackgroundFor(widget.pageTheme)!);
  Color? get accent =>
      widget.appearance.calendarAccentFor(widget.pageTheme) == null
      ? null
      : Color(widget.appearance.calendarAccentFor(widget.pageTheme)!);
  Future<void> editColor(bool isBackground) async {
    final value = isBackground
        ? widget.appearance.calendarBackground
        : widget.appearance.calendarAccent;
    final controller = TextEditingController(
      text: value.toRadixString(16).substring(2).toUpperCase(),
    );
    String? error;
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, change) => AlertDialog(
          title: Text(isBackground ? '自訂月曆底色' : '自訂重點色'),
          content: TextField(
            controller: controller,
            maxLength: 7,
            decoration: InputDecoration(
              labelText: 'HEX 色碼',
              hintText: '#34786B',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final hex = controller.text.trim().replaceFirst('#', '');
                if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
                  change(() => error = '請輸入六位 HEX 色碼');
                  return;
                }
                Navigator.pop(context, int.parse('FF$hex', radix: 16));
              },
              child: const Text('套用'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result != null && mounted) {
      widget.onColors(
        'custom',
        isBackground ? result : widget.appearance.calendarBackground,
        isBackground ? widget.appearance.calendarAccent : result,
      );
    }
  }

  void select(DateTime day) => setState(() {
    if (start == null || end != null || !day.isAfter(start!)) {
      start = day;
      end = null;
    } else {
      end = day;
    }
  });
  Future<void> trial() async {
    final a = widget.appearance;
    var trialMonth = month;
    DateTime? trialStart = start, trialEnd = end;
    final result = await showBookingCalendarSurface<DateTimeRange>(
      context: context,
      presentation: a.calendarPresentation,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, change) => BookingCalendarDialog(
          payload: const FrontCalendarPayload(
            blockedDateKeys: {},
            blockedDateReasons: {},
            unbookableDateKeys: {},
            priceMap: {},
            remainingRoomsMap: {},
          ),
          calendarMonth: trialMonth,
          today: today,
          maxDays: 90,
          tempStartDate: trialStart,
          tempEndDate: trialEnd,
          rangeMessage: '示範操作，不會建立預約',
          visualStyle: a.calendarStyle,
          backgroundColor: background,
          accentColor: accent,
          presentation: a.calendarPresentation,
          density: a.calendarDensity,
          onMonthChanged: (v) => change(() => trialMonth = v),
          onDayTap: (v) => change(() {
            if (trialStart == null ||
                trialEnd != null ||
                !v.isAfter(trialStart!)) {
              trialStart = v;
              trialEnd = null;
            } else {
              trialEnd = v;
            }
          }),
          onCancel: () => Navigator.pop(dialogContext),
          onConfirm: trialStart != null && trialEnd != null
              ? () => Navigator.pop(
                  dialogContext,
                  DateTimeRange(start: trialStart!, end: trialEnd!),
                )
              : null,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        start = result.start;
        end = result.end;
      });
    }
  }

  Widget choices(
    String title,
    Map<String, String> values,
    String selected,
    ValueChanged<String> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in values.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: selected == e.key,
              onSelected: widget.enabled ? (_) => change(e.key) : null,
            ),
        ],
      ),
      const SizedBox(height: 20),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final a = widget.appearance;
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('月曆設定', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('選擇整套日期介面：版面、資訊排列與操作方式一起切換。'),
        const SizedBox(height: 20),
        choices(
          '瀏覽分類',
          const {'month': '整月', 'week': '週／分組'},
          _category ??
              (BookingPageAppearance.monthCalendarStyles.contains(
                    a.calendarStyle,
                  )
                  ? 'month'
                  : 'week'),
          (value) => setState(() => _category = value),
        ),
        Text(
          '目前使用：${BookingPageAppearance.calendarStyles[a.calendarStyle]}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final category =
                _category ??
                (BookingPageAppearance.monthCalendarStyles.contains(
                      a.calendarStyle,
                    )
                    ? 'month'
                    : 'week');
            final cards = <Widget>[
              for (final entry
                  in const {
                    'weekbands': (
                      '整月週次表',
                      '整月展開・逐週分列',
                      Icons.table_rows_outlined,
                      Color(0xFFEFF5F3),
                    ),
                    'monthlist': (
                      '整月日期索引',
                      '上／下半月・日期索引',
                      Icons.vertical_split_outlined,
                      Color(0xFFF4F0FA),
                    ),
                    'monthwall': (
                      '整月卡片牆',
                      '全月日期・卡片排列',
                      Icons.grid_view_outlined,
                      Color(0xFFFFF3E6),
                    ),
                    'classic': (
                      '經典月曆',
                      '完整月份・傳統格狀',
                      Icons.calendar_month,
                      Color(0xFFEAF0FA),
                    ),
                    'stay': (
                      '旅宿日期卡',
                      '步驟提示・大日期摘要',
                      Icons.hotel_outlined,
                      Color(0xFFF5EFE6),
                    ),
                    'week': (
                      '週曆時間軸',
                      '橫向日期卡・旅程票卡',
                      Icons.view_week_outlined,
                      Color(0xFFECF4F3),
                    ),
                    'board': (
                      '週末旅行板',
                      '雙欄卡片・每週安排',
                      Icons.dashboard_outlined,
                      Color(0xFFF0F7F2),
                    ),
                    'ribbon': (
                      '旅程長票',
                      '整月滑軌・住宿通行證',
                      Icons.confirmation_number_outlined,
                      Color(0xFFFFF3E6),
                    ),
                    'journal': (
                      '日程清單',
                      '直向日期列・每日狀態',
                      Icons.view_agenda_outlined,
                      Color(0xFFF5F2FA),
                    ),
                  }.entries.where(
                    (entry) =>
                        (category == 'month'
                                ? BookingPageAppearance.monthCalendarStyles
                                : BookingPageAppearance.weekCalendarStyles)
                            .contains(entry.key),
                  ))
                SizedBox(
                  width: constraints.maxWidth < 600
                      ? 190
                      : (constraints.maxWidth - 10) / 2,
                  child: Material(
                    color: entry.value.$4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        width: a.calendarStyle == entry.key ? 2 : 1,
                        color: a.calendarStyle == entry.key
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: widget.enabled
                          ? () => widget.onStyle(entry.key)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(entry.value.$3, size: 30),
                                const Spacer(),
                                if (a.calendarStyle == entry.key)
                                  const Icon(Icons.check_circle, size: 20),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              entry.value.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.value.$2,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ];
            if (constraints.maxWidth < 600) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final card in cards)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: card,
                      ),
                  ],
                ),
              );
            }
            return Wrap(spacing: 10, runSpacing: 10, children: cards);
          },
        ),
        const SizedBox(height: 16),
      ],
    );
    final extra = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        choices(
          '月曆配色',
          const {'template': '版型預設', 'page': '跟隨預約頁背景', 'custom': '自訂配色'},
          a.calendarColorMode,
          (mode) =>
              widget.onColors(mode, a.calendarBackground, a.calendarAccent),
        ),
        if (a.calendarColorMode == 'page')
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('月曆底色與重點色會隨預約頁配色一起更新。'),
          ),
        if (a.calendarColorMode == 'custom') ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final palette in const [
                ('森林', 0xFFF0F7F2, 0xFF34786B),
                ('奶茶', 0xFFFFF3E6, 0xFF926744),
                ('海藍', 0xFFEEF5FC, 0xFF376CA0),
                ('薰衣草', 0xFFF4F0FA, 0xFF79639A),
                ('暖粉', 0xFFFFF2F0, 0xFFAE5E63),
                ('深夜', 0xFF243136, 0xFF89CABC),
              ])
                ActionChip(
                  label: Text(palette.$1),
                  avatar: CircleAvatar(backgroundColor: Color(palette.$3)),
                  onPressed: widget.enabled
                      ? () => widget.onColors('custom', palette.$2, palette.$3)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: widget.enabled ? () => editColor(true) : null,
                icon: Icon(Icons.circle, color: Color(a.calendarBackground)),
                label: const Text('自訂底色'),
              ),
              OutlinedButton.icon(
                onPressed: widget.enabled ? () => editColor(false) : null,
                icon: Icon(Icons.circle, color: Color(a.calendarAccent)),
                label: const Text('自訂重點色'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        choices(
          '日期間距',
          BookingPageAppearance.calendarDensities,
          a.calendarDensity,
          widget.onDensity,
        ),
        choices(
          '彈出排版',
          BookingPageAppearance.calendarPresentations,
          a.calendarPresentation,
          widget.onPresentation,
        ),
        OutlinedButton.icon(
          onPressed: widget.enabled ? trial : null,
          icon: const Icon(Icons.open_in_new),
          label: const Text('試開日期視窗'),
        ),
        const SizedBox(height: 8),
        const Text(
          '彈出排版請按上方按鈕體驗。月曆直選版的頁內月曆只套用樣式與間距。',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
    final preview = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '即時月曆 · ${BookingPageAppearance.calendarStyles[a.calendarStyle]}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('示範操作，不會建立預約', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            BookingCalendar(
              initialMonth: month,
              firstDate: today,
              lastDate: today.add(const Duration(days: 90)),
              rangeStart: start,
              rangeEnd: end,
              visualStyle: a.calendarStyle,
              backgroundColor: background,
              accentColor: accent,
              compactCells: a.calendarDensity == 'compact',
              onMonthChanged: (v) => setState(() => month = v),
              onDayTap: select,
            ),
            const SizedBox(height: 12),
            Text(
              start == null
                  ? '先選入住日，再選退房日'
                  : '入住 ${start!.month}/${start!.day}  →  ${end == null ? "請選退房日" : "${end!.month}/${end!.day}"}',
            ),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 800
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [controls, extra],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(child: preview),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [controls, preview, const SizedBox(height: 20), extra],
            ),
    );
  }
}
