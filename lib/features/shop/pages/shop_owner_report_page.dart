import 'package:petnest_saas/core/models/owner_cashflow_totals.dart';
import 'package:petnest_saas/features/shop/widgets/owner_cashflow_card.dart';
import 'dart:math' as math;
import 'package:petnest_saas/core/services/owner_report_workspace.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:petnest_saas/features/shop/widgets/owner_finance_widgets.dart';
import 'package:petnest_saas/core/services/owner_finance_export.dart';
import 'package:petnest_saas/core/services/report_downloader_stub.dart'
    if (dart.library.html) 'package:petnest_saas/core/services/report_downloader_web.dart'
    as downloader;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/shop_report_models.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';

/// Private owner ledger. Firestore rules enforce access independently of routing.
class ShopOwnerReportPage extends StatefulWidget {
  const ShopOwnerReportPage({
    super.key,
    required this.shopId,
    this.reportLoader,
    this.ledgerLoader,
    this.moduleLoader,
    this.workspaceLoader,
    this.initialDemo = false,
  });
  final Future<ShopReportBundle> Function(ReportRange)? reportLoader;
  final Stream<QuerySnapshot<Map<String, dynamic>>> Function(String)?
  ledgerLoader;
  final Future<Set<String>> Function()? moduleLoader;
  final Future<Map<String, ShopReportBundle>> Function(
    ReportRange,
    Set<String>,
  )?
  workspaceLoader;
  final bool initialDemo;
  final String shopId;
  @override
  State<ShopOwnerReportPage> createState() => _ShopOwnerReportPageState();
}

