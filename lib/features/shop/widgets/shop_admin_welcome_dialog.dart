// 檔案名稱：lib/features/shop/widgets/shop_admin_welcome_dialog.dart
// 功能說明：新店家首次進入後台的歡迎彈窗與基本資料提醒卡。

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const _ink = Color(0xFF74250F);
const _muted = Color(0xFF796A5D);
const _orange = Color(0xFFF45B14);
const _cream = Color(0xFFFFFAF2);
const _line = Color(0xFFF3E7D8);
const _mobilePhoto = 'assets/images/shop_onboarding/welcome_mobile.webp';
const _desktopPhoto = 'assets/images/shop_onboarding/welcome_desktop.webp';
const _regularAxes = [ui.FontVariation('wght', 400)];
const _boldAxes = [ui.FontVariation('wght', 700)];
const _heavyAxes = [ui.FontVariation('wght', 800)];

Widget _photoFallback(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
) {
  return const ColoredBox(color: Color(0xFFF6E7D4));
}

class ShopAdminWelcomeDialog extends StatefulWidget {
  const ShopAdminWelcomeDialog({
    super.key,
    required this.onStart,
    required this.onLater,
  });

  final VoidCallback onStart;
  final VoidCallback onLater;

  @override
  State<ShopAdminWelcomeDialog> createState() => _ShopAdminWelcomeDialogState();
}

class _ShopAdminWelcomeDialogState extends State<ShopAdminWelcomeDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.isAnimating || _entrance.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Animation<double> _fade(double start, double end) {
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final desktop = size.width >= 900;
    final maxWidth = desktop ? 920.0 : size.width - 20;
    final maxHeight = size.height - (desktop ? 64 : 24);
    return SafeArea(
      child: Center(
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: 'NotoSansTC',
            fontVariations: _regularAxes,
            color: _ink,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Material(
              key: const ValueKey('shop-admin-welcome'),
              color: _cream,
              elevation: 0,
              shadowColor: const Color(0x1A784A22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(desktop ? 28 : 22),
                side: const BorderSide(color: _line),
              ),
              clipBehavior: Clip.antiAlias,
              child: desktop
                  ? ListView(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      children: [
                        _DesktopBody(
                          fade: _fade,
                          onStart: widget.onStart,
                          onLater: widget.onLater,
                        ),
                      ],
                    )
                  : _PhoneBody(
                      fade: _fade,
                      onStart: widget.onStart,
                      onLater: widget.onLater,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneBody extends StatelessWidget {
  const _PhoneBody({
    required this.fade,
    required this.onStart,
    required this.onLater,
  });

  final Animation<double> Function(double start, double end) fade;
  final VoidCallback onStart;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        FadeTransition(opacity: fade(0, 0.45), child: const _PhonePhoto()),
        const SizedBox(height: 14),
        FadeTransition(opacity: fade(0.12, 0.5), child: const _WelcomeCopy()),
        const SizedBox(height: 14),
        _Steps(fade: fade),
        const SizedBox(height: 16),
        FadeTransition(
          opacity: fade(0.72, 1),
          child: _Actions(onStart: onStart, onLater: onLater),
        ),
      ],
    );
  }
}

class _DesktopBody extends StatelessWidget {
  const _DesktopBody({
    required this.fade,
    required this.onStart,
    required this.onLater,
  });

  final Animation<double> Function(double start, double end) fade;
  final VoidCallback onStart;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(flex: 5, child: _DesktopPhoto()),
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 28, 28, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeTransition(
                  opacity: fade(0.08, 0.45),
                  child: const _WelcomeCopy(compact: true),
                ),
                const SizedBox(height: 16),
                _Steps(fade: fade),
                const SizedBox(height: 18),
                FadeTransition(
                  opacity: fade(0.72, 1),
                  child: _Actions(onStart: onStart, onLater: onLater),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhonePhoto extends StatelessWidget {
  const _PhonePhoto();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 132,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _mobilePhoto,
              fit: BoxFit.cover,
              alignment: const Alignment(0, 0.42),
              cacheWidth: 720,
              semanticLabel: '暖陽照入木質貓咪旅社',
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: Color(0xFFF6E7D4)),
            ),
            const Positioned(left: 12, top: 12, child: _BrandChip()),
          ],
        ),
      ),
    );
  }
}

class _DesktopPhoto extends StatelessWidget {
  const _DesktopPhoto();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 8, 18),
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 1774 / 887,
              child: Image.asset(
                _desktopPhoto,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                semanticLabel: '暖陽照入木質貓咪旅社，長毛虎斑貓躺在柔軟地毯上',
                errorBuilder: _photoFallback,
              ),
            ),
            Positioned(left: 12, top: 12, child: _BrandChip()),
          ],
        ),
      ),
    );
  }
}

