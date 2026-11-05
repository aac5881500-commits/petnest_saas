import 'daily_care_upgrade_card.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/daily_care_paid_plan.dart';
import 'package:petnest_saas/core/models/daily_care_report_mode.dart';
import 'package:petnest_saas/core/services/daily_care_entitlement_math.dart';
import 'booking_cream_header.dart';
import 'booking_arrival_layout.dart';
import 'booking_editorial_design.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'booking_service_templates.dart';
import 'booking_appearance_scope.dart';
import 'booking_room_type_options.dart';
import 'booking_addon_section.dart';
import 'booking_summary_helper.dart';

class BookingServiceTemplateEditor extends StatelessWidget {
  const BookingServiceTemplateEditor({
    super.key,
    required this.appearance,
    required this.onChanged,
    this.enabled = true,
  });
  final BookingPageAppearance appearance;
  final ValueChanged<String> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('房型與服務・快速模板', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('選擇 A 同步套用兩頁雜誌套裝；其他模板只調整第二步。原版保留，儲存後才套用到客人頁面。'),
        const SizedBox(height: 16),
        for (final entry in BookingPageAppearance.serviceStyles.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: appearance.serviceStyle == entry.key
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: appearance.serviceStyle == entry.key
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFFDFE3E8),
                ),
              ),
              child: InkWell(
                key: ValueKey('booking-service-template-${entry.key}'),
                borderRadius: BorderRadius.circular(12),
                onTap: enabled ? () => onChanged(entry.key) : null,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(switch (entry.key) {
                        'editorial' => Icons.photo_library_outlined,
                        'journal' => Icons.auto_stories_outlined,
                        'premium' => Icons.grid_view_outlined,
                        _ => Icons.view_agenda_outlined,
                      }),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.value,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              switch (entry.key) {
                                'editorial' => '主打房型大圖・精簡服務列',
                                'journal' => '手帳分段・票券房型・柔和藍奶油色',
                                'premium' => '雙欄房型照片・深藍標題・精品線條',
                                _ => '保留目前完整展開的房型與加購排版',
                              },
                              style: const TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      if (appearance.serviceStyle == entry.key)
                        const Icon(Icons.check_circle, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          '示範資料可操作；容量、滿房、寵物與時段計費規則各模板相同。',
          style: TextStyle(fontSize: 12, height: 1.5),
        ),
      ],
    );
    final preview = BookingServicePreview(appearance: appearance);
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 900
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 300, child: controls),
                const SizedBox(width: 24),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: preview,
                    ),
                  ),
                ),
              ],
            )
          : Column(children: [controls, const SizedBox(height: 20), preview]),
    );
  }
}

class BookingServicePreview extends StatefulWidget {
  const BookingServicePreview({
    super.key,
    required this.appearance,
    this.shopName = '貓咪旅館',
    this.frontendTheme,
  });
  final String shopName;
  final HomeThemeModel? frontendTheme;
  final BookingPageAppearance appearance;
  @override
  State<BookingServicePreview> createState() => _BookingServicePreviewState();
}

