import 'package:petnest_saas/features/admin/widgets/admin_booking_order_workspace.dart';
// 檔案名稱：lib/features/admin/widgets/admin_booking_detail_layout.dart
// 功能說明：店主端住宿／安親訂單詳細共用響應式版型：依可用寬度切桌面／平板／手機

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/booking_pet_care_form_loader.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_form_focus.dart';
import 'package:petnest_saas/features/admin/widgets/settlement_next_action_view.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_care_scope.dart';

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
    this.phoneInlineActions,
    this.phoneStickyActions,
    this.desktopStickyActions,
    this.splitPhoneActions = false,
    this.handover,
    this.handoverHasContent = false,
    this.forms = const <Widget>[],
    this.formSummary,
    this.communication = const <Widget>[],
    this.progress,
    this.petCareFuture,
    this.workspace,
    this.onClose,
    this.paneToggle,
  });

  final String title;
  final String bookingCode;
  final Widget overview;
  final Widget? actions;
  final List<Widget> banners;
  final List<Widget> left;
  final List<Widget> right;
  final List<Widget> appBarActions;
  final Widget? phoneInlineActions;
  final Widget? phoneStickyActions;
  final Widget? desktopStickyActions;
  final bool splitPhoneActions;
  final Widget? handover;
  final bool handoverHasContent;
  final List<Widget> forms;
  final Widget? formSummary;
  final List<Widget> communication;
  final Widget? progress;
  final Future<List<BookingPetCareFormItem>>? petCareFuture;
  final AdminBookingWorkspaceContent? workspace;
  final VoidCallback? onClose;
  final Widget? paneToggle;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final AdminBookingDetailMode mode = AdminBookingDetailMetrics.modeFor(
          width,
        );
        final bool phone = mode == AdminBookingDetailMode.phone;
        final Widget? inlineActions =
            (phone ||
                    (workspace != null &&
                        !(mode == AdminBookingDetailMode.desktop))) &&
                splitPhoneActions
            ? phoneInlineActions
            : actions;
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
              automaticallyImplyLeading: onClose == null,
              leading: onClose == null
                  ? null
                  : IconButton(
                      tooltip: '關閉訂單',
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
              title: Row(
                children: [
                  if (paneToggle != null) ...[
                    paneToggle!,
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: _AppBarTitle(title: title, bookingCode: bookingCode),
                  ),
                ],
              ),
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
            body: _DetailBody(
              mode: mode,
              width: width,
              banners: banners,
              overview: overview,
              actions: inlineActions,
              left: left,
              right: right,
              handover: handover,
              handoverHasContent: handoverHasContent,
              forms: forms,
              formSummary: formSummary,
              communication: communication,
              progress: progress,
              petCareFuture: petCareFuture,
              workspace: workspace,
            ),
            bottomNavigationBar:
                (phone ||
                    (workspace != null &&
                        mode != AdminBookingDetailMode.desktop))
                ? phoneStickyActions
                : desktopStickyActions,
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

class _DetailBody extends StatefulWidget {
  const _DetailBody({
    required this.mode,
    required this.width,
    required this.banners,
    required this.overview,
    required this.actions,
    required this.left,
    required this.right,
    required this.handover,
    required this.handoverHasContent,
    required this.forms,
    this.formSummary,
    required this.communication,
    this.progress,
    this.petCareFuture,
    this.workspace,
  });

  final AdminBookingDetailMode mode;
  final double width;
  final List<Widget> banners;
  final Widget overview;
  final Widget? actions;
  final List<Widget> left;
  final List<Widget> right;
  final Widget? handover;
  final bool handoverHasContent;
  final List<Widget> forms;
  final Widget? formSummary;
  final List<Widget> communication;
  final Widget? progress;
  final Future<List<BookingPetCareFormItem>>? petCareFuture;
  final AdminBookingWorkspaceContent? workspace;

  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  int _tab = 0;
  final GlobalKey<AdminBookingOrderWorkspaceState> _workspaceKey =
      GlobalKey<AdminBookingOrderWorkspaceState>();
  final Set<AdminBookingFormAnchor> _expanded = <AdminBookingFormAnchor>{};
  final Map<AdminBookingFormAnchor, GlobalKey> _anchorKeys =
      <AdminBookingFormAnchor, GlobalKey>{
        for (final AdminBookingFormAnchor anchor
            in AdminBookingFormAnchor.values)
          anchor: GlobalKey(),
      };
  final GlobalKey _formsSectionKey = GlobalKey();
  final ScrollController _leftScroll = ScrollController();
  final ScrollController _rightScroll = ScrollController();

  @override
  void dispose() {
    _leftScroll.dispose();
    _rightScroll.dispose();
    super.dispose();
  }

  List<Widget> get _leftForSingleColumn {
    if (widget.progress == null) {
      return widget.left;
    }
    return <Widget>[...widget.left, widget.progress!];
  }

  void _focusForm(AdminBookingFormAnchor anchor) {
    if (widget.workspace != null) _workspaceKey.currentState?.showDocuments();
    setState(() {
      _expanded.add(anchor);
      if (widget.mode == AdminBookingDetailMode.phone) {
        _tab = 2;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target =
          _anchorKeys[anchor]?.currentContext ??
          _formsSectionKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.08,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final bool phone = widget.mode == AdminBookingDetailMode.phone;
    final bool desktop = widget.mode == AdminBookingDetailMode.desktop;
    final List<Widget> comm = <Widget>[
      if (widget.handover != null) widget.handover!,
      ...widget.communication,
    ];
    final Widget body = widget.workspace != null
        ? _workspaceBody(comm)
        : phone
        ? _phoneBody(theme: theme, comm: comm)
        : desktop
        ? _desktopBody(theme: theme, comm: comm)
        : _tabletBody(theme: theme, comm: comm);
    return AdminBookingPetCareGate(
      future: widget.petCareFuture,
      child: AdminBookingFormFocusScope(
        requestFocus: _focusForm,
        expanded: Set<AdminBookingFormAnchor>.from(_expanded),
        desktop: desktop && widget.workspace == null,
        anchorKeys: _anchorKeys,
        child: body,
      ),
    );
  }

  Widget _workspaceBody(List<Widget> comm) {
    final List<Widget> finance = widget.right
        .where((Widget item) => item.key != SettlementNextActionView.slotKey)
        .toList();
    final List<Widget> next = widget.right
        .where((Widget item) => item.key == SettlementNextActionView.slotKey)
        .toList();
    return AdminBookingOrderWorkspace(
      key: _workspaceKey,
      content: widget.workspace!,
      overview: widget.overview,
      banners: widget.banners,
      actions: widget.actions is AdminBookingDetailCard
          ? (widget.actions as AdminBookingDetailCard).child
          : widget.actions,
      nextAction: next.isEmpty ? null : next.first,
      finance: finance,
      documents: <Widget>[
        if (widget.formSummary != null) widget.formSummary!,
        if (widget.forms.isNotEmpty)
          Column(
            key: _formsSectionKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _withGaps(widget.forms),
          ),
      ],
      activity: <Widget>[
        if (widget.progress != null) widget.progress!,
        ...comm,
      ],
      handoverHasContent: widget.handoverHasContent,
    );
  }

  Widget _mergedOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        widget.overview,
        if (widget.actions != null) ...<Widget>[
          const SizedBox(height: 8),
          widget.actions!,
        ],
      ],
    );
  }

  Widget _tabletBody({
    required ShopFrontendTheme theme,
    required List<Widget> comm,
  }) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: AdminBookingDetailMetrics.pagePadding(widget.mode),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
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
              ...widget.banners,
              widget.overview,
              if (widget.actions != null) ...<Widget>[
                const SizedBox(height: 12),
                widget.actions!,
              ],
              const SizedBox(height: 16),
              if (AdminBookingDetailMetrics.useTwoColumns(widget.width))
                _TwoColumn(left: _leftForSingleColumn, right: widget.right)
              else
                _SingleColumn(
                  leading: widget.right,
                  trailing: _leftForSingleColumn,
                ),
              if (widget.forms.isNotEmpty) ...<Widget>[
                const SizedBox(height: 20),
                Text(
                  '表單資料',
                  key: _formsSectionKey,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.titleColor,
                  ),
                ),
                const SizedBox(height: 10),
                ..._withGaps(widget.forms),
              ],
              if (comm.isNotEmpty) ...<Widget>[
                const SizedBox(height: 20),
                Text(
                  '交接與溝通',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.titleColor,
                  ),
                ),
                const SizedBox(height: 10),
                ..._withGaps(comm),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  Widget _desktopBody({
    required ShopFrontendTheme theme,
    required List<Widget> comm,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height - kToolbarHeight;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1600),
            child: SizedBox(
              height: height,
              child: Row(
                key: const ValueKey<String>('admin-booking-desktop-split'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: Scrollbar(
                      controller: _leftScroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _leftScroll,
                        padding: AdminBookingDetailMetrics.pagePadding(
                          widget.mode,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
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
                            ...widget.banners,
                            _mergedOverview(),
                            const SizedBox(height: 16),
                            ..._withGaps(widget.left),
                            if (widget.forms.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 20),
                              Text(
                                '表單資料',
                                key: _formsSectionKey,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: theme.titleColor,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ..._withGaps(widget.forms),
                            ],
                            if (comm.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 20),
                              Text(
                                '交接與溝通',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: theme.titleColor,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ..._withGaps(comm),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth * 0.30).clamp(320.0, 400.0),
                    child: Scrollbar(
                      controller: _rightScroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _rightScroll,
                        padding: AdminBookingDetailMetrics.pagePadding(
                          widget.mode,
                        ).copyWith(left: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _withGaps(_desktopAside()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _desktopAside() {
    final List<Widget> right = widget.right;
    final bool hasNext =
        right.isNotEmpty && right.first.key == SettlementNextActionView.slotKey;
    final List<Widget> rest = hasNext ? right.skip(1).toList() : right;
    final int paymentCount = rest.length >= 2 ? 2 : rest.length;
    return <Widget>[
      if (hasNext) right.first,
      ...rest.take(paymentCount),
      if (widget.progress != null) widget.progress!,
      if (widget.formSummary != null) widget.formSummary!,
      ...rest.skip(paymentCount),
    ];
  }

  Widget _phoneBody({
    required ShopFrontendTheme theme,
    required List<Widget> comm,
  }) {
    final Widget orderScroll = CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: AdminBookingDetailMetrics.pagePadding(widget.mode),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              ...widget.banners,
              widget.overview,
              if (widget.actions != null) ...<Widget>[
                const SizedBox(height: 12),
                widget.actions!,
              ],
              const SizedBox(height: 16),
              ..._withGaps(widget.left),
            ]),
          ),
        ),
      ],
    );
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll<EdgeInsets>(
                EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
            segments: <ButtonSegment<int>>[
              const ButtonSegment<int>(value: 0, label: Text('訂單')),
              const ButtonSegment<int>(value: 1, label: Text('進度')),
              const ButtonSegment<int>(value: 4, label: Text('付款')),
              const ButtonSegment<int>(value: 2, label: Text('表單')),
              ButtonSegment<int>(
                value: 3,
                label: const Text('交接'),
                tooltip: widget.handoverHasContent ? '交接與溝通，有內容' : '交接與溝通',
              ),
            ],
            selected: <int>{_tab.clamp(0, 4)},
            onSelectionChanged: (Set<int> next) {
              setState(() => _tab = next.first);
            },
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab.clamp(0, 4),
            children: <Widget>[
              orderScroll,
              ListView(
                padding: AdminBookingDetailMetrics.pagePadding(widget.mode),
                children: widget.progress == null
                    ? const <Widget>[
                        Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Text('目前沒有訂單進度'),
                        ),
                      ]
                    : <Widget>[widget.progress!],
              ),
              ListView(
                padding: AdminBookingDetailMetrics.pagePadding(widget.mode),
                children: widget.forms.isEmpty
                    ? <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Text('此訂單目前沒有可顯示的表單資料'),
                        ),
                      ]
                    : _withGaps(widget.forms),
              ),
              ListView(
                padding: AdminBookingDetailMetrics.pagePadding(widget.mode),
                children: comm.isEmpty
                    ? <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Text('目前沒有交接或溝通內容'),
                        ),
                      ]
                    : _withGaps(comm),
              ),
              ListView(
                key: const PageStorageKey<String>('booking-payment'),
                padding: AdminBookingDetailMetrics.pagePadding(widget.mode),
                children: widget.right.isEmpty
                    ? const <Widget>[Text('目前沒有付款資料')]
                    : _withGaps(widget.right),
              ),
            ],
          ),
        ),
      ],
    );
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
    this.showHeading = true,
  });

  final String title;
  final Widget child;
  final bool collapsible;
  final bool initiallyExpanded;
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final bool phone = AdminBookingDetailScope.of(context).isPhone;
    final bool fold = collapsible && phone;
    if (!showHeading) {
      return child;
    }
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

class AdminBookingDetailGroup extends StatelessWidget {
  const AdminBookingDetailGroup({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.children,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 16),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: theme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
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
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: theme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ..._withGaps(children),
      ],
    );
  }
}
