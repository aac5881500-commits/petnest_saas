import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'booking_care_display.dart';

enum BookingDetailExperience {
  tabs('五頁分類管理', '預設 · 總覽、照護、帳務、資料、紀錄', Icons.tab_outlined),
  single('單頁完整訂單', '不分頁，區段目錄直達全部資訊', Icons.article_outlined),
  dual('雙頁日常作業', '訂單管理與入住照護，兩個工作區', Icons.view_week_outlined),
  master('主從資料工作台', '電腦左右選閱，手機點入與返回', Icons.view_sidebar_outlined),
  stages('階段展開作業', '依作業階段展開，可同時查看多區', Icons.format_list_numbered);

  const BookingDetailExperience(this.label, this.description, this.icon);
  final String label, description;
  final IconData icon;
}

class AdminBookingDetailExperience extends StatefulWidget {
  const AdminBookingDetailExperience({
    super.key,
    required this.scope,
    required this.sectionBuilder,
    this.alerts = const [],
    this.hasCareDisplay = false,
    this.initialSection = 0,
    this.workflow = false,
    this.worksheetHeader,
    this.worksheetPrimarySection = 0,
  });
  final String scope;
  final Widget Function(
    int index,
    BookingDetailExperience experience,
    BookingCareDisplay careDisplay,
  )
  sectionBuilder;
  final bool hasCareDisplay;
  final bool workflow;
  final Widget? worksheetHeader;
  final int worksheetPrimarySection;
  final int initialSection;
  final List<String> alerts;
  @override
  State<AdminBookingDetailExperience> createState() =>
      AdminBookingDetailExperienceState();
}