class _BrandChip extends StatelessWidget {
  const _BrandChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF5FFFCF5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF0DDC3)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets_rounded, size: 16, color: Color(0xFFB23A0B)),
            SizedBox(width: 6),
            Text(
              'PetNest',
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '歡迎加入 PetNest！',
          style: TextStyle(
            color: _orange,
            fontSize: compact ? 14 : 13,
            fontWeight: FontWeight.w700,
            fontVariations: _boldAxes,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '你的貓咪旅社建立成功了！',
          style: TextStyle(
            color: _ink,
            fontSize: compact ? 26 : 22,
            fontWeight: FontWeight.w800,
            fontVariations: _heavyAxes,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '接下來，讓我們一起把旅社準備好，打造讓毛孩安心、讓飼主放心的第二個家。',
          style: TextStyle(color: _muted, fontSize: 14, height: 1.6),
        ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.fade});

  final Animation<double> Function(double start, double end) fade;

  @override
  Widget build(BuildContext context) {
    const steps = [
      _StepData(
        done: true,
        current: false,
        title: '建立旅社',
        detail: '你的專屬旅社已成功建立。',
      ),
      _StepData(
        done: false,
        current: true,
        title: '完善基本資料',
        detail: '設定聯絡方式、地址與店家介紹。',
      ),
      _StepData(
        done: false,
        current: false,
        title: '開始準備營運',
        detail: '後續可以逐步設定營業資訊、房型與服務。',
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          FadeTransition(
            opacity: fade(0.28 + i * 0.14, 0.62 + i * 0.12),
            child: _StepRow(
              index: i,
              step: steps[i],
              last: i == steps.length - 1,
            ),
          ),
      ],
    );
  }
}

class _StepData {
  const _StepData({
    required this.done,
    required this.current,
    required this.title,
    required this.detail,
  });

  final bool done;
  final bool current;
  final String title;
  final String detail;
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.step, required this.last});

  final int index;
  final _StepData step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = step.done
        ? const Color(0xFF5E8A45)
        : step.current
        ? _orange
        : const Color(0xFFCDB9A6);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: step.done
                  ? const Color(0xFF5E8A45)
                  : step.current
                  ? _orange
                  : const Color(0xFFFFF6EE),
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
            child: step.done
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: step.current ? Colors.white : color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      color: step.current || step.done
                          ? const Color(0xFF30261E)
                          : _muted,
                      fontWeight: FontWeight.w700,
                      fontVariations: _boldAxes,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.detail,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onStart, required this.onLater});

  final VoidCallback onStart;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: const ValueKey('shop-admin-welcome-start'),
          onPressed: onStart,
          style: FilledButton.styleFrom(
            backgroundColor: _orange,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontFamily: 'NotoSansTC',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontVariations: _boldAxes,
            ),
          ),
          child: const Text('開始設定店家資料 →'),
        ),
        const SizedBox(height: 4),
        TextButton(
          key: const ValueKey('shop-admin-welcome-later'),
          onPressed: onLater,
          style: TextButton.styleFrom(
            foregroundColor: _muted,
            minimumSize: const Size(double.infinity, 44),
          ),
          child: const Text('稍後再設定'),
        ),
        const Text(
          '不用一次完成，之後都可以回來繼續設定。',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

class ShopAdminWelcomeReminder extends StatelessWidget {
  const ShopAdminWelcomeReminder({
    super.key,
    required this.onOpen,
    this.onReplay,
  });

  final VoidCallback? onOpen;
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamily: 'NotoSansTC',
        fontVariations: _regularAxes,
        color: _ink,
      ),
      child: Container(
        key: const ValueKey('shop-admin-welcome-reminder'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pets_rounded, size: 18, color: Color(0xFFB23A0B)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '再完成一點點，讓你的旅社準備好迎接毛孩！',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '先完善店家基本資料，之後就能逐步設定其他服務。',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
            ),
            if (onOpen != null || onReplay != null)
              Wrap(
                spacing: 12,
                runSpacing: 0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (onOpen != null)
                    TextButton(
                      key: const ValueKey('shop-admin-welcome-reminder-open'),
                      onPressed: onOpen,
                      style: TextButton.styleFrom(
                        foregroundColor: _orange,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(44, 44),
                        textStyle: const TextStyle(
                          fontFamily: 'NotoSansTC',
                          fontWeight: FontWeight.w700,
                          fontVariations: _boldAxes,
                          fontSize: 14,
                        ),
                      ),
                      child: const Text('前往完善資料 →'),
                    ),
                  if (onReplay != null)
                    TextButton.icon(
                      key: const ValueKey('shop-admin-welcome-replay'),
                      onPressed: onReplay,
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: const Text('重新觀看引導'),
                      style: TextButton.styleFrom(
                        foregroundColor: _muted,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(44, 44),
                        textStyle: const TextStyle(
                          fontFamily: 'NotoSansTC',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
