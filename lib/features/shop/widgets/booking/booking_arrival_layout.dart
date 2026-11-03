import 'booking_appearance_scope.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'booking_quick_template_surface.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

/// 正式頁與預覽共用同一套結構；狀態與資料仍由原預約頁管理。
class BookingArrivalLayout extends StatefulWidget {
  const BookingArrivalLayout({
    super.key,
    required this.style,
    required this.shopName,
    required this.dateSection,
    required this.petsSection,
    required this.reminder,
    required this.campaign,
    required this.calendar,
    required this.hasDates,
    required this.petCount,
    required this.dateLabel,
    this.coverUrl = '',
  });
  final String style, shopName, dateLabel, coverUrl;
  final Widget dateSection, petsSection, reminder, campaign, calendar;
  final bool hasDates;
  final int petCount;
  static HomeThemeModel themeFor(
    String style, {
    BookingPageAppearance? appearance,
    HomeThemeModel? originalTheme,
  }) {
    final base = switch (style) {
      'original' => const HomeThemeModel(
        backgroundColorValue: 0xFFFFF9F0,
        cardColorValue: 0xFFFFF9F0,
        cardBorderColorValue: 0xFFFFCAA5,
        primaryColorValue: 0xFFFF881E,
        textColorValue: 0xFF603B28,
      ),
      'cream' => const HomeThemeModel(
        backgroundColorValue: 0xFFFFFEFB,
        cardColorValue: 0xFFFFFEFB,
        cardBorderColorValue: 0xFFB9DFF7,
        primaryColorValue: 0xFF429ADA,
        textColorValue: 0xFF60402D,
      ),
      'house' => const HomeThemeModel(
        backgroundColorValue: 0xFFFFFDF9,
        cardColorValue: 0xFFFFFDF9,
        cardBorderColorValue: 0xFFCEE4F3,
        primaryColorValue: 0xFF4E8FBF,
        textColorValue: 0xFF253B4A,
      ),
      'boutique' => const HomeThemeModel(
        backgroundColorValue: 0xFFF4F0E8,
        cardColorValue: 0xFFFFFFFF,
        cardBorderColorValue: 0xFFD9CDB8,
        primaryColorValue: 0xFF8D6D3D,
        textColorValue: 0xFF233D36,
      ),
      'minimal' => const HomeThemeModel(
        backgroundColorValue: 0xFFF6F5FF,
        cardColorValue: 0xFFFFFFFF,
        cardBorderColorValue: 0xFFDDD9F6,
        primaryColorValue: 0xFF6554C0,
        textColorValue: 0xFF292742,
      ),
      'soft' => const HomeThemeModel(
        backgroundColorValue: 0xFFFFF4EE,
        cardColorValue: 0xFFFFFDFA,
        cardBorderColorValue: 0xFFF4CDBF,
        primaryColorValue: 0xFFC15F4E,
        textColorValue: 0xFF51352F,
      ),
      'compact' => const HomeThemeModel(
        backgroundColorValue: 0xFFF0F5F8,
        cardColorValue: 0xFFFFFFFF,
        cardBorderColorValue: 0xFFCEDDE5,
        primaryColorValue: 0xFF196B83,
        textColorValue: 0xFF1C3542,
      ),
      _ => const HomeThemeModel(
        backgroundColorValue: 0xFFF1F7F3,
        cardColorValue: 0xFFFFFFFF,
        cardBorderColorValue: 0xFFD4E5DA,
        primaryColorValue: 0xFF39775D,
        textColorValue: 0xFF203D30,
      ),
    };
    return appearance?.applyLook(
          style == 'original' && originalTheme != null ? originalTheme : base,
          frontendTheme: originalTheme,
        ) ??
        base;
  }

  @override
  State<BookingArrivalLayout> createState() => _BookingArrivalLayoutState();
}

