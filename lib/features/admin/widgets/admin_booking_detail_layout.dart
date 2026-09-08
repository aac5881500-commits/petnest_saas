// 檔案名稱：lib/features/admin/widgets/admin_booking_detail_layout.dart
// 功能說明：店主端住宿／安親訂單詳細共用響應式版型：依可用寬度切桌面／平板／手機

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';

enum AdminBookingDetailMode { phone, tablet, desktop }

class AdminBookingDetailMetrics {
  AdminBookingDetailMetrics._();

  static const double desktopMin = 1024;
  static const double tabletMin = 600;
  static const double twoColumnMin = 840;

  static AdminBookingDetailMode modeFor(double width) {
    if (width >= desktopMin) {
      return AdminBookingDetailMode.desktop;
    }
    if (width >= tabletMin) {
      return AdminBookingDetailMode.tablet;
    }
    return AdminBookingDetailMode.phone;
  }

  static bool useTwoColumns(double width) => width >= twoColumnMin;

  static EdgeInsets pagePadding(AdminBookingDetailMode mode) {
    switch (mode) {
      case AdminBookingDetailMode.desktop:
        return const EdgeInsets.fromLTRB(24, 16, 24, 32);
      case AdminBookingDetailMode.tablet:
        return const EdgeInsets.fromLTRB(16, 12, 16, 28);
      case AdminBookingDetailMode.phone:
        return const EdgeInsets.fromLTRB(12, 8, 12, 24);
    }
  }
}

class AdminBookingDetailScope extends InheritedWidget {
  const AdminBookingDetailScope({
    super.key,
    required this.mode,
    required this.width,
    required super.child,
  });

  final AdminBookingDetailMode mode;
  final double width;

  bool get isPhone => mode == AdminBookingDetailMode.phone;

  bool get isDesktop => mode == AdminBookingDetailMode.desktop;

  static AdminBookingDetailScope of(BuildContext context) {
    final AdminBookingDetailScope? scope = context
        .dependOnInheritedWidgetOfExactType<AdminBookingDetailScope>();
    return scope ??
        const AdminBookingDetailScope(
          mode: AdminBookingDetailMode.phone,
          width: 390,
          child: SizedBox.shrink(),
        );
  }

  @override
  bool updateShouldNotify(AdminBookingDetailScope oldWidget) {
    return mode != oldWidget.mode || width != oldWidget.width;
  }
}

class AdminBookingDetailScaffold extends StatelessWidget {
  const AdminBookingDetailScaffold({
    super.key,
    required this.title,
    required this.bookingCode,
    required this.overview,
    required this.left,
    required this.right,
    this.actions,
    this.banners = const <Widget>[],
    this.appBarActions = const <Widget>[],
  });

  final String title;
  final String bookingCode;
  final Widget overview;
  final Widget? actions;
  final List<Widget> banners;
  final List<Widget> left;
  final List<Widget> right;
  final List<Widget> appBarActions;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final AdminBookingDetailMode mode = AdminBookingDetailMetrics.modeFor(
          width,
        );
        return AdminBookingDetailScope(
          mode: mode,
          width: width,
          child: Scaffold(
            backgroundColor: _warmBackground(theme),
            appBar: AppBar(
              backgroundColor: _warmBackground(theme),
              foregroundColor: theme.titleColor,
              elevation: 0,
              titleSpacing: 0,
              title: _AppBarTitle(title: title, bookingCode: bookingCode),
              actions: <Widget>[
                if (bookingCode.trim().isNotEmpty)
                  IconButton(
                    tooltip: '複製訂單編號',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: bookingCode));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已複製訂單編號')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 20),
                  ),
                ...appBarActions,
              ],
            ),
            body: CustomScrollView(
              slivers: <Widget>[
                SliverPadding(
                  padding: AdminBookingDetailMetrics.pagePadding(mode),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(<Widget>[
                      if (mode != AdminBookingDetailMode.phone)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            '訂單管理  >  訂單詳細',
                            style: TextStyle(
                              color: theme.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ...banners,
                      overview,
                      if (actions != null) ...<Widget>[
                        const SizedBox(height: 12),
                        actions!,
                      ],
                      const SizedBox(height: 16),
                      if (AdminBookingDetailMetrics.useTwoColumns(width))
                        _TwoColumn(left: left, right: right)
                      else
                        _SingleColumn(leading: left, trailing: right),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _warmBackground(ShopFrontendTheme theme) {
    return Color.lerp(
          theme.pageBackgroundColor,
          const Color(0xFFF7F4EF),
          0.55,
        ) ??
        const Color(0xFFF7F4EF);
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.title, required this.bookingCode});

  final String title;
  final String bookingCode;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.titleColor,
          ),
        ),
        if (bookingCode.trim().isNotEmpty)
          Text(
            bookingCode,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: theme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});

  final List<Widget> left;
  final List<Widget> right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _withGaps(left),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _withGaps(right),
          ),
        ),
      ],
    );
  }
}

class _SingleColumn extends StatelessWidget {
  const _SingleColumn({required this.leading, required this.trailing});

  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _withGaps(<Widget>[...leading, ...trailing]),
    );
  }
}

List<Widget> _withGaps(List<Widget> children) {
  final List<Widget> out = <Widget>[];
  for (int i = 0; i < children.length; i++) {
    if (i > 0) {
      out.add(const SizedBox(height: 12));
    }
    out.add(children[i]);
  }
  return out;
}

class AdminBookingDetailCard extends StatelessWidget {
  const AdminBookingDetailCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.tint,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor.withValues(alpha: 0.7)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.titleColor.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AdminBookingDetailSection extends StatelessWidget {
  const AdminBookingDetailSection({
    super.key,
    required this.title,
    required this.child,
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  final String title;
  final Widget child;
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final bool phone = AdminBookingDetailScope.of(context).isPhone;
    final bool fold = collapsible && phone;
    if (!fold) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: theme.titleColor,
              ),
            ),
          ),
          child,
        ],
      );
    }
    return AdminBookingDetailCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: theme.titleColor,
            ),
          ),
          children: <Widget>[child],
        ),
      ),
    );
  }
}