class AdminBookingDetailExperienceState
    extends State<AdminBookingDetailExperience> {
  BookingDetailExperience experience = BookingDetailExperience.tabs;
  BookingCareDisplay careDisplay = const BookingCareDisplay();
  late int selected = widget.initialSection;
  late final Set<int> _openSections = {
    widget.initialSection == 0 ? widget.worksheetPrimarySection : widget.initialSection,
  };
  late bool _mobileDetail = selected != 0;
  late final Set<int> _visited = {0, selected};
  final Set<int> _expanded = {0};
  final List<GlobalKey> _sections = List.generate(5, (_) => GlobalKey());
  final ScrollController _scroll = ScrollController();
  int _revision = 0;
  Future<void> _saving = Future.value();
  static const labels = ['訂單總覽', '寵物照護', '帳務收款', '顧客文件', '進度紀錄'];
  static const shortLabels = ['總覽', '照護', '帳務', '資料', '紀錄'];
  static const icons = [
    Icons.space_dashboard_outlined,
    Icons.pets_outlined,
    Icons.receipt_long_outlined,
    Icons.folder_open_outlined,
    Icons.history,
  ];
  static const groups = [
    [0, 2, 3],
    [1, 4],
  ];
  static const stages = [
    [0, 3],
    [1],
    [2],
    [4],
  ];
  static const stageLabels = ['訂單確認與入住準備', '寵物與住宿照護', '收款與退房結算', '留言、交接與歷程'];
  String get _storageKey => 'booking.detail.experience.v2.${widget.scope}';
  String get _careStorageKey =>
      'booking.detail.care-display.v1.${widget.scope}';
  @override
  void initState() {
    super.initState();
    _expanded.add(_stageFor(selected));
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminBookingDetailExperience oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      _revision++;
      experience = BookingDetailExperience.tabs;
      careDisplay = const BookingCareDisplay();
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.scope.isEmpty || widget.workflow) return;
    final version = _revision;
    final key = _storageKey;
    final careKey = _careStorageKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(key);
      if (!mounted || version != _revision) return;
      setState(() {
        experience = BookingDetailExperience.values.firstWhere(
          (item) => item.name == value,
          orElse: () => BookingDetailExperience.tabs,
        );
        careDisplay = BookingCareDisplay.fromStorage(prefs.getString(careKey));
      });
    } catch (_) {
      /* Keep the usable default if storage is unavailable. */
    }
  }

  Future<void> chooseExperience() async {
    final scope = widget.scope;
    final value = await showDialog<Object>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('訂單詳細顯示設定'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '切換整套導覽、頁數與閱讀方式。所有資料與功能保留，偏好儲存在目前裝置。',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (widget.hasCareDisplay) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '照護時程顯示',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final item in BookingCareLayout.values)
                    ListTile(
                      key: ValueKey('choose-care-layout-${item.name}'),
                      leading: Icon(item.icon),
                      title: Text(item.label),
                      subtitle: Text(item.description),
                      trailing: Icon(
                        careDisplay.layout == item
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      onTap: () => Navigator.pop(
                        context,
                        BookingCareDisplay(
                          layout: item,
                          showPhotos: careDisplay.showPhotos,
                        ),
                      ),
                    ),
                  SwitchListTile(
                    key: const ValueKey('care-display-photos'),
                    title: const Text('顯示寵物照片'),
                    value: careDisplay.showPhotos,
                    onChanged: (value) => Navigator.pop(
                      context,
                      BookingCareDisplay(
                        layout: careDisplay.layout,
                        showPhotos: value,
                      ),
                    ),
                  ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '整套訂單詳細介面',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
                for (final item in BookingDetailExperience.values) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      key: ValueKey('choose-experience-${item.name}'),
                      leading: Icon(item.icon),
                      title: Text(item.label),
                      subtitle: Text(item.description),
                      trailing: Icon(
                        experience == item
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      onTap: () => Navigator.pop(context, item),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
    if (!mounted || value == null || widget.scope != scope) return;
    final String key;
    final String stored;
    if (value is BookingCareDisplay) {
      setState(() {
        careDisplay = value;
        _revision++;
      });
      key = _careStorageKey;
      stored = value.storageValue;
    } else if (value is BookingDetailExperience) {
      setState(() {
        experience = value;
        _revision++;
        _mobileDetail = false;
        _expanded.add(_stageFor(selected));
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
      key = _storageKey;
      stored = value.name;
    } else {
      return;
    }
    if (scope.isEmpty) return;
    _saving = _saving.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(key, stored)) {
          throw StateError('not saved');
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('介面已切換，此裝置暫時無法記住偏好。')));
        }
      }
    });
    await _saving;
  }

  int _stageFor(int index) =>
      stages.indexWhere((group) => group.contains(index));
  void select(int index) {
    FocusScope.of(context).unfocus();
    setState(() {
      selected = index;
      _openSections.add(index);
      _visited.add(index);
      _mobileDetail = true;
      _expanded.add(_stageFor(index));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _sections[index].currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 180),
          alignment: 0,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _section(int index, {required bool visible, bool heading = true}) {
    if (visible) _visited.add(index);
    if (!_visited.contains(index)) return const SizedBox.shrink();
    return KeyedSubtree(
      key: _sections[index],
      child: Offstage(
        offstage: !visible,
        child: TickerMode(
          enabled: visible,
          child: Padding(
            key: ValueKey('detail-section-$index'),
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (heading) ...[
                  Row(
                    children: [
                      Icon(icons[index], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          labels[index],
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                widget.sectionBuilder(index, experience, careDisplay),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(int index, {bool vertical = false}) => TextButton(
    key: ValueKey('booking-tab-$index'),
    onPressed: () => select(index),
    style: TextButton.styleFrom(
      alignment: vertical ? Alignment.centerLeft : Alignment.center,
      backgroundColor: selected == index
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    ),
    child: vertical
        ? Row(
            children: [
              Icon(icons[index], size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(labels[index])),
            ],
          )
        : Text(
            shortLabels[index],
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
  );

  Widget _worksheet() => LayoutBuilder(
    builder: (context, bounds) {
      final wide = bounds.maxWidth >= 850;
      final colors = Theme.of(context).colorScheme;
      const labels = ['入住與交接', '住宿照護', '退房與帳務', '飼主與表單', '操作紀錄'];
      Widget section(int index) {
        final open = _openSections.contains(index);
        return Card(
          key: ValueKey('worksheet-section-$index'),
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                key: ValueKey('booking-tab-$index'),
                selected: open,
                selectedTileColor: colors.primaryContainer.withValues(alpha: .45),
                leading: Icon(icons[index]),
                title: Text(labels[index], style: const TextStyle(fontWeight: FontWeight.w800)),
                trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
                onTap: open
                    ? () => setState(() => _openSections.remove(index))
                    : () => select(index),
              ),
              if (open) const Divider(height: 1),
              Padding(
                padding: open ? const EdgeInsets.fromLTRB(14, 14, 14, 0) : EdgeInsets.zero,
                child: _section(index, visible: open, heading: false),
              ),
            ],
          ),
        );
      }

      return Scrollbar(
        controller: _scroll,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.all(wide ? 24 : 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  widget.worksheetHeader!,
                  if (widget.alerts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final alert in widget.alerts)
                            ActionChip(
                              avatar: const Icon(Icons.info_outline, size: 16),
                              label: Text(alert),
                              onPressed: () => select(alert.contains('交接') ? 4 : 1),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  section(widget.worksheetPrimarySection),
                  for (var i = 0; i < labels.length; i++)
                    if (i != widget.worksheetPrimarySection) section(i),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _workflow() => LayoutBuilder(
    builder: (context, bounds) {
      final desktop = bounds.maxWidth >= 1050;
      final colors = Theme.of(context).colorScheme;
      const labels = ['入住', '照護', '結帳', '資料', '紀錄'];

      Widget destination(int index) {
        final active = selected == index;
        return Semantics(
          selected: active,
          child: TextButton(
            key: ValueKey('booking-tab-$index'),
            onPressed: () => select(index),
            style: TextButton.styleFrom(
              backgroundColor: active ? colors.primaryContainer : null,
              foregroundColor: active ? colors.onPrimaryContainer : colors.onSurfaceVariant,
              padding: EdgeInsets.symmetric(horizontal: desktop ? 14 : 2, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: desktop
                ? Row(
                    children: [
                      Icon(icons[index], size: 20),
                      const SizedBox(width: 10),
                      Flexible(child: Text(labels[index])),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icons[index], size: 19),
                      const SizedBox(height: 4),
                      Text(labels[index], textAlign: TextAlign.center),
                    ],
                  ),
          ),
        );
      }

      final body = Scrollbar(
        controller: _scroll,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(desktop ? 26 : 12, 18, desktop ? 26 : 12, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    const ['入住與接待', '照護工作', '結帳與費用', '訂單資料', '操作紀錄'][selected],
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  if (selected == 0 && widget.alerts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final alert in widget.alerts)
                            ActionChip(
                              avatar: const Icon(Icons.info_outline, size: 16),
                              label: Text(alert),
                              onPressed: () => select(alert.contains('交接') ? 4 : 1),
                            ),
                        ],
                      ),
                    ),
                  for (var i = 0; i < labels.length; i++)
                    _section(i, visible: selected == i, heading: false),
                ],
              ),
            ),
          ),
        ),
      );

      if (desktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: colors.surface,
              child: SizedBox(
                width: 148,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: destination(i),
                      ),
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 1, color: colors.outlineVariant),
            Expanded(child: body),
          ],
        );
      }
      return Column(
        children: [
          Material(
            color: colors.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(child: destination(i)),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(child: body),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => widget.worksheetHeader != null
      ? _worksheet()
      : widget.workflow ? _workflow() : LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 1024;
      final master = experience == BookingDetailExperience.master;
      final group = groups.indexWhere((items) => items.contains(selected));
      final showMenuOnly = master && !desktop && !_mobileDetail;
      Widget contents;
      switch (experience) {
        case BookingDetailExperience.single:
          contents = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (var i = 0; i < 5; i++) _section(i, visible: true)],
          );
        case BookingDetailExperience.dual:
          contents = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final id in groups[group]) _section(id, visible: true),
              for (final id in groups[1 - group]) _section(id, visible: false),
            ],
          );
        case BookingDetailExperience.tabs:
          contents = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < 5; i++) _section(i, visible: selected == i),
            ],
          );
        case BookingDetailExperience.master:
          contents = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showMenuOnly) ...[
                const Text(
                  '選擇要查看的訂單資料',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < 5; i++)
                  Card(
                    child: ListTile(
                      key: ValueKey('master-item-$i'),
                      leading: Icon(icons[i]),
                      title: Text(labels[i]),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => select(i),
                    ),
                  ),
              ],
              if (!desktop && _mobileDetail)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('master-back'),
                    onPressed: () => setState(() => _mobileDetail = false),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('返回資料清單'),
                  ),
                ),
              for (var i = 0; i < 5; i++)
                _section(i, visible: !showMenuOnly && selected == i),
            ],
          );
        case BookingDetailExperience.stages:
          contents = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var step = 0; step < stages.length; step++)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE4E7EE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        key: ValueKey('stage-$step'),
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text('${step + 1}'),
                        ),
                        title: Text(
                          stageLabels[step],
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        trailing: Icon(
                          _expanded.contains(step)
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        onTap: () => setState(() {
                          if (!_expanded.add(step)) _expanded.remove(step);
                        }),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: desktop ? 18 : 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final id in stages[step])
                              _section(id, visible: _expanded.contains(step)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
      }
      final scrollable = Scrollbar(
        controller: _scroll,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.all(desktop ? 20 : 12),
          child: contents,
        ),
      );
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1680),
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(experience.icon, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        experience.label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: '訂單操作',
                      onPressed: () => select(0),
                      icon: const Icon(Icons.task_alt),
                    ),
                    IconButton(
                      key: const ValueKey('booking-layout-settings'),
                      tooltip: '選擇整套訂單介面',
                      onPressed: chooseExperience,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
              ),
              if (widget.alerts.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF4E4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Wrap(
                    spacing: 12,
                    children: [
                      for (final alert in widget.alerts)
                        TextButton.icon(
                          onPressed: () => select(alert.contains('交接') ? 4 : 1),
                          icon: const Icon(Icons.info_outline, size: 17),
                          label: Text(alert),
                        ),
                    ],
                  ),
                ),
              if (experience == BookingDetailExperience.single)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('跳至'),
                      ),
                      for (var i = 0; i < 5; i++)
                        TextButton.icon(
                          onPressed: () => select(i),
                          icon: const Icon(Icons.south, size: 14),
                          label: Text(labels[i]),
                        ),
                    ],
                  ),
                ),
              if (experience == BookingDetailExperience.tabs)
                Row(
                  children: [
                    for (var i = 0; i < 5; i++) Expanded(child: _button(i)),
                  ],
                ),
              if (experience == BookingDetailExperience.dual)
                Row(
                  children: [
                    for (var g = 0; g < 2; g++)
                      Expanded(
                        child: TextButton(
                          key: ValueKey('detail-group-$g'),
                          onPressed: () => select(groups[g].first),
                          style: TextButton.styleFrom(
                            backgroundColor: group == g
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            minimumSize: const Size(0, 48),
                          ),
                          child: Text(g == 0 ? '訂單管理' : '入住照護'),
                        ),
                      ),
                  ],
                ),
              Expanded(
                child: master && desktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 200,
                            child: ColoredBox(
                              color: Colors.white,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    for (var i = 0; i < 5; i++)
                                      _button(i, vertical: true),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(child: scrollable),
                        ],
                      )
                    : scrollable,
              ),
            ],
          ),
        ),
      );
    },
  );
}
