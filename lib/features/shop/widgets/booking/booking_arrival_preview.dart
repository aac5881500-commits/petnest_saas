import 'booking_background_surface.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'booking_template_pet_grid.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'booking_appearance_scope.dart';
import 'booking_arrival_layout.dart';
import 'booking_date_section.dart';
import 'booking_inline_calendar.dart';
import 'booking_pet_choice.dart';
import 'booking_step_widgets.dart';
import 'front_calendar_payload.dart';

/// 與正式頁共用版面，只有預覽的日期與貓咪是明確標示的示範資料。
class BookingArrivalPreview extends StatefulWidget {
  const BookingArrivalPreview({
    super.key,
    required this.appearance,
    this.shopName = 'PetNest 貓咪旅店',
    this.coverUrl = '',
    this.frontendTheme,
  });
  final BookingPageAppearance appearance;
  final String shopName, coverUrl;
  final HomeThemeModel? frontendTheme;
  @override
  State<BookingArrivalPreview> createState() => _BookingArrivalPreviewState();
}

class _BookingArrivalPreviewState extends State<BookingArrivalPreview> {
  DateTime? _start, _end;
  final _pets = <String>{};
  @override
  Widget build(BuildContext context) {
    final a = widget.appearance;
    final t = BookingArrivalLayout.themeFor(
      a.style,
      appearance: a,
      originalTheme: widget.frontendTheme,
    );
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final label = _start == null || _end == null
        ? '尚未選擇入住與退房日'
        : '${_start!.month}/${_start!.day} → ${_end!.month}/${_end!.day}・${_end!.difference(_start!).inDays} 晚';
    Widget reminder() => BookingThemedCard(
      theme: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            a.reminderTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text('訂房安全提醒', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            '本平台僅提供預約系統服務，實際住宿與照護內容由店家負責。',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
          if (a.note.isNotEmpty) ...[const SizedBox(height: 8), Text(a.note)],
        ],
      ),
    );
    return BookingAppearanceScope(
      appearance: a,
      frontendTheme: widget.frontendTheme,
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: t.primaryColor),
        ),
        child: BookingBackgroundSurface(
          theme: t,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '即時預覽・${BookingPageAppearance.styles[a.style]}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: t.textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '示範日期與貓咪，可試操作；尚未儲存',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11),
                ),
              ),
              if (a.style == 'original')
                BookingStepIndicator(currentStep: 1, theme: t),
              BookingArrivalLayout(
                style: a.style,
                shopName: widget.shopName,
                coverUrl: widget.coverUrl,
                hasDates: _start != null && _end != null,
                petCount: _pets.length,
                dateLabel: label,
                calendar: BookingInlineCalendar(
                  today: today,
                  maxDays: 90,
                  startDate: _start,
                  endDate: _end,
                  loadMonth: (_) async => const FrontCalendarPayload(
                    blockedDateKeys: {},
                    blockedDateReasons: {},
                    unbookableDateKeys: {},
                    priceMap: {},
                    remainingRoomsMap: {},
                  ),
                  onApply: (start, end) => setState(() {
                    _start = start;
                    _end = end;
                  }),
                ),
                dateSection: BookingDateSection(
                  shopName: widget.shopName,
                  bookingEnabled: true,
                  theme: t,
                  startDate: _start,
                  endDate: _end,
                  nights: _end != null ? _end!.difference(_start!).inDays : 0,
                  onOpenCalendar: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: today,
                      lastDate: today.add(const Duration(days: 90)),
                      initialDateRange: _start != null && _end != null
                          ? DateTimeRange(start: _start!, end: _end!)
                          : null,
                    );
                    if (range != null && mounted) {
                      setState(() {
                        _start = range.start;
                        _end = range.end;
                      });
                    }
                  },
                ),
                petsSection: BookingThemedCard(
                  theme: t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '選擇入住貓咪（已選 ${_pets.length} 隻）',
                        style: TextStyle(
                          color: t.textColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (const ['cream', 'house'].contains(a.style))
                        BookingTemplatePetGrid(
                          style: a.style,
                          pets: [
                            {
                              'petId': '奶茶',
                              'name': '奶茶',
                              '_previewAsset':
                                  'assets/images/booking_demo_ginger_chibi_v1.png',
                            },
                            {
                              'petId': '芝麻',
                              'name': '芝麻',
                              '_previewAsset':
                                  'assets/images/booking_demo_tabby_chibi_v1.png',
                            },
                          ],
                          selectedIds: _pets.toList(),
                          theme: t,
                          onToggle: (name, selected) => setState(() {
                            if (selected) {
                              _pets.add(name);
                            } else {
                              _pets.remove(name);
                            }
                          }),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: ['奶茶', '芝麻']
                              .map(
                                (name) => BookingPetChoice(
                                  pet: {
                                    'name': name,
                                    '_previewAsset': name == '奶茶'
                                        ? 'assets/images/booking_demo_ginger_chibi_v1.png'
                                        : 'assets/images/booking_demo_tabby_chibi_v1.png',
                                  },
                                  selected: _pets.contains(name),
                                  theme: t,
                                  portrait: a.style == 'soft',
                                  onSelected: (selected) => setState(() {
                                    if (selected) {
                                      _pets.add(name);
                                    } else {
                                      _pets.remove(name);
                                    }
                                  }),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
                reminder: reminder(),
                campaign: const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: null,
                  child: const Text('下一步・房型與服務'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingLayoutThumbnail extends StatelessWidget {
  const BookingLayoutThumbnail({super.key, required this.style});
  final String style;
  @override
  Widget build(BuildContext context) {
    final t = BookingArrivalLayout.themeFor(style);
    Widget block(double height, {double opacity = .15}) => Container(
      height: height,
      decoration: BoxDecoration(
        color: t.primaryColor.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(4),
      ),
    );
    Widget cells() => Wrap(
      spacing: 3,
      runSpacing: 3,
      children: List.generate(
        21,
        (i) => Container(
          width: 11,
          height: 7,
          color: t.primaryColor.withValues(alpha: i == 9 || i == 10 ? .8 : .15),
        ),
      ),
    );
    return Container(
      height: 94,
      padding: const EdgeInsets.all(9),
      color: t.backgroundColor,
      child: switch (style) {
        'original' => Column(
          children: [
            block(24),
            const SizedBox(height: 6),
            block(15),
            const SizedBox(height: 6),
            block(19),
          ],
        ),
        'cream' || 'house' => Column(
          children: [
            block(23, opacity: style == 'cream' ? .15 : .3),
            const SizedBox(height: 5),
            Row(
              children: [
                for (var i = 0; i < 2; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        height: 26,
                        decoration: BoxDecoration(
                          color: t.primaryColor.withValues(alpha: .18),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(style == 'house' ? 18 : 5),
                            bottom: const Radius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            block(9),
          ],
        ),
        'boutique' => Column(
          children: [
            block(44, opacity: .8),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(child: block(18)),
                const SizedBox(width: 5),
                Expanded(child: block(18)),
              ],
            ),
          ],
        ),
        'minimal' => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 35, child: block(6)),
            const SizedBox(height: 10),
            SizedBox(width: 65, child: block(15, opacity: .7)),
            const SizedBox(height: 12),
            block(22),
          ],
        ),
        'soft' => Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                3,
                (_) => CircleAvatar(
                  radius: 13,
                  backgroundColor: t.primaryColor.withValues(alpha: .2),
                  child: Icon(Icons.pets, size: 13, color: t.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 10),
            block(10),
            const SizedBox(height: 7),
            block(10),
          ],
        ),
        'compact' => Column(
          children: [
            block(12, opacity: .8),
            const SizedBox(height: 7),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        block(18),
                        const SizedBox(height: 5),
                        block(18),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(flex: 2, child: block(48, opacity: .3)),
                ],
              ),
            ),
          ],
        ),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 70, child: block(7, opacity: .7)),
            const SizedBox(height: 10),
            cells(),
            const SizedBox(height: 7),
            block(8),
          ],
        ),
      },
    );
  }
}