class _ShopOwnerReportPageState extends State<ShopOwnerReportPage>
    with SingleTickerProviderStateMixin {
  bool _demo = false, _modulesReady = false;
  bool _demoIncludeReserved = false;
  Object? _moduleError;
  Set<String> _enabledModules = {};
  String _scope = 'all';
  int _demoSequence = 0;
  final Map<String, List<OwnerLedgerEntry>> _demoLedger = {};
  late Future<Map<String, ShopReportBundle>> _workspace;
  Set<String> get _activeModules => _demo
      ? (_demoIncludeReserved
            ? OwnerReportDemo.modules
            : OwnerReportDemo.readyModules)
      : _enabledModules;
  Set<String> get _sources =>
      OwnerReportWorkspace.sources(_activeModules, _scope);
  bool get _scopeReady =>
      (_demo || (_modulesReady && _moduleError == null)) && _sources.isNotEmpty;
  bool get _wholeShop => _scope == 'all';
  bool get _canCalculateBalance =>
      OwnerReportWorkspace.isComplete(_activeModules, _scope);
  Future<void> _loadModules({bool reloadLedger = false}) async {
    try {
      final modules = widget.moduleLoader != null
          ? await widget.moduleLoader!()
          : ShopService.instance
                .effectiveEnabledModules(
                  (await FirebaseFirestore.instance
                              .collection('shops')
                              .doc(widget.shopId)
                              .get())
                          .data() ??
                      {},
                )
                .toSet();
      if (!mounted) return;
      setState(() {
        _enabledModules = modules;
        if (_scope != 'all' &&
            !OwnerReportWorkspace.available(
              modules,
            ).any((source) => source.id == _scope)) {
          _scope = 'all';
        }
        _modulesReady = true;
        _moduleError = null;
        _load(reloadLedger: reloadLedger);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _moduleError = e;
          _modulesReady = true;
          _load(reloadLedger: false);
        });
      }
    }
  }

  void _setDemo(bool value) {
    setState(() {
      _demo = value;
      _scope = 'all';
      _query = '';
      _kind = 'all';
      _load();
    });
    if (!value && !_modulesReady) _loadModules();
  }

  void _setScope(String scope) {
    if (_pageScroll.hasClients) _pageScroll.jumpTo(0);
    setState(() {
      _scope = scope;
      _load(reloadLedger: false);
    });
  }

  Future<Map<String, ShopReportBundle>> _fetchWorkspace(ReportRange range) {
    final selectedSources = _sources;
    if (_demo) {
      return Future.value(OwnerReportDemo.reports(range, selectedSources));
    }
    if (!_scopeReady) {
      return Future.value(
        OwnerReportWorkspace.build(range: range, sources: {}),
      );
    }
    if (widget.workspaceLoader != null) {
      return widget.workspaceLoader!(range, selectedSources);
    }
    if (widget.reportLoader != null) {
      return widget.reportLoader!(range).then(
        (report) => {
          'all': report,
          for (final source in selectedSources) source: report,
        },
      );
    }
    return ShopReportService.instance.loadOwnerModules(
      shopId: widget.shopId,
      range: range,
      sources: selectedSources,
    );
  }

  late final TabController _tabs;
  final _pageScroll = ScrollController(keepScrollOffset: false);
  int _tab = 0;
  static const _tabNames = ['本月總覽', '薪資管理', '收入支出', '營運分析', '完整月報'];
  static const _tabHints = [
    '先看本月成果，再前往薪資與收支完成記帳。',
    '在這裡新增每位員工的當月薪資，並查看已填寫明細。',
    '登記房租、水電、耗材等成本，以及系統以外的其他收入。',
    '查看營運指標、每日收款、熱銷排行與上月比較。',
    '集中檢視已選取的報表區塊，確認本月資料後匯出。',
  ];
  bool get _needsComparison =>
      _tab == 3 || (_tab == 4 && _sections.contains('comparison'));
  void _selectTab(int index) {
    if (_pageScroll.hasClients) _pageScroll.jumpTo(0);
    setState(() {
      _tab = index;
      _tabs.index = index;
      _query = '';
      _kind = 'all';
    });
    if (_needsComparison && _previous == null) _loadPrevious();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _pageScroll.dispose();
    super.dispose();
  }

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<ShopReportBundle> _report;
  late Stream<List<OwnerLedgerEntry>> _ledger;
  static const _panelGroups = <String, List<String>>{
    '彙總與圖表': ['modules', 'summary', 'charts', 'comparison'],
    '營運明細': ['operations', 'daily', 'ranking'],
    '成本與記帳': ['salary', 'costs', 'ledger'],
  };
  static const _panels = <String, String>{
    'modules': '各服務項目收入比較',
    'summary': '收入與結餘摘要',
    'charts': '收入／成本圓環圖',
    'operations': '訂單與營運指標',
    'salary': '員工薪資明細',
    'costs': '成本分析與提醒',
    'daily': '每日收款統計',
    'ranking': '房型與加購排行',
    'comparison': '與上月比較',
    'ledger': '收支記帳明細',
  };
  final Set<String> _sections = {
    'modules',
    'summary',
    'charts',
    'operations',
    'salary',
    'costs',
    'ledger',
  };
  Future<ShopReportBundle>? _previous;
  String _query = '', _kind = 'all';
  bool _descending = true, _exporting = false;
  String get _settingsKey => 'owner_report_panels_v1_${widget.shopId}';
  String get _monthKey => DateFormat('yyyy-MM').format(_month);
  CollectionReference<Map<String, dynamic>> get _entries => FirebaseFirestore
      .instance
      .collection('shops')
      .doc(widget.shopId)
      .collection('owner_finance_months')
      .doc(_monthKey)
      .collection('entries');
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _demo = widget.initialDemo;
    _load();
    _restorePanels();
    if (!_demo) _loadModules();
  }

  void _setDemoScenario(bool reserved) {
    setState(() {
      _demoIncludeReserved = reserved;
      _scope = 'all';
      _load(reloadLedger: false);
    });
  }

  Future<void> _applyPreset(bool full) async {
    setState(() {
      _sections.clear();
      _sections.addAll(
        full ? _panels.keys : ['summary', 'salary', 'costs', 'ledger'],
      );
    });
    if (_needsComparison && _previous == null) _loadPrevious();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_settingsKey, _sections.toList());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('本次設定已套用，裝置儲存失敗。')));
      }
    }
  }

  Future<void> _restorePanels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_settingsKey);
      if (saved != null && mounted) {
        setState(() {
          _sections.clear();
          _sections.addAll(saved.where(_panels.containsKey));
        });
        if (_needsComparison) _loadPrevious();
      }
    } catch (_) {
      /* Display preferences do not block financial data. */
    }
  }

  Future<void> _togglePanel(String key, bool enabled) async {
    setState(() {
      if (enabled) {
        _sections.add(key);
      } else {
        _sections.remove(key);
      }
    });
    if (key == 'comparison' &&
        enabled &&
        _needsComparison &&
        _previous == null) {
      _loadPrevious();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_settingsKey, _sections.toList());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('本次顯示設定已套用，但無法儲存到此裝置。')));
      }
    }
  }

  void _loadPrevious() {
    final start = DateTime(_month.year, _month.month - 1);
    final range = ReportRange(
      type: ReportRangeType.custom,
      startDate: start,
      endDate: _month.subtract(const Duration(milliseconds: 1)),
    );
    final scope = _scope;
    setState(() {
      _previous = _fetchWorkspace(
        range,
      ).then((reports) => reports[scope] ?? reports['all']!);
    });
    _previous!.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
  }

  Future<void> _configure() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .78,
            child: Column(
              children: [
                ListTile(
                  title: const Text('自訂完整月報'),
                  subtitle: const Text('這些開關只調整「完整月報」內容，不會隱藏薪資或記帳入口。設定保存在此裝置。'),
                  trailing: IconButton(
                    tooltip: '完成',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                _applyPreset(false);
                                update(() {});
                              },
                              child: const Text('只看收支'),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                _applyPreset(true);
                                update(() {});
                              },
                              child: const Text('全部顯示'),
                            ),
                          ],
                        ),
                      ),
                      if (_demo) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '示範情境',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('完整營運（住宿＋日托＋商城）'),
                                selected: !_demoIncludeReserved,
                                onSelected: (_) {
                                  _setDemoScenario(false);
                                  update(() {});
                                },
                              ),
                              ChoiceChip(
                                label: const Text('含統計準備中項目'),
                                selected: _demoIncludeReserved,
                                onSelected: (_) {
                                  _setDemoScenario(true);
                                  update(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          '資料來源・依已開啟模板',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('整店'),
                              selected: _scope == 'all',
                              onSelected: (_) {
                                _setScope('all');
                                update(() {});
                              },
                            ),
                            for (final source in OwnerReportWorkspace.available(
                              _activeModules,
                            ))
                              ChoiceChip(
                                label: Text(
                                  '${source.label}${source.ready ? '' : '・統計準備中'}',
                                ),
                                selected: _scope == source.id,
                                onSelected: (_) {
                                  _setScope(source.id);
                                  update(() {});
                                },
                              ),
                          ],
                        ),
                      ),
                      for (final group in _panelGroups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                          child: Text(
                            group.key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        for (final key in group.value)
                          SwitchListTile(
                            title: Text(_panels[key]!),
                            value: _sections.contains(key),
                            onChanged: (value) {
                              _togglePanel(key, value);
                              update(() {});
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _export(List<Map<String, dynamic>> entries) async {
    final month = _monthKey;
    final currentReport = _report;
    final demoExport = _demo, fullShop = _canCalculateBalance;
    final sourceLabel = OwnerReportWorkspace.label(_scope);
    setState(() => _exporting = true);
    try {
      ShopReportBundle? report;
      try {
        report = await currentReport;
      } catch (_) {
        /* Export marks system data unavailable. */
      }
      final bytes = OwnerFinanceExport.build(
        month: month,
        entries: entries,
        report: report,
        isDemo: demoExport,
        sourceLabel: sourceLabel,
        includeBalance: fullShop,
      );
      await downloader.downloadExcelFile(
        bytes: bytes,
        fileName:
            '${demoExport ? '示範_' : ''}PetNest_${sourceLabel}_老闆月報_$month.xlsx',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('匯出失敗，請使用 Web 版重試。')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _comparison(ShopReportBundle current) =>
      FutureBuilder<ShopReportBundle>(
        future: _previous,
        builder: (context, snapshot) => OwnerReportSection(
          title: '月度比較',
          subtitle: '本月與上一個完整月份的系統資料比較；當月未結束時，不能視為同期成長率。',
          child: snapshot.hasError
              ? TextButton(
                  onPressed: _loadPrevious,
                  child: const Text('上月資料讀取失敗，按此重試'),
                )
              : !snapshot.hasData ||
                    snapshot.connectionState == ConnectionState.waiting
              ? const LinearProgressIndicator()
              : Wrap(
                  spacing: 24,
                  runSpacing: 20,
                  children: [
                    _difference(
                      '系統淨實收',
                      current.revenueKpi.paidAmount,
                      snapshot.data!.revenueKpi.paidAmount,
                    ),
                    _difference(
                      '有效訂單',
                      current.overview.orders,
                      snapshot.data!.overview.orders,
                      money: false,
                    ),
                    _difference(
                      '訂單金額',
                      current.revenueKpi.orderAmount,
                      snapshot.data!.revenueKpi.orderAmount,
                    ),
                  ],
                ),
        ),
      );
  Widget _difference(
    String label,
    int current,
    int previous, {
    bool money = true,
  }) => SizedBox(
    width: 260,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          '本月 ${money ? ownerMoney(current) : current} ／上月 ${money ? ownerMoney(previous) : previous}',
        ),
        Text(
          '差額 ${money ? ownerMoney(current - previous) : current - previous}  ·  ${previous <= 0 ? '上月無基準，不計成長率' : '${((current - previous) / previous * 100).toStringAsFixed(1)}%'}',
        ),
      ],
    ),
  );
  void _load({bool reloadLedger = true}) {
    if (reloadLedger) {
      _ledger = _demo
          ? Stream.value(
              _demoLedger.putIfAbsent(
                _monthKey,
                () => OwnerReportDemo.ledger(_month),
              ),
            )
          : (widget.ledgerLoader?.call(_monthKey) ?? _entries.snapshots()).map(
              (snapshot) =>
                  snapshot.docs.map(OwnerLedgerEntry.fromDoc).toList(),
            );
    }
    final range = ReportRange(
      type: ReportRangeType.custom,
      startDate: _month,
      endDate: DateTime(
        _month.year,
        _month.month + 1,
        1,
      ).subtract(const Duration(milliseconds: 1)),
    );
    _previous = null;
    if (_needsComparison) _loadPrevious();
    final scope = _scope;
    _workspace = _fetchWorkspace(range);
    _report = _workspace.then((reports) => reports[scope] ?? reports['all']!);
    _report.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
  }

  void _changeMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
    _load();
  });
  String _label(String kind) => switch (kind) {
    'salary' => '員工薪資',
    'income' => '其他收入',
    _ => '營運支出',
  };
  String _ledgerError(Object? error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => '私人收支存取遭拒，請確認使用老闆帳號，並請管理者更新收支存取權限。',
        'unauthenticated' => '登入已失效，請重新登入後再讀取收支。',
        'unavailable' => '暫時無法連線，請確認網路後重試。',
        _ => '私人收支讀取失敗（${error.code}），請稍後重試。',
      };
    }
    return '私人收支讀取失敗，請稍後重試。';
  }

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('操作失敗，請確認網路與老闆權限後重試。')));
    }
  }

  Future<void> _edit([
    OwnerLedgerEntry? doc,
    String initialKind = 'salary',
  ]) async {
    final demoEdit = _demo;
    final monthKey = _monthKey;
    final collection = demoEdit ? null : _entries;
    final data = doc?.data() ?? {};
    final name = TextEditingController(text: data['name'] as String? ?? '');
    final amount = TextEditingController(
      text: data['amount']?.toString() ?? '',
    );
    final note = TextEditingController(text: data['note'] as String? ?? '');
    final payrollFields = {
      for (final label in ['本薪', '加班費', '獎金', '津貼', '扣款'])
        label: TextEditingController(),
    };
    var kind = data['kind'] as String? ?? initialKind;
    final form = GlobalKey<FormState>();
    var saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(
              '${demoEdit ? '示範・' : ''}${doc == null ? '新增' : '編輯'} $_monthKey 收支',
            ),
            content: SizedBox(
              width: 420,
              child: Form(
                key: form,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: kind,
                        decoration: const InputDecoration(labelText: '類別'),
                        items: ['salary', 'expense', 'income']
                            .map(
                              (k) => DropdownMenuItem(
                                value: k,
                                child: Text(_label(k)),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (v) => update(() => kind = v!),
                      ),
                      if (kind == 'expense')
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: '常用支出項目（也可自行輸入）',
                          ),
                          items:
                              [
                                    '房租',
                                    '水電',
                                    '耗材飼料',
                                    '清潔消毒',
                                    '廣告行銷',
                                    '保險',
                                    '稅費',
                                    '設備維修',
                                    '其他支出',
                                  ]
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v),
                                    ),
                                  )
                                  .toList(),
                          onChanged: saving ? null : (v) => name.text = v!,
                        ),
                      TextFormField(
                        controller: name,
                        enabled: !saving,
                        maxLength: 80,
                        decoration: InputDecoration(
                          labelText: kind == 'salary'
                              ? '員工姓名'
                              : '項目名稱（房租、水電、耗材等）',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? '請填寫名稱' : null,
                      ),
                      TextFormField(
                        controller: amount,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: '金額（新台幣整數）',
                          helperText: '輸入正整數，依收入／支出類別自動加減。',
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null || n <= 0 || n > 999999999
                              ? '請輸入 1～999,999,999 元'
                              : null;
                        },
                      ),
                      if (kind == 'salary')
                        ExpansionTile(
                          title: const Text('薪資試算（選填）'),
                          subtitle: const Text('本薪＋加班＋獎金＋津貼－扣款'),
                          children: [
                            const Text(
                              '試算後套用到金額，組成寫入備註。不自動計算勞健保或稅額；雇主負擔請另記支出。',
                            ),
                            for (final field in payrollFields.entries)
                              TextFormField(
                                controller: field.value,
                                enabled: !saving,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  labelText: field.key,
                                ),
                                validator: (v) =>
                                    v != null &&
                                        v.isNotEmpty &&
                                        (int.tryParse(v) == null ||
                                            int.parse(v) > 999999999)
                                    ? '金額超出上限'
                                    : null,
                              ),
                            TextButton(
                              onPressed: saving
                                  ? null
                                  : () {
                                      final values = {
                                        for (final e in payrollFields.entries)
                                          e.key:
                                              int.tryParse(e.value.text) ?? 0,
                                      };
                                      final sum =
                                          values['本薪']! +
                                          values['加班費']! +
                                          values['獎金']! +
                                          values['津貼']! -
                                          values['扣款']!;
                                      if (sum <= 0 || sum > 999999999) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '試算結果須為 1～999,999,999 元',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      final breakdown = values.entries
                                          .map((e) => '${e.key} ${e.value}')
                                          .join('／');
                                      // Keep existing notes intact; never silently truncate payroll information.
                                      final nextNote = note.text.isEmpty
                                          ? breakdown
                                          : '${note.text}\n$breakdown';
                                      if (nextNote.length > 300) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('備註空間不足，請先整理備註再套用'),
                                          ),
                                        );
                                        return;
                                      }
                                      amount.text = '$sum';
                                      note.text = nextNote;
                                    },
                              child: const Text('套用試算到金額與備註'),
                            ),
                          ],
                        ),
                      TextFormField(
                        controller: note,
                        enabled: !saving,
                        maxLength: 300,
                        decoration: const InputDecoration(
                          labelText: '備註（薪資組成、付款日期等）',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        update(() => saving = true);
                        try {
                          final value = <String, dynamic>{
                            'kind': kind,
                            'name': name.text.trim(),
                            'amount': int.parse(amount.text),
                            'note': note.text.trim(),
                            'updatedAt': demoEdit
                                ? Timestamp.now()
                                : FieldValue.serverTimestamp(),
                          };
                          if (demoEdit) {
                            final rows = _demoLedger[monthKey]!;
                            final entry = OwnerLedgerEntry(
                              id: doc?.id ?? 'demo-new-${_demoSequence++}',
                              value: value,
                            );
                            final index = rows.indexWhere(
                              (e) => e.id == doc?.id,
                            );
                            if (index < 0) {
                              rows.add(entry);
                            } else {
                              rows[index] = entry;
                            }
                            if (mounted) setState(_load);
                          } else {
                            await (doc == null
                                    ? collection!.doc()
                                    : collection!.doc(doc.id))
                                .set(value);
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (e) {
                          _error(e);
                          if (dialogContext.mounted) {
                            update(() => saving = false);
                          }
                        }
                      },
                child: Text(saving ? '儲存中…' : '儲存'),
              ),
            ],
          ),
        ),
      ),
    );
    // Wait for the dialog closing animation before disposing field controllers.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    name.dispose();
    amount.dispose();
    note.dispose();
    for (final field in payrollFields.values) {
      field.dispose();
    }
  }

  Future<void> _delete(OwnerLedgerEntry doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除這筆收支？'),
        content: Text('${doc.data()['name']}，刪除後無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        if (_demo) {
          _demoLedger[_monthKey]!.removeWhere((entry) => entry.id == doc.id);
          if (mounted) setState(_load);
        } else {
          await doc.reference!.delete();
        }
      } catch (e) {
        _error(e);
      }
    }
  }

  Widget _metric(String label, int amount, {bool money = true, int flow = 0}) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width:
                (math.min(MediaQuery.sizeOf(context).width, 1440) - 32) /
                    (MediaQuery.sizeOf(context).width < 600
                        ? 2
                        : MediaQuery.sizeOf(context).width < 1100
                        ? 3
                        : 6) -
                72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    money
                        ? ownerSignedMoney(amount, direction: flow)
                        : '$amount 人',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: flow < 0
                          ? const Color(0xffb34c43)
                          : flow > 0
                          ? const Color(0xff197b58)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  Widget _salarySummary(List<OwnerLedgerEntry> docs) {
    final groups = ownerGroupAmounts(
      docs.map((d) => d.data()).toList(),
      'salary',
    );
    final total = groups.values.fold<int>(0, (a, b) => a + b);
    return OwnerReportSection(
      title: '員工薪資明細',
      subtitle: '同名員工多筆薪資合併；下方原始紀錄可個別編輯。',
      child: groups.isEmpty
          ? const Text('尚未填寫薪資，請按上方「新增員工薪資」。')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('員工姓名')),
                  DataColumn(label: Text('本月合計')),
                  DataColumn(label: Text('薪資占比')),
                ],
                rows: groups.entries
                    .map(
                      (e) => DataRow(
                        cells: [
                          DataCell(Text(e.key)),
                          DataCell(
                            Text(ownerSignedMoney(e.value, direction: -1)),
                          ),
                          DataCell(
                            Text(
                              '${(e.value / total * 100).toStringAsFixed(1)}%',
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }

  Widget _entryList(List<OwnerLedgerEntry> docs, bool ready) {
    final scope = docs
        .where(
          (d) => _tab == 1
              ? d.data()['kind'] == 'salary'
              : _tab == 2
              ? d.data()['kind'] != 'salary'
              : true,
        )
        .toList();
    final filtered =
        scope.where((d) {
          final data = d.data();
          return (_kind == 'all' || data['kind'] == _kind) &&
              '${data['name']} ${data['note']}'.toLowerCase().contains(
                _query.toLowerCase(),
              );
        }).toList()..sort(
          (a, b) => _descending
              ? (b.data()['amount'] as num).compareTo(a.data()['amount'] as num)
              : (a.data()['amount'] as num).compareTo(
                  b.data()['amount'] as num,
                ),
        );
    return OwnerReportSection(
      title: _tab == 1 ? '薪資記錄與編輯' : '收支記帳明細',
      subtitle: '搜尋與分類只篩選明細，不改變全月統計或 Excel 匯出範圍。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: ValueKey('entry-search-$_tab'),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: _tab == 1 ? '搜尋員工姓名或薪資備註' : '搜尋項目或備註',
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (_tab != 1)
                for (final kind
                    in (_tab == 2
                        ? ['all', 'expense', 'income']
                        : ['all', 'salary', 'expense', 'income']))
                  ChoiceChip(
                    label: Text(kind == 'all' ? '全部' : _label(kind)),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ActionChip(
                avatar: const Icon(Icons.sort, size: 16),
                label: Text(_descending ? '金額由高到低' : '金額由低到高'),
                onPressed: () => setState(() => _descending = !_descending),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!ready)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('私人資料尚未載入，暫時無法查看或修改明細。'),
            ),
          if (ready && scope.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_tab == 1 ? '這個月尚未新增員工薪資。' : '這個月尚無手動紀錄，請新增營運收支。'),
            ),
          if (ready && scope.isNotEmpty && filtered.isEmpty)
            const Text('沒有符合篩選的紀錄'),
          for (final doc in filtered)
            Card(
              child: ListTile(
                title: Text(
                  '${doc.data()['name']}　${ownerSignedMoney(doc.data()['amount'] as num, direction: doc.data()['kind'] == 'income' ? 1 : -1)}',
                ),
                subtitle: Text(
                  '${_label(doc.data()['kind'] as String)}${(doc.data()['note'] as String? ?? '').isEmpty ? '' : '\n${doc.data()['note']}'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '編輯',
                      onPressed: () => _edit(doc),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: '刪除',
                      onPressed: () => _delete(doc),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shortcut(String title, String subtitle, IconData icon, int index) =>
      SizedBox(
        width: 290,
        child: Card(
          child: ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectTab(index),
          ),
        ),
      );
  Widget _workspaceControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('正式資料'),
                icon: Icon(Icons.cloud_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('示範資料'),
                icon: Icon(Icons.science_outlined),
              ),
            ],
            selected: {_demo},
            onSelectionChanged: (values) => _setDemo(values.single),
          ),
          SizedBox(
            width: 310,
            child: DropdownButtonFormField<String>(
              key: ValueKey(
                'business-$_demo-$_modulesReady-${_activeModules.join(',')}',
              ),
              initialValue: _scope,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '系統收入來源',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(OwnerReportWorkspace.label('all')),
                ),
                for (final source in OwnerReportWorkspace.available(
                  _activeModules,
                ))
                  DropdownMenuItem(
                    value: source.id,
                    child: Text(
                      '${source.label}${source.ready ? '' : '（統計準備中）'}',
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) _setScope(value);
              },
            ),
          ),
          Text(
            _tab == 1 || _tab == 2 ? '薪資／手動收支維持整店記帳' : '已啟用模板分開統計，統計準備中不列入合計',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      if (_demo)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xfffff2cf),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('示範模式：全部為虛構資料。可試填薪資與收支，只暫存本畫面；匯出也會標示示範，不寫入正式資料。'),
        ),
    ],
  );
  Widget _businessComparison() => FutureBuilder<Map<String, ShopReportBundle>>(
    future: _workspace,
    builder: (context, snapshot) {
      if (!snapshot.hasData ||
          snapshot.hasError ||
          snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox.shrink();
      }
      final reports = snapshot.data!,
          sources = OwnerReportWorkspace.available(_activeModules);
      return OwnerReportSection(
        title: '各服務項目收入比較',
        subtitle: '只彙總已啟用且可統計的系統訂單及收款。統計準備中的服務項目不當作 0 元；整店薪資與共用成本尚未分攤。',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_tab == 0 || _sections.contains('charts'))
              OwnerDonut(
                title: '各服務項目淨實收占比',
                caption: '可點圖例查看不同服務項目，不含手動其他收入。',
                values: {
                  for (final source in sources)
                    if (reports[source.id] != null)
                      source.label: reports[source.id]!.revenueKpi.paidAmount,
                },
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('服務項目')),
                  DataColumn(label: Text('統計狀態')),
                  DataColumn(label: Text('訂單金額')),
                  DataColumn(label: Text('淨實收')),
                  DataColumn(label: Text('未收款')),
                ],
                rows: sources.map((source) {
                  final report = reports[source.id];
                  return DataRow(
                    cells: [
                      DataCell(Text(source.label)),
                      DataCell(Text(source.ready ? '可統計' : '統計準備中')),
                      DataCell(
                        Text(
                          report == null
                              ? '—'
                              : ownerMoney(report.revenueKpi.orderAmount),
                        ),
                      ),
                      DataCell(
                        Text(
                          report == null
                              ? '—'
                              : ownerMoney(report.revenueKpi.paidAmount),
                        ),
                      ),
                      DataCell(
                        Text(
                          report == null
                              ? '—'
                              : ownerMoney(report.revenueKpi.unpaidAmount),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _manualTotals(
    int salary,
    int expense,
    int income,
    List<OwnerLedgerEntry> docs,
  ) => OwnerReportSection(
    title: _tab == 1
        ? '本月薪資摘要'
        : _tab == 2
        ? '本月手動收支'
        : '整店已填收支（未分攤）',
    subtitle: '依已填寫資料合計；未填成本不會自動估算。',
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metric('員工薪資合計', salary, flow: -1),
        if (_tab == 1)
          _metric(
            '已填薪資人數',
            ownerGroupAmounts(
              docs.map((d) => d.data()).toList(),
              'salary',
            ).length,
            money: false,
          ),
        if (_tab != 1) ...[
          _metric('其他支出合計', expense, flow: -1),
          _metric('手動其他收入', income, flow: 1),
          _metric('支出總計（含薪資）', salary + expense, flow: -1),
        ],
      ],
    ),
  );
  Widget _cashflowSummary(
    ShopReportBundle report,
    List<OwnerLedgerEntry> docs,
    bool ready,
  ) {
    if (!_wholeShop) {
      return OwnerReportSection(
        title: '整店收支總結',
        subtitle: '單一服務項目尚未分攤整店薪資與支出。',
        child: TextButton(
          onPressed: () => _setScope('all'),
          child: const Text('切回整店查看總收入與結餘'),
        ),
      );
    }
    return OwnerCashflowCard(
      totals: OwnerCashflowTotals.fromEntries(
        report.revenueKpi.paidAmount,
        docs.map((e) => e.data()).toList(),
      ),
      complete: _canCalculateBalance,
      privateReady: ready,
    );
  }

  Widget _reportContent(
    List<OwnerLedgerEntry> docs,
    bool ready,
    int salary,
    int expense,
    int income,
  ) => !_scopeReady
      ? OwnerReportSection(
          title: _modulesReady || _demo ? '此服務項目尚無可用的統計來源' : '正在讀取店家模板',
          subtitle: _moduleError != null
              ? '模板設定讀取失敗，請重試或切換示範資料。'
              : '統計準備中的服務項目不當作 0 元，也不合併進其他服務項目。',
          child: _moduleError != null
              ? TextButton(onPressed: _loadModules, child: const Text('重新讀取模板'))
              : Text(
                  _scope == 'all'
                      ? '整店只彙總已啟用且可統計的服務項目。'
                      : '${OwnerReportWorkspace.label(_scope)}報表統計準備中，暫無可用的訂單與付款統計。',
                ),
        )
      : FutureBuilder<ShopReportBundle>(
          key: ValueKey('report-$_monthKey-$_tab'),
          future: _report,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const OwnerReportSection(
                title: '系統營收暫時無法載入',
                subtitle: '請按右上角重新載入。',
                child: Text('未將未知收入當成 0 元；薪資與手動記帳可獨立使用。'),
              );
            }
            if (!snapshot.hasData ||
                snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            final report = snapshot.data!, k = report.revenueKpi;
            if (_tab == 2) return _cashflowSummary(report, docs, ready);
            final panels = _tab == 0
                ? <String>{'charts'}
                : _tab == 3
                ? <String>{'operations', 'daily', 'ranking', 'costs'}
                : _sections;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_tab == 0 || (_tab == 4 && _sections.contains('summary')))
                  _cashflowSummary(report, docs, ready),
                if (_tab == 0 || (_tab == 4 && _sections.contains('summary')))
                  OwnerReportSection(
                    title: '${OwnerReportWorkspace.label(_scope)}・本月成果',
                    subtitle: '系統淨實收已反映退款；未載入的私人收支不列入結餘計算。',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _metric('系統訂單金額', k.orderAmount),
                        _metric('系統淨實收（已反映退款）', k.paidAmount),
                        _metric('系統退款', k.refundAmount),
                        _metric('系統未收款', k.unpaidAmount),
                      ],
                    ),
                  ),
                if (_tab == 3 ||
                    (_tab == 4 && _sections.contains('comparison')))
                  _comparison(report),
                if ((_tab == 0 || panels.contains('modules')) && _wholeShop)
                  _businessComparison(),
                if (_wholeShop && !_canCalculateBalance)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('部分已啟用的服務尚未提供統計，目前只提供可統計收入與整店已填支出，暫不計算完整結餘。'),
                  ),
                if (!_wholeShop)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('薪資與手動收支為整店共用，尚未分攤；此頁只看選定服務項目的系統收入，不計算服務項目結餘。'),
                  ),
                OwnerFinanceInsights(
                  report: report,
                  entries: docs.map((d) => d.data()).toList(),
                  ledgerReady: ready,
                  sections: panels,
                  wholeShop: _wholeShop,
                  revenueComplete: _canCalculateBalance,
                ),
                if (_tab == 4)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '統計口徑：訂單依建立日、淨實收依付款日。結餘＝系統淨實收＋其他收入－薪資－其他支出；未填成本不自動估算，結餘非會計淨利。其他收入勿重複登記系統已有收入。',
                    ),
                  ),
              ],
            );
          },
        );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('老闆經營儀表板'),
      actions: [
        IconButton(
          tooltip: '自訂顯示區塊',
          onPressed: _configure,
          icon: const Icon(Icons.tune),
        ),
        IconButton(
          tooltip: '重新載入營收',
          onPressed: () {
            if (_demo) {
              setState(_load);
            } else {
              _loadModules(reloadLedger: true);
            }
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '上個月',
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(_monthKey, style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  tooltip: '下個月',
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _month = DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                    );
                    _load();
                  }),
                  child: const Text('本月'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _workspaceControls(),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: _selectTab,
              tabs: [for (final name in _tabNames) Tab(text: name)],
            ),
            Expanded(
              child: StreamBuilder<List<OwnerLedgerEntry>>(
                key: ValueKey('$_monthKey-$_demo'),
                stream: _ledger,
                builder: (context, ledger) {
                  final ready =
                      ledger.hasData &&
                      !ledger.hasError &&
                      ledger.connectionState != ConnectionState.waiting;
                  final docs = ready
                      ? ledger.data!.toList()
                      : <OwnerLedgerEntry>[];
                  int total(String kind) => docs
                      .where((d) => d.data()['kind'] == kind)
                      .fold<int>(
                        0,
                        (v, d) => v + (d.data()['amount'] as num).toInt(),
                      );
                  final salary = total('salary'),
                      expense = total('expense'),
                      income = total('income');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 16,
                          runSpacing: 10,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_monthKey  ${_tabNames[_tab]}',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _tabHints[_tab],
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_tab == 0)
                                  FilledButton.icon(
                                    onPressed: () => _selectTab(1),
                                    icon: const Icon(Icons.person_add_alt),
                                    label: const Text('前往薪資填寫'),
                                  ),
                                if (_tab == 1)
                                  FilledButton.icon(
                                    onPressed: ready ? () => _edit() : null,
                                    icon: const Icon(Icons.add),
                                    label: const Text('新增員工薪資'),
                                  ),
                                if (_tab == 2) ...[
                                  FilledButton.icon(
                                    onPressed: ready
                                        ? () => _edit(null, 'expense')
                                        : null,
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    label: const Text('新增支出'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: ready
                                        ? () => _edit(null, 'income')
                                        : null,
                                    icon: const Icon(Icons.add_circle_outline),
                                    label: const Text('新增其他收入'),
                                  ),
                                ],
                                if (_tab == 3)
                                  OutlinedButton.icon(
                                    onPressed: () => _selectTab(4),
                                    icon: const Icon(Icons.summarize_outlined),
                                    label: const Text('查看完整月報'),
                                  ),
                                if (_tab == 4) ...[
                                  OutlinedButton.icon(
                                    onPressed: _configure,
                                    icon: const Icon(Icons.tune),
                                    label: const Text('選擇月報內容'),
                                  ),
                                  if (kIsWeb)
                                    FilledButton.icon(
                                      onPressed:
                                          ready && _scopeReady && !_exporting
                                          ? () => _export(
                                              docs
                                                  .map((d) => d.data())
                                                  .toList(),
                                            )
                                          : null,
                                      icon: const Icon(Icons.download),
                                      label: Text(
                                        _exporting ? '匯出中…' : '匯出完整 Excel',
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          key: ValueKey('owner-page-$_monthKey-$_tab'),
                          controller: _pageScroll,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            if (!ready)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (ledger.hasError) ...[
                                        Text(_ledgerError(ledger.error)),
                                        Text(
                                          _tab == 1 || _tab == 2
                                              ? '填寫入口就在上方；目前私人資料存取受限，尚不能新增或儲存。'
                                              : '私人收支尚未載入，薪資、總支出與結餘暫不計算。',
                                        ),
                                        TextButton(
                                          onPressed: () => setState(_load),
                                          child: const Text('重新讀取收支'),
                                        ),
                                      ] else ...[
                                        const Text('正在讀取薪資與私人收支…'),
                                        const LinearProgressIndicator(),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            if (_tab == 0)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _shortcut(
                                    '填寫員工薪資',
                                    '新增薪資、試算與修改',
                                    Icons.badge_outlined,
                                    1,
                                  ),
                                  _shortcut(
                                    '登記收入支出',
                                    '房租、水電、耗材與其他收入',
                                    Icons.edit_note,
                                    2,
                                  ),
                                  _shortcut(
                                    '查看完整月報',
                                    '確認整月成果與匯出 Excel',
                                    Icons.summarize_outlined,
                                    4,
                                  ),
                                ],
                              ),
                            if (_tab == 2)
                              _reportContent(
                                docs,
                                ready,
                                salary,
                                expense,
                                income,
                              ),
                            if (ready &&
                                (_tab == 0 ||
                                    _tab == 1 ||
                                    _tab == 2 ||
                                    (_tab == 4 &&
                                        _sections.contains('summary'))))
                              (_tab == 2
                                  ? Card(
                                      child: ExpansionTile(
                                        title: const Text('查看手動收支分類'),
                                        subtitle: const Text('薪資、其他支出與其他收入'),
                                        children: [
                                          _manualTotals(
                                            salary,
                                            expense,
                                            income,
                                            docs,
                                          ),
                                        ],
                                      ),
                                    )
                                  : _manualTotals(
                                      salary,
                                      expense,
                                      income,
                                      docs,
                                    )),
                            if (_tab == 1) ...[
                              if (ready) _salarySummary(docs),
                              _entryList(docs, ready),
                            ],
                            if (_tab == 2) _entryList(docs, ready),
                            if (_tab == 0 || _tab == 3 || _tab == 4)
                              _reportContent(
                                docs,
                                ready,
                                salary,
                                expense,
                                income,
                              ),
                            if (_tab == 4) ...[
                              if (_sections.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('尚未選取月報內容，請按上方「選擇月報內容」。'),
                                ),
                              if (_sections.contains('ledger'))
                                _entryList(docs, ready),
                              const OwnerReportSection(
                                title: '月報確認',
                                subtitle: '匯出包含完整月份私人收支，不受報表開關或搜尋影響，含薪資資料。',
                                child: Text(
                                  '請確認員工薪資、房租水電及其他成本已填齊，再核對收入、退款與未收款。尚未填寫的支出不會自動補入。',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