class _BookingArrivalLayoutState extends State<BookingArrivalLayout> {
  int _question = 0;
  bool _showPets = false;
  @override
  void didUpdateWidget(covariant BookingArrivalLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.style != oldWidget.style) {
      _question = 0;
      _showPets = false;
    }
    if (widget.hasDates && !oldWidget.hasDates) _showPets = true;
  }

  HomeThemeModel get t => BookingArrivalLayout.themeFor(
    widget.style,
    appearance: BookingAppearanceScope.of(context),
    originalTheme: BookingAppearanceScope.frontendOf(context),
  );
  Widget _heading(
    String eyebrow,
    String title,
    String subtitle, {
    bool dark = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            color: dark ? Colors.white70 : t.primaryColor,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 30,
            height: 1.18,
            fontWeight: FontWeight.w800,
            color: dark ? Colors.white : t.textColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: dark ? Colors.white70 : t.textColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    ),
  );
  Widget _panel(Widget child, {Color? color}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: color ?? t.cardColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
  Widget _summary() => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '本次住宿計畫',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: t.textColor,
          ),
        ),
        const SizedBox(height: 16),
        _status(Icons.calendar_month, '住宿日期', widget.dateLabel),
        const Divider(height: 28),
        _status(
          Icons.pets,
          '入住貓咪',
          widget.petCount > 0 ? '已選 ${widget.petCount} 隻' : '尚未選擇',
        ),
        const Divider(height: 28),
        _status(Icons.hotel_outlined, '房型與費用', '下一步選擇後計算'),
      ],
    ),
  );
  Widget _status(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: t.primaryColor, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: t.textColor.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(color: t.textColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _timeline(String number, String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: t.primaryColor,
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: t.textColor,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(left: 15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 0, 18),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: t.cardBorderColor, width: 2),
            ),
          ),
          child: child,
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final Widget body;
    switch (widget.style) {
      case 'original':
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.dateSection,
            widget.campaign,
            if (!widget.hasDates) widget.reminder,
            widget.petsSection,
          ],
        );

      case 'cream':
      case 'house':
        body = BookingQuickTemplateSurface(
          style: widget.style,
          shopName: widget.shopName,
          pets: widget.petsSection,
          dates: widget.dateSection,
          reminder: widget.reminder,
          campaign: widget.campaign,
        );

      case 'boutique':
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  SizedBox(
                    height: 275,
                    width: double.infinity,
                    child: widget.coverUrl.isNotEmpty
                        ? Image.network(
                            widget.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stack) => _heroFallback(),
                          )
                        : _heroFallback(),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black12,
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 8,
                    child: _heading(
                      'A LITTLE GETAWAY',
                      '讓牠，也放個假。',
                      widget.shopName,
                      dark: true,
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: widget.dateSection,
              ),
            ),
            const Text(
              'THE STAY / 入住成員',
              style: TextStyle(
                letterSpacing: 2,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            widget.petsSection,
            widget.campaign,
            widget.reminder,
          ],
        );
      case 'minimal':
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 2; i++)
                  ChoiceChip(
                    label: Text(i == 0 ? '01 住宿時間' : '02 入住夥伴'),
                    selected: _question == i,
                    onSelected: (_) => setState(() => _question = i),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            _heading(
              'LET’S PLAN TOGETHER',
              _question == 0 ? '這次，\n哪天來住？' : '這次，\n誰要一起來？',
              _question == 0
                  ? '先選入住與退房日期，接著挑選入住貓咪。'
                  : widget.hasDates
                  ? widget.dateLabel
                  : '可以先選貓咪，回到上一題補上日期。',
            ),
            _panel(_question == 0 ? widget.dateSection : widget.petsSection),
            Wrap(
              spacing: 12,
              children: [
                if (_question == 1)
                  TextButton(
                    onPressed: () => setState(() => _question = 0),
                    child: const Text('返回日期'),
                  ),
                if (_question == 0)
                  FilledButton.icon(
                    onPressed: widget.hasDates
                        ? () => setState(() => _question = 1)
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('日期選好了，選貓咪'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            widget.campaign,
            widget.reminder,
          ],
        );
      case 'soft':
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8DCCD),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.pets, size: 48, color: Color(0xFFC15F4E)),
                  const SizedBox(height: 18),
                  _heading(
                    'HELLO, LITTLE FRIEND',
                    '今天，\n幫誰安排假期？',
                    '先認識入住的小夥伴，再安排牠的旅程。',
                  ),
                ],
              ),
            ),
            _timeline('1', '挑選入住小夥伴', widget.petsSection),
            _timeline('2', '安排住宿時間', widget.dateSection),
            _timeline('3', '出發前的小提醒', widget.reminder),
            widget.campaign,
          ],
        );
      case 'compact':
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: t.textColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _heading(
                'RESERVATION DESK',
                '建立住宿計畫',
                widget.shopName,
                dark: true,
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final form = Column(
                  children: [
                    widget.dateSection,
                    widget.petsSection,
                    widget.campaign,
                  ],
                );
                final overview = Column(
                  children: [_summary(), widget.reminder],
                );
                if (constraints.maxWidth >= 700) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: form),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: overview),
                    ],
                  );
                }
                return Column(children: [_summary(), form, widget.reminder]);
              },
            ),
          ],
        );
      default:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(
              'MAKE ROOM FOR A LITTLE JOY',
              '從一段好日子開始',
              '在月曆上選擇入住與退房日，安排貓咪的小旅行。',
            ),
            _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.hasDates ? widget.dateLabel : '先選入住日，再選退房日',
                    style: TextStyle(
                      color: t.primaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  widget.calendar,
                ],
              ),
            ),
            if (widget.hasDates || _showPets)
              widget.petsSection
            else
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _status(Icons.pets, '接下來', '挑選這次入住的貓咪'),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => setState(() => _showPets = true),
                      child: const Text('也可以先選貓咪 →'),
                    ),
                  ],
                ),
              ),
            widget.campaign,
            widget.reminder,
          ],
        );
    }
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: t.primaryColor),
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: BookingAppearanceScope.of(context).look.font.isEmpty
              ? null
              : BookingAppearanceScope.of(context).look.font,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: t.textColor,
          fontFamily: BookingAppearanceScope.of(context).look.font.isEmpty
              ? null
              : BookingAppearanceScope.of(context).look.font,
        ),
        child: Container(
          color:
              BookingAppearanceScope.of(context).look.followFrontend &&
                  t.usesAppBackgroundImage
              ? Colors.transparent
              : t.backgroundColor,
          padding: EdgeInsets.all(widget.style == 'original' ? 0 : 8),
          child: body,
        ),
      ),
    );
  }

  Widget _heroFallback() => Image.asset(
    'assets/images/shop_house/modern_japanese/modern_japanese_courtyard.jpg',
    fit: BoxFit.cover,
  );
}
