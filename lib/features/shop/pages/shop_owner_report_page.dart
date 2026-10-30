import 'dart:math' as math;
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
  });
  final Future<ShopReportBundle> Function(ReportRange)? reportLoader;
  final Stream<QuerySnapshot<Map<String, dynamic>>> Function(String)?
  ledgerLoader;
  final String shopId;
  @override
  State<ShopOwnerReportPage> createState() => _ShopOwnerReportPageState();
}

class _ShopOwnerReportPageState extends State<ShopOwnerReportPage>
    with SingleTickerProviderStateMixin {
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
  late Stream<QuerySnapshot<Map<String, dynamic>>> _ledger;
  static const _panels = <String, String>{
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
  final _money = NumberFormat('#,##0', 'zh_TW');
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
    _load();
    _restorePanels();
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
    setState(() {
      _previous =
          widget.reportLoader?.call(range) ??
          ShopReportService.instance.load(shopId: widget.shopId, range: range);
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
                      for (final panel in _panels.entries)
                        SwitchListTile(
                          title: Text(panel.value),
                          value: _sections.contains(panel.key),
                          onChanged: (value) {
                            _togglePanel(panel.key, value);
                            update(() {});
                          },
                        ),
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
      );
      await downloader.downloadExcelFile(
        bytes: bytes,
        fileName: 'PetNest_老闆月報_$month.xlsx',
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
  void _load() {
    _ledger = widget.ledgerLoader?.call(_monthKey) ?? _entries.snapshots();
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
    _report =
        widget.reportLoader?.call(range) ??
        ShopReportService.instance.load(shopId: widget.shopId, range: range);
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
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
    String initialKind = 'salary',
  ]) async {
    final collection = _entries;
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
            title: Text('${doc == null ? '新增' : '編輯'} $_monthKey 收支'),
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
                          await (doc == null
                                  ? collection.doc()
                                  : collection.doc(doc.id))
                              .set({
                                'kind': kind,
                                'name': name.text.trim(),
                                'amount': int.parse(amount.text),
                                'note': note.text.trim(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
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

  Future<void> _delete(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
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
        await doc.reference.delete();
      } catch (e) {
        _error(e);
      }
    }
  }

  Widget _metric(String label, int amount, {bool money = true}) => Card(
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
                money ? 'NT\$ ${_money.format(amount)}' : '$amount 人',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _salarySummary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
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
                          DataCell(Text(ownerMoney(e.value))),
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

  Widget _entryList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    bool ready,
  ) {
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
                  '${doc.data()['name']}　${ownerMoney(doc.data()['amount'] as num)}',
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
  Widget _reportContent(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    bool ready,
    int salary,
    int expense,
    int income,
  ) => FutureBuilder<ShopReportBundle>(
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
      final panels = _tab == 0
          ? <String>{'charts'}
          : _tab == 3
          ? <String>{'operations', 'daily', 'ranking', 'costs'}
          : _sections;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_tab == 0 || (_tab == 4 && _sections.contains('summary')))
            OwnerReportSection(
              title: '本月經營成果',
              subtitle: '系統淨實收已反映退款；未載入的私人收支不列入結餘計算。',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metric('系統訂單金額', k.orderAmount),
                  _metric('系統淨實收（已反映退款）', k.paidAmount),
                  _metric('系統退款', k.refundAmount),
                  _metric('系統未收款', k.unpaidAmount),
                  if (ready) _metric('總淨收入（淨實收＋其他收入）', k.paidAmount + income),
                  if (ready)
                    _metric('收支結餘', k.paidAmount + income - salary - expense),
                ],
              ),
            ),
          if (_tab == 3 || (_tab == 4 && _sections.contains('comparison')))
            _comparison(report),
          OwnerFinanceInsights(
            report: report,
            entries: docs.map((d) => d.data()).toList(),
            ledgerReady: ready,
            sections: panels,
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
          onPressed: () => setState(_load),
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
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: _selectTab,
              tabs: [for (final name in _tabNames) Tab(text: name)],
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                key: ValueKey(_monthKey),
                stream: _ledger,
                builder: (context, ledger) {
                  final ready =
                      ledger.hasData &&
                      !ledger.hasError &&
                      ledger.connectionState != ConnectionState.waiting;
                  final docs = ready
                      ? ledger.data!.docs.toList()
                      : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
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
                                      onPressed: ready && !_exporting
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
                            if (ready &&
                                (_tab == 0 ||
                                    _tab == 1 ||
                                    _tab == 2 ||
                                    (_tab == 4 &&
                                        _sections.contains('summary'))))
                              OwnerReportSection(
                                title: _tab == 1
                                    ? '本月薪資摘要'
                                    : _tab == 2
                                    ? '本月手動收支'
                                    : '本月已填收支',
                                subtitle: '依已填寫資料合計；未填成本不會自動估算。',
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (_tab != 2) _metric('員工薪資合計', salary),
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
                                      _metric('其他支出合計', expense),
                                      _metric('手動其他收入', income),
                                      _metric('支出總計', salary + expense),
                                    ],
                                  ],
                                ),
                              ),
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
