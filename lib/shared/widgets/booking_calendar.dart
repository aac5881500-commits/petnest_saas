// 檔案名稱：lib/shared/widgets/booking_calendar.dart
// 功能說明：共用預約月曆元件
// 用途：
// - 前台 / 後台共用同一套月曆視覺
// - 可顯示：
//   1. 不可預約日期
//   2. 關閉日期
//   6. 區間選取
//
// 備註：
// - 目前先做單月切換版
// - 不依賴外部套件
// - 下一步會接到後台預約管理頁
// - 再下一步會接到前台預約頁

import 'package:flutter/material.dart';

class BookingCalendar extends StatefulWidget {
  final bool allowBlockedTap;
  final String visualStyle;
  final Color? accentColor, backgroundColor;
  const BookingCalendar({
    this.allowBlockedTap = false,
    this.visualStyle = 'classic',
    this.accentColor,
    this.backgroundColor,
    super.key,
    required this.initialMonth,
    required this.firstDate,
    required this.lastDate,
    required this.onDayTap,
    this.rangeStart,
    this.rangeEnd,
    this.blockedDateKeys = const {},
    this.unbookableDateKeys = const {},
    this.blockedDateReasons = const {},
    this.remainingRoomsMap = const {},
    this.specialOpenDateKeys = const {},
    this.onMonthChanged,
    this.compactCells = false,
  });

  final DateTime initialMonth;
  final DateTime firstDate;
  final DateTime lastDate;

  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  final Set<String> blockedDateKeys;
  final Set<String> unbookableDateKeys;

  final Map<String, String> blockedDateReasons;
  final Map<String, int> remainingRoomsMap;
  final Set<String> specialOpenDateKeys;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime>? onMonthChanged;
  final bool compactCells;

