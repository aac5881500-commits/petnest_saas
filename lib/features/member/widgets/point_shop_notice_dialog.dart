// 檔案名稱：lib/features/member/widgets/point_shop_notice_dialog.dart
// 功能說明：PetNest 點數平台公告。首次必須按「我知道了」，資訊按鈕則只供再次查看。

import 'package:flutter/material.dart';

class PointPlatformNoticeDialog extends StatelessWidget {
  const PointPlatformNoticeDialog({
    super.key,
    required this.requireAcceptance,
    required this.onPrimary,
    this.onDismiss,
    this.maxHeight,
  });

  final bool requireAcceptance;
  final VoidCallback onPrimary;
  final VoidCallback? onDismiss;
  final double? maxHeight;

  /// 黑色遮罩約 45%。
  static const Color barrierColor = Color(0x73000000);

  static const double desktopWidth = 420;
  static const double phoneSideInset = 24;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final bool desktop = screen.width >= desktopWidth + phoneSideInset * 2;
    final double cardWidth = desktop
        ? desktopWidth
        : (screen.width - phoneSideInset * 2).clamp(0, desktopWidth);
    final double cardMaxHeight = maxHeight ?? (screen.height - 48);
    final Color brand = Theme.of(context).colorScheme.primary;

    return Center(
      child: Material(
        key: const Key('point-platform-notice-card'),
        color: Colors.white,
        elevation: 10,
        shadowColor: const Color(0x26000000),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: cardWidth,
            maxHeight: cardMaxHeight,
          ),
          child: SizedBox(
            width: cardWidth,
            child: Stack(
              children: <Widget>[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                        child: _NoticeBody(brand: brand),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                      child: _NoticeFooter(
                        requireAcceptance: requireAcceptance,
                        brand: brand,
                        onPrimary: onPrimary,
                      ),
                    ),
                  ],
                ),
                if (!requireAcceptance)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      tooltip: '關閉',
                      onPressed: onDismiss,
                      icon: const Icon(Icons.close, size: 18),
                      visualDensity: VisualDensity.compact,
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

class _NoticeBody extends StatelessWidget {
  const _NoticeBody({required this.brand});

  final Color brand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.account_balance, size: 18, color: brand),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'PETNEST NOTICE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: brand.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'PetNest 平台通知',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.3,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'PetNest 的點數制度由各店家獨立營運。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 14),
        const _NoticeLine(
          icon: Icons.storefront_outlined,
          title: '點數僅限原店家使用',
          body: '在某間店獲得的點數，只能於該店使用。',
        ),
        const Divider(height: 18, thickness: 1, color: Color(0xFFF3F4F6)),
        const _NoticeLine(
          icon: Icons.sync_disabled_outlined,
          title: '無法跨店合併或轉移',
          body: '不同店家的點數會分開累計，不能互相折抵、兌換或轉贈。',
        ),
        const Divider(height: 18, thickness: 1, color: Color(0xFFF3F4F6)),
        const _NoticeLine(
          icon: Icons.rule_outlined,
          title: '各店規則可能不同',
          body: '點數取得、有效期限、折抵與兌換方式，依各店家設定為準。',
        ),
      ],
    );
  }
}

class _NoticeLine extends StatelessWidget {
  const _NoticeLine({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final Color brand = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: brand.withValues(alpha: 0.8)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoticeFooter extends StatelessWidget {
  const _NoticeFooter({
    required this.requireAcceptance,
    required this.brand,
    required this.onPrimary,
  });

  final bool requireAcceptance;
  final Color brand;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Text(
          '實際可用點數與明細，請以您目前查看的店家頁面為準。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 140,
            height: 42,
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: brand,
                foregroundColor: Colors.white,
                minimumSize: const Size(140, 42),
                maximumSize: const Size(140, 42),
                fixedSize: const Size(140, 42),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(requireAcceptance ? '我知道了' : '關閉'),
            ),
          ),
        ),
      ],
    );
  }
}