class _BookingServicePreviewState extends State<BookingServicePreview> {
  static const rooms = <Map<String, dynamic>>[
    {
      'roomTypeId': 'small',
      'name': '日式豪房',
      'capacity': 1,
      'price': 800,
      'availableRooms': 2,
      '_previewAtlas': true,
    },
    {
      'roomTypeId': 'forest',
      'name': '森林套房',
      'capacity': 2,
      'price': 1200,
      'availableRooms': 0,
      '_previewAtlas': true,
    },
    {
      'roomTypeId': 'double',
      'name': '標準雙貓房',
      'capacity': 2,
      'price': 500,
      'extraPrice': 100,
      'availableRooms': 2,
      '_previewAtlas': true,
    },
  ];
  static const addons = <String, dynamic>{
    'enabled': true,
    'timeOptions': [
      {'label': '正常入住', 'price': 0, 'desc': '一般營業時間內辦理入住。'},
    ],
    'valueServices': [
      {
        'id': 'snack',
        'name': '迎賓點心組',
        'price': 100,
        'desc': '入住期間提供一次，飲食限制請先告知店家。',
      },
    ],
    'customServices': [
      {'id': 'care', 'name': '專屬照護', 'price': 200, 'desc': '依每隻貓咪的生活習慣安排日常照護。'},
    ],
    'dailyTimedServices': [
      {
        'id': 'play',
        'name': '每日陪玩',
        'price': 50,
        'desc': '依貓咪狀態安排陪伴與互動。',
        'timeSlots': [
          {'id': 'am', 'label': '10:00'},
          {'id': 'pm', 'label': '16:00'},
        ],
      },
    ],
  };
  static const careSetting = DailyCareSettingModel(
    enabled: true,
    stayReportMode: DailyCareReportMode.paidAddon,
    stayPaidPlan: DailyCarePaidPlan(
      price: 300,
      reports: 3,
      sessionLabels: ['早安回報', '午間回報', '晚安回報'],
    ),
  );
  String? _careId;
  Map<String, dynamic> _room = rooms.last;
  Map<String, dynamic>? _time;
  final _values = <Map<String, dynamic>>[];
  final _custom = <String, List<String>>{};
  final _daily = <String, Map<String, Map<String, List<String>>>>{};
  @override
  Widget build(BuildContext context) {
    final style = widget.appearance.serviceStyle;
    final theme =
        BookingPageAppearance.suiteServiceStyles[widget.appearance.style] ==
            style
        ? BookingArrivalLayout.themeFor(
            widget.appearance.style,
            appearance: widget.appearance,
            originalTheme: widget.frontendTheme,
          )
        : widget.appearance.applyLook(
            BookingServiceTemplates.themeFor(
              style,
              HomeThemeModel.classicDefault,
            ),
            frontendTheme: widget.frontendTheme,
          );
    final careAmount =
        const ['editorial', 'cream'].contains(style) && _careId != null
        ? DailyCareEntitlementMath.resolve(
            setting: careSetting,
            isDaycare: false,
            shopDaycareOn: true,
            offerId: 'preview',
            offerName: '示範房型',
            purchaseAddon: true,
            nights: 3,
            startDate: DateTime(2026, 11, 12),
            endDate: DateTime(2026, 11, 15),
          ).amount
        : 0;
    final parts = BookingSummaryHelper.calculatePriceParts(
      dailyCareAmount: careAmount,
      selectedRoomType: _room,
      nights: 3,
      selectedPetIds: const ['tea', 'sesame'],
      selectedTimeAddon: _time,
      selectedValueServices: _values,
      selectedCustomServices: _custom,
      selectedDailyTimedServices: _daily,
      addonData: addons,
    );
    return BookingAppearanceScope(
      appearance: widget.appearance,
      frontendTheme: widget.frontendTheme,
      child: Container(
        key: ValueKey('booking-service-preview-$style'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '即時預覽・${BookingPageAppearance.serviceStyles[style]}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '示範日期、房型及貓咪，可試選；不會建立預約。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (style == 'cream')
              BookingCreamHeader(
                shopName: widget.shopName,
                step: 2,
                title: '挑選安心的小房間',
                subtitle: '選擇房型，再搭配貓咪喜歡的服務。',
              ),
            if (style == 'editorial') ...[
              BookingEditorial.brand(shopName: widget.shopName),
              const BookingEditorialProgress(step: 2),
              BookingEditorial.trip('11/12—11/15 · 2 隻'),
            ] else
              Container(
                padding: const EdgeInsets.all(12),
                color: theme.primaryColor.withValues(alpha: .08),
                child: Text(
                  '11/12—11/15 · 奶茶、芝麻 · 2 隻',
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            BookingRoomTypeOptions(
              roomTypes: rooms,
              petCount: 2,
              theme: theme,
              selectedRoomTypeId: _room['roomTypeId'].toString(),
              onSelect: (v) => setState(() => _room = v),
            ),
            const SizedBox(height: 20),
            BookingAddonSection(
              showAddons: true,
              addonLoading: false,
              addonData: addons,
              selectedPetIds: const ['tea', 'sesame'],
              pets: const [
                {'petId': 'tea', 'name': '奶茶'},
                {'petId': 'sesame', 'name': '芝麻'},
              ],
              selectedTimeAddon: _time,
              selectedValueServices: _values,
              selectedCustomServices: _custom,
              selectedDailyTimedServices: _daily,
              startDate: DateTime(2026, 11, 12),
              endDate: DateTime(2026, 11, 15),
              theme: theme,
              addonTotal: parts['addonTotal'] ?? 0,
              onToggleShowAddons: () {},
              onSelectTimeAddon: (v) => setState(() => _time = v),
              onToggleValueService: (v) => setState(() {
                if (_values.any((item) => item['id'] == v['id'])) {
                  _values.removeWhere((item) => item['id'] == v['id']);
                } else {
                  _values.add(v);
                }
              }),
              onToggleCustomService: (v) => setState(() {
                final name = v['name'].toString();
                if (_custom.containsKey(name)) {
                  _custom.remove(name);
                } else {
                  _custom[name] = ['tea', 'sesame'];
                }
              }),
              onToggleCustomPet: (name, id, selected) => setState(() {
                final pets = _custom.putIfAbsent(name, () => []);
                if (selected) {
                  if (!pets.contains(id)) pets.add(id);
                } else {
                  pets.remove(id);
                }
              }),
              onDailyTimedServicesChanged: () => setState(() {}),
            ),
            if (const ['editorial', 'cream'].contains(style))
              DailyCareUpgradeCard(
                setting: careSetting,
                isDaycare: false,
                shopDaycareOn: true,
                offerId: 'preview',
                offerName: '示範房型',
                nights: 3,
                startDate: DateTime(2026, 11, 12),
                endDate: DateTime(2026, 11, 15),
                selectedPlanId: _careId,
                onChanged: (id) => setState(() => _careId = id),
              ),
            const SizedBox(height: 12),
            Text(
              '預估總額 NT\$ ${parts['subtotal']}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            if (style == 'cream') const BookingCreamProgress(step: 2),
            if (style == 'editorial' || style == 'cream')
              BookingEditorial.button('下一步', () {})
            else
              const FilledButton(onPressed: null, child: Text('示範預覽・不會建立預約')),
          ],
        ),
      ),
    );
  }
}