  @override
  State<BookingCalendar> createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<BookingCalendar> {
  @override
  void didUpdateWidget(covariant BookingCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 🔥 當 range 改變時強制刷新
    if (oldWidget.rangeStart != widget.rangeStart ||
        oldWidget.rangeEnd != widget.rangeEnd) {
      setState(() {});
    }
  }

  late DateTime _visibleMonth;
  int _week = 0;
  final _ribbonScroll = ScrollController();
  @override
  void dispose() {
    _ribbonScroll.dispose();
    super.dispose();
  }

  void _moveRibbon(int direction) {
    if (!_ribbonScroll.hasClients) return;
    final position = _ribbonScroll.position;
    _ribbonScroll.animateTo(
      (position.pixels + direction * position.viewportDimension * .8).clamp(
        0.0,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(
      widget.initialMonth.year,
      widget.initialMonth.month,
      1,
    );
    final focus = widget.rangeStart ?? widget.firstDate;
    if (focus.year == _visibleMonth.year &&
        focus.month == _visibleMonth.month) {
      _week = (focus.day - 1) ~/ 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    );

    final int leadingEmpty = firstDayOfMonth.weekday % 7;
    final int totalDays = lastDayOfMonth.day;

    final List<Widget> dayCells = [];

    for (int i = 0; i < leadingEmpty; i++) {
      dayCells.add(const SizedBox());
    }

    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
      dayCells.add(_buildDayCell(context, date));
    }

    final monthGrid = Card(
      color: widget.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 4),
            _buildWeekHeader(),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                double maxWidth = constraints.maxWidth;
                if (!maxWidth.isFinite || maxWidth <= 0) {
                  maxWidth = MediaQuery.sizeOf(context).width;
                }
                final double spacing = widget.compactCells ? 4 : 8;
                final double cellWidth = ((maxWidth - spacing * 6) / 7).clamp(
                  1.0,
                  240.0,
                );
                final double minHeight = widget.compactCells ? 54 : 64;
                final double maxHeight = widget.compactCells ? 64 : 82;
                final double targetHeight;
                if (widget.compactCells) {
                  targetHeight = 58;
                } else if (maxWidth < 720) {
                  targetHeight = 58;
                } else if (maxWidth < 1000) {
                  targetHeight = 68;
                } else {
                  targetHeight = 74;
                }
                final double height = targetHeight.clamp(minHeight, maxHeight);
                return GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 4,
                  mainAxisSpacing: spacing,
                  childAspectRatio: cellWidth / height,
                  children: dayCells,
                );
              },
            ),
          ],
        ),
      ),
    );
    final content = switch (widget.visualStyle) {
      'stay' => _stayLayout(monthGrid),
      'week' => _weekLayout(context, totalDays),
      'journal' => _journalLayout(context, totalDays),
      'board' => _boardLayout(context, totalDays),
      'ribbon' => _ribbonLayout(context, totalDays),
      'weekbands' => _monthBands(context, totalDays, leadingEmpty),
      'monthlist' => _monthIndex(context, totalDays),
      'monthwall' => _monthWall(context, totalDays),
      _ => monthGrid,
    };
    if (widget.backgroundColor == null) return content;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(bodyColor: _ink, displayColor: _ink),
        iconTheme: theme.iconTheme.copyWith(color: _ink),
        colorScheme: theme.colorScheme.copyWith(
          surface: _paper,
          onSurface: _ink,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: _ink),
        child: content,
      ),
    );
  }

  Widget _monthShell(
    String key,
    String heading,
    String subtitle,
    Widget child,
  ) => Container(
    key: ValueKey('calendar-layout-$key'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          heading,
          style: TextStyle(
            fontSize: 25,
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: _ink, fontSize: 12)),
        const SizedBox(height: 12),
        _buildHeader(),
        const SizedBox(height: 12),
        child,
        const SizedBox(height: 20),
        _dateSummary(),
      ],
    ),
  );

  Widget _monthBands(
    BuildContext context,
    int totalDays,
    int leading,
  ) => _monthShell(
    'weekbands',
    '一整月，週週好安排',
    '按週分列，一次看完本月所有日期。',
    Column(
      children: [
        _buildWeekHeader(),
        const SizedBox(height: 12),
        for (var row = 0; row < ((leading + totalDays) / 7).ceil(); row++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: _accent, width: 3)),
              color: _accent.withValues(alpha: .05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WEEK ${row + 1}',
                  style: TextStyle(color: _ink, fontSize: 10, letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: SizedBox(
                            height: widget.compactCells ? 48 : 62,
                            child:
                                row * 7 + col - leading + 1 < 1 ||
                                    row * 7 + col - leading + 1 > totalDays
                                ? const SizedBox.shrink()
                                : _buildDayCell(
                                    context,
                                    DateTime(
                                      _visibleMonth.year,
                                      _visibleMonth.month,
                                      row * 7 + col - leading + 1,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _monthIndex(BuildContext context, int totalDays) => _monthShell(
    'monthlist',
    '本月日期索引',
    '上半月與下半月並排，直接定位入住日。',
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var half = 0; half < 2; half++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: half == 0 ? 0 : 6,
                right: half == 0 ? 6 : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: _accent.withValues(alpha: .12),
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      half == 0 ? '01—15' : '16—$totalDays',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (
                    var day = half == 0 ? 1 : 16;
                    day <= (half == 0 ? 15 : totalDays);
                    day++
                  )
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: InkWell(
                        onTap: () => _tapDate(
                          context,
                          DateTime(
                            _visibleMonth.year,
                            _visibleMonth.month,
                            day,
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 42,
                              height: 64,
                              child: _buildDayCell(
                                context,
                                DateTime(
                                  _visibleMonth.year,
                                  _visibleMonth.month,
                                  day,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '週${_weekday(DateTime(_visibleMonth.year, _visibleMonth.month, day))}',
                                style: TextStyle(color: _ink, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _monthWall(BuildContext context, int totalDays) => _monthShell(
    'monthwall',
    '這個月的小日子',
    '整月日期卡片，一張就是一天。',
    LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 320 ? 3 : 4;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var day = 1; day <= totalDays; day++)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '週${_weekday(DateTime(_visibleMonth.year, _visibleMonth.month, day))}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: _ink),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 64,
                        child: _buildDayCell(
                          context,
                          DateTime(
                            _visibleMonth.year,
                            _visibleMonth.month,
                            day,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  Color get _paper =>
      widget.backgroundColor ??
      switch (widget.visualStyle) {
        'stay' || 'ribbon' => const Color(0xFFF5EFE6),
        'journal' => const Color(0xFFF5F2FA),
        _ => const Color(0xFFECF4F3),
      };
  Color get _ink =>
      _paper.computeLuminance() < .3 ? Colors.white : const Color(0xFF293F42);
  Color get _accent => widget.accentColor ?? const Color(0xFF34786B);
  Color get _accentInk =>
      _accent.computeLuminance() < .4 ? Colors.white : Colors.black87;

  Widget _boardLayout(BuildContext context, int totalDays) => Container(
    key: const ValueKey('calendar-layout-board'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'LET’S MAKE A PLAN',
          style: TextStyle(color: _accent, letterSpacing: 2),
        ),
        Text(
          '把好日子，排進行事曆',
          style: TextStyle(
            color: _ink,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        _buildHeader(),
        _weekNavigation(totalDays),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final date in _weekDates(totalDays))
                SizedBox(
                  width: c.maxWidth < 260 ? c.maxWidth : (c.maxWidth - 10) / 2,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '週${_weekday(date)}',
                          style: TextStyle(color: _ink),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 60,
                          child: _buildDayCell(context, date),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _dateSummary(),
      ],
    ),
  );
  Widget _ribbonLayout(BuildContext context, int totalDays) => Container(
    key: const ValueKey('calendar-layout-ribbon'),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: _accent,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PETNEST / STAY PASS',
                style: TextStyle(
                  color: _accentInk,
                  letterSpacing: 2,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '你的住宿通行證',
                style: TextStyle(
                  color: _accentInk,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text('先選入住，再選退房', style: TextStyle(color: _accentInk)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              SizedBox(
                height: 112,
                child: Scrollbar(
                  controller: _ribbonScroll,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _ribbonScroll,
                    padding: const EdgeInsets.only(bottom: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: totalDays,
                    separatorBuilder: (_, index) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final date = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month,
                        index + 1,
                      );
                      return SizedBox(
                        width: 76,
                        child: Column(
                          children: [
                            Text(
                              '週${_weekday(date)}',
                              style: TextStyle(color: _ink),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SizedBox(
                                width: double.infinity,
                                child: _buildDayCell(context, date),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    tooltip: '往前瀏覽日期',
                    onPressed: () => _moveRibbon(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '左右滑動或按箭頭瀏覽整月日期',
                      style: TextStyle(color: _ink, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: '往後瀏覽日期',
                    onPressed: () => _moveRibbon(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(),
              ),
              _dateSummary(),
            ],
          ),
        ),
      ],
    ),
  );
  String _dateLabel(DateTime? date) =>
      date == null ? '尚未選擇' : '${date.month}/${date.day}';
  Widget _dateSummary({bool dark = false}) {
    final color = dark ? _accentInk : _ink;
    return Wrap(
      spacing: 28,
      runSpacing: 16,
      children: [
        for (final e in {
          '入住': widget.rangeStart,
          '退房': widget.rangeEnd,
        }.entries)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.key, style: TextStyle(color: color.withValues(alpha: .7))),
              Text(
                _dateLabel(e.value),
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        if (widget.rangeStart != null && widget.rangeEnd != null)
          Chip(
            label: Text(
              '${widget.rangeEnd!.difference(widget.rangeStart!).inDays} 晚',
            ),
          ),
      ],
    );
  }

  Widget _stayLayout(Widget grid) => Container(
    key: ValueKey('calendar-layout-stay'),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(24),
    ),
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'STAY PLANNER',
          style: TextStyle(letterSpacing: 3, color: _ink, fontSize: 11),
        ),
        SizedBox(height: 12),
        Text(
          widget.rangeEnd != null
              ? '住宿期間已選好'
              : widget.rangeStart == null
              ? '01  選擇入住日期'
              : '02  接著選擇退房日期',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        SizedBox(height: 18),
        _dateSummary(),
        SizedBox(height: 16),
        LinearProgressIndicator(
          value: widget.rangeEnd != null
              ? 1
              : widget.rangeStart != null
              ? .5
              : 0,
          color: _accent,
          backgroundColor: _accent.withValues(alpha: .12),
        ),
        SizedBox(height: 16),
        grid,
        SizedBox(height: 8),
        Text('點選日期安排旅程，完成後再確認住宿期間。', style: TextStyle(color: _ink)),
      ],
    ),
  );

  Widget _weekNavigation(int totalDays) => Row(
    children: [
      IconButton(
        tooltip: '上一週',
        onPressed: _week > 0 ? () => setState(() => _week--) : null,
        icon: Icon(Icons.chevron_left),
      ),
      Expanded(
        child: Text(
          '第 ${_week + 1} 週 · ${_week * 7 + 1}–${((_week + 1) * 7).clamp(1, totalDays)} 日',
          textAlign: TextAlign.center,
        ),
      ),
      IconButton(
        tooltip: '下一週',
        onPressed: (_week + 1) * 7 < totalDays
            ? () => setState(() => _week++)
            : null,
        icon: Icon(Icons.chevron_right),
      ),
    ],
  );

  List<DateTime> _weekDates(int totalDays) => [
    for (
      var day = _week * 7 + 1;
      day <= ((_week + 1) * 7).clamp(1, totalDays);
      day++
    )
      DateTime(_visibleMonth.year, _visibleMonth.month, day),
  ];
  String _weekday(DateTime d) =>
      ['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1];

  Widget _weekLayout(BuildContext context, int totalDays) => Container(
    key: ValueKey('calendar-layout-week'),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(24),
    ),
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '安排一段小假期',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: _accent,
          ),
        ),
        Text('一週一週看，找到適合出發的日子。'),
        SizedBox(height: 16),
        _buildHeader(),
        _weekNavigation(totalDays),
        SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final dates = _weekDates(totalDays);
            final columns = constraints.maxWidth >= 7 * 44 + 6 * 6 ? 7 : 4;
            final width = (constraints.maxWidth - (columns - 1) * 6) / columns;
            return Wrap(
              spacing: 6,
              runSpacing: 12,
              children: [
                for (final date in dates)
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '週${_weekday(date)}',
                            style: TextStyle(color: _ink),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 72,
                          child: _buildDayCell(context, date),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        SizedBox(height: 24),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR LITTLE GETAWAY',
                style: TextStyle(
                  letterSpacing: 2,
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
              SizedBox(height: 16),
              _dateSummary(dark: true),
            ],
          ),
        ),
        SizedBox(height: 12),
        Text('一週日期完整顯示；使用箭頭切換週次與月份。'),
      ],
    ),
  );

  Widget _journalLayout(BuildContext context, int totalDays) => Container(
    key: ValueKey('calendar-layout-journal'),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(20),
    ),
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '住宿日程',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        Text('按日期列選擇，入住與退房一目了然。'),
        SizedBox(height: 12),
        _buildHeader(),
        _weekNavigation(totalDays),
        for (final date in _weekDates(totalDays))
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Color.alphaBlend(_accent.withValues(alpha: .04), _paper),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.all(8),
              child: InkWell(
                onTap: () => _tapDate(context, date),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      height: 54,
                      child: _buildDayCell(context, date),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${date.month} 月 · 星期${_weekday(date)}',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _journalStatus(date),
                            style: TextStyle(fontSize: 12, color: _ink),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.touch_app_outlined, size: 18, color: _ink),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(height: 16),
        _dateSummary(),
      ],
    ),
  );
  String _journalStatus(DateTime date) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (date.isBefore(_dateOnly(widget.firstDate)) ||
        date.isAfter(_dateOnly(widget.lastDate))) {
      return '不在可預約期間';
    }
    if (widget.blockedDateKeys.contains(key)) return '暫停開放';
    if (widget.unbookableDateKeys.contains(key)) return '此日期已滿';
    if (widget.rangeStart != null &&
        _dateOnly(date) == _dateOnly(widget.rangeStart!)) {
      return '已選入住日';
    }
    if (widget.rangeEnd != null &&
        _dateOnly(date) == _dateOnly(widget.rangeEnd!)) {
      return '已選退房日';
    }
    return '點選此列安排住宿';
  }

  Widget _buildHeader() {
    final canGoPrev = !_isSameMonthOrBefore(_visibleMonth, widget.firstDate);
    final canGoNext = !_isSameMonthOrAfter(_visibleMonth, widget.lastDate);

    return Row(
      children: [
        IconButton(
          onPressed: canGoPrev ? _goPrevMonth : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(
              '${_visibleMonth.year} / ${_visibleMonth.month.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        IconButton(
          onPressed: canGoNext ? _goNextMonth : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildWeekHeader() {
    const labels = ['日', '一', '二', '三', '四', '五', '六'];

    return Row(
      children: labels.map((label) {
        return Expanded(
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime date) {
    final bool isOutOfRange =
        date.isBefore(_dateOnly(widget.firstDate)) ||
        date.isAfter(_dateOnly(widget.lastDate));

    final dateKey = _formatDateKey(date);

    final bool isBlocked = widget.blockedDateKeys.contains(dateKey);
    final bool isUnbookable = widget.unbookableDateKeys.contains(dateKey);

    final String? reason = widget.blockedDateReasons[dateKey];
    final bool isRangeStart =
        widget.rangeStart != null && _isSameDate(widget.rangeStart!, date);

    final bool isRangeEnd =
        widget.rangeEnd != null && _isSameDate(widget.rangeEnd!, date);

    final bool isInRange =
        widget.rangeStart != null &&
        widget.rangeEnd != null &&
        !date.isBefore(_dateOnly(widget.rangeStart!)) &&
        !date.isAfter(_dateOnly(widget.rangeEnd!));

    Color borderColor = _ink.withValues(alpha: .16);
    Color backgroundColor = widget.backgroundColor ?? Colors.white;
    Color dayTextColor = _ink;

    if (isOutOfRange) {
      backgroundColor = Colors.grey.shade100;
      dayTextColor = Colors.grey.shade400;
    } else if (isBlocked) {
      backgroundColor = Colors.grey.shade200;
      borderColor = Colors.red.shade200;
      dayTextColor = Colors.red.shade700;
    } else if (isUnbookable) {
      backgroundColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade300;
      dayTextColor = Colors.orange.shade800;
    } else if (widget.specialOpenDateKeys.contains(dateKey)) {
      backgroundColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
      dayTextColor = Colors.green.shade800;
    }
    final accent = widget.accentColor ?? Colors.blue;
    if (!isOutOfRange &&
        !isBlocked &&
        !isUnbookable &&
        !widget.specialOpenDateKeys.contains(dateKey)) {
      if (widget.visualStyle == 'minimal' || widget.visualStyle == 'round') {
        borderColor = Colors.transparent;
        backgroundColor = Colors.transparent;
      }
      if (widget.visualStyle == 'soft') {
        borderColor = Colors.transparent;
        backgroundColor = accent.withValues(alpha: .07);
      }
    }
    if (isRangeStart || isRangeEnd) {
      backgroundColor = accent;
      borderColor = widget.accentColor ?? Colors.blue.shade900;
      dayTextColor = accent.computeLuminance() < .4
          ? Colors.white
          : Colors.black87;
    } else if (isInRange) {
      backgroundColor = accent.withValues(alpha: .16);
      borderColor = Colors.blue.shade300;
      dayTextColor = _ink;
    }

    return InkWell(
      key: ValueKey('calendar-day-$dateKey'),
      onTap: () => _tapDate(context, date),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 2,
          vertical: widget.compactCells ? 0 : 8,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: widget.visualStyle == 'round'
              ? BoxShape.circle
              : BoxShape.rectangle,
          borderRadius: widget.visualStyle == 'round'
              ? null
              : BorderRadius.circular(
                  widget.visualStyle == 'soft'
                      ? 16
                      : widget.compactCells
                      ? 8
                      : 12,
                ),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.hardEdge,
        child: widget.compactCells
            ? Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${date.day}',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: dayTextColor,
                        height: 1.0,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 1,
                    child: _compactMarker(
                      isUnbookable: isUnbookable,
                      isBlocked: isBlocked,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${date.day}',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: dayTextColor,
                        height: 1.0,
                      ),
                    ),
                  ),
                  if (isUnbookable)
                    Text(
                      '滿',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  if (isBlocked && reason != null && reason.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  void _tapDate(BuildContext context, DateTime date) {
    final dateKey = _formatDateKey(date);
    final isOutOfRange =
        date.isBefore(_dateOnly(widget.firstDate)) ||
        date.isAfter(_dateOnly(widget.lastDate));
    final isUnbookable = widget.unbookableDateKeys.contains(dateKey);
    final isBlocked = widget.blockedDateKeys.contains(dateKey);

    /// 🔥 超出範圍
    if (isOutOfRange) return;

    /// 🔥 房滿（前後台都擋）
    if (isUnbookable && !widget.allowBlockedTap) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此日期已滿')));
      return;
    }

    /// 🔥 關閉日期
    if (isBlocked && !widget.allowBlockedTap) {
      return;
    }

    /// ✅ 正常
    widget.onDayTap(date);
  }

  Widget _compactMarker({required bool isUnbookable, required bool isBlocked}) {
    if (isUnbookable) {
      return Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: Color(0xFFE67A35),
          shape: BoxShape.circle,
        ),
      );
    }
    if (isBlocked) {
      return Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: Color(0xFFE53935),
          shape: BoxShape.circle,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _goPrevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
      _week = 0;
    });

    widget.onMonthChanged?.call(_visibleMonth); // 🔥 新增
  }

  void _goNextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
      _week = 0;
    });

    widget.onMonthChanged?.call(_visibleMonth); // 🔥 新增
  }

  bool _isSameMonthOrBefore(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month, 1);
    final bb = DateTime(b.year, b.month, 1);
    return aa.isAtSameMomentAs(bb) || aa.isBefore(bb);
  }

  bool _isSameMonthOrAfter(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month, 1);
    final bb = DateTime(b.year, b.month, 1);
    return aa.isAtSameMomentAs(bb) || aa.isAfter(bb);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    final aa = _dateOnly(a);
    final bb = _dateOnly(b);
    return aa.isAtSameMomentAs(bb);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatDateKey(DateTime date) {
    final d = _dateOnly(date);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
