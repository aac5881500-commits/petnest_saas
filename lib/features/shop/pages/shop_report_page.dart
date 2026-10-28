import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/models/shop_report_models.dart';
import 'package:petnest_saas/core/models/report_table_spec.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';
import 'package:petnest_saas/core/services/report_workbench_export.dart';
import 'package:petnest_saas/core/services/report_downloader_stub.dart'
    if (dart.library.html) 'package:petnest_saas/core/services/report_downloader_web.dart';
import '../widgets/report_range_selector.dart';
import '../widgets/reports/report_data_grid.dart';

typedef ReportLoader =
    Future<ShopReportBundle> Function(ReportRange range, Set<String> sources);

class ShopReportPage extends StatefulWidget {
  const ShopReportPage({
    super.key,
    required this.shopId,
    this.initialTemplate = 'overview',
    this.showTaskCenter = true,
    this.loadReport,
    this.loadAccess,
    this.saveFile,
  });
  final String shopId, initialTemplate;
  final bool showTaskCenter;
  final ReportLoader? loadReport;
  final Future<Map<String, dynamic>> Function()? loadAccess;
  final Future<void> Function(Uint8List bytes, String filename)? saveFile;
  @override
  State<ShopReportPage> createState() => _ShopReportPageState();
}

class _ShopReportPageState extends State<ShopReportPage> {
  ReportRange _range = ReportRange.thisMonth();
  late ReportTableSpec _spec;
  Map<String, dynamic>? _access;
  ShopReportBundle? _bundle;
  Object? _error;
  bool _initializing = true, _loading = false, _exporting = false;
  String _loadedKey = '', _query = '', _sort = 'date';
  bool _ascending = false;
  int _request = 0;
  final _searchController = TextEditingController();
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _preferenceError;
  List<Map<String, dynamic>> _saved = [];
  String get _key =>
      '${widget.shopId}|${_range.startDate.toIso8601String()}|${_range.endDate.toIso8601String()}|${(_spec.sources.toList()..sort()).join(',')}';
  bool get _stale => _loadedKey != _key;
  bool get _canMembers => _access?['canMembers'] == true;
  bool get _canStore => _access?['canStore'] == true;
  String get _prefsKey =>
      'report_views_v1_${_access?['uid'] ?? 'local'}_${widget.shopId}';
  @override
  void initState() {
    super.initState();
    _spec = ReportTableSpec.preset(ReportTemplate.byId(widget.initialTemplate));
    _init();
  }

  @override
  void didUpdateWidget(covariant ShopReportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) {
      _request++;
      _loading = false;
      _error = null;
      _bundle = null;
      _access = null;
      _saved = [];
      _loadedKey = '';
      _initializing = true;
      _init();
    }
  }

  Future<Map<String, dynamic>> _defaultAccess() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {'canView': false};
    final result = await Future.wait([
      ShopService.instance.getUserMemberInShop(shopId: widget.shopId, uid: uid),
      ShopService.instance.getShop(widget.shopId),
    ]);
    final member = result[0], shop = result[1];
    bool can(String key) => ShopService.instance.hasPermission(member, key);
    return {
      'uid': uid,
      'shopName': shop?['name'] ?? '本店',
      'canView': can(ShopPermissionKeys.viewReports),
      'canMembers': can(ShopPermissionKeys.manageMembers),
      'canStore':
          can(ShopPermissionKeys.viewStoreOrders) ||
          can(ShopPermissionKeys.manageStoreOrders),
    };
  }

  Future<void> _init() async {
    final shopId = widget.shopId;
    try {
      final access = await (widget.loadAccess?.call() ?? _defaultAccess());
      if (!mounted || shopId != widget.shopId) return;
      setState(() {
        _access = access;
        _error = null;
        _initializing = false;
        _spec = _sanitize(_spec);
      });
      if (access['canView'] != true) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_prefsKey);
        if (raw != null) {
          final entries = jsonDecode(raw);
          if (entries is List) {
            _saved = entries
                .whereType<Map>()
                .where((e) => e['name'] is String && e['spec'] is Map)
                .take(20)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
      } catch (_) {
        _preferenceError = '本機模板讀取失敗，內建模板仍可使用。';
      }
      if (mounted && shopId == widget.shopId) await _load();
    } catch (error) {
      if (mounted && shopId == widget.shopId) {
        setState(() {
          _error = error;
          _initializing = false;
        });
      }
    }
  }

  ReportTableSpec _sanitize(ReportTableSpec spec) => spec.copyWith(
    sources: {
      ...spec.sources
          .where(spec.allowedSources.contains)
          .where((s) => s != 'members' || _canMembers)
          .where((s) => s != 'store' || _canStore),
    },
  );
  bool get _validSources => _spec.kind == ReportTableKind.member
      ? _canMembers && _spec.sources.contains('members')
      : _spec.kind == ReportTableKind.revenue
      ? _spec.sources.any((s) => ['stay', 'daycare', 'store'].contains(s))
      : _spec.sources.any((s) => ['stay', 'daycare'].contains(s));
  Future<void> _load() async {
    if (_loading || _exporting || !_validSources) return;
    final request = ++_request,
        range = _range,
        sources = Set<String>.of(_spec.sources),
        key = _key;
    setState(() {
      _loading = true;
      _error = null;
      _bundle = null;
    });
    try {
      final data =
          await (widget.loadReport?.call(range, sources) ??
              ShopReportService.instance.loadSelected(
                shopId: widget.shopId,
                range: range,
                sources: sources,
                includeMoney: sources.contains('payments'),
              ));
      if (!mounted || request != _request) return;
      setState(() {
        _bundle = data;
        _loadedKey = key;
        _loading = false;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  void _choose(ReportTableSpec spec) {
    _searchController.clear();
    setState(() {
      _spec = _sanitize(spec);
      _query = '';
      _sort = _spec.visibleFields.firstOrNull?.id ?? 'date';
      _ascending = true;
    });
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _saveTemplate() async {
    var draftName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('儲存為個人模板'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) => draftName = value,
              maxLength: 40,
              decoration: const InputDecoration(labelText: '模板名稱'),
            ),
            const Text('保存資料來源、欄位順序與表格外觀，不保存資料列或固定日期。同名模板會更新；儲存於目前裝置與帳號。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = draftName.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('儲存模板'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    if (_saved.length >= 20 && !_saved.any((e) => e['name'] == name)) {
      _message('最多保存 20 個個人模板，請先刪除不需要的模板。');
      return;
    }
    final next = [
      ..._saved.where((e) => e['name'] != name),
      {'name': name, 'spec': _spec.toMap()},
    ];
    try {
      final prefs = await SharedPreferences.getInstance();
      final ok = await prefs.setString(_prefsKey, jsonEncode(next));
      if (!ok) throw StateError('save');
      if (mounted) setState(() => _saved = next);
      if (mounted) _message('個人模板已儲存。');
    } catch (_) {
      if (mounted) _message('模板儲存失敗，畫面設定仍保留。');
    }
  }

  Future<void> _deleteTemplate(int index) async {
    final next = [..._saved]..removeAt(index);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_prefsKey, jsonEncode(next))) {
        throw StateError('save');
      }
      if (mounted) setState(() => _saved = next);
    } catch (_) {
      if (mounted) _message('刪除模板失敗，請重試。');
    }
  }

  Future<void> _columns() async {
    var draft = _spec;
    final all = ReportDataset.fields(_spec.kind);
    final result = await showModalBottomSheet<ReportTableSpec>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, change) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .82,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '欄位與順序',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('未勾選的欄位不會顯示或匯出。第一個識別欄位固定保留。'),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final f in all)
                        CheckboxListTile(
                          title: Text(f.label),
                          subtitle: !draft.available(f)
                              ? const Text('需勾選對應資料來源')
                              : null,
                          value:
                              draft.columns.contains(f.id) &&
                              draft.available(f),
                          onChanged: !draft.available(f) || f == all.first
                              ? null
                              : (value) => change(() {
                                  final cols = [...draft.columns];
                                  if (value == true) {
                                    cols.add(f.id);
                                  } else {
                                    cols.remove(f.id);
                                  }
                                  draft = draft.copyWith(columns: cols);
                                }),
                        ),
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('已選欄位順序'),
                      ),
                      for (var i = 0; i < draft.visibleFields.length; i++)
                        ListTile(
                          title: Text(draft.visibleFields[i].label),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: '欄位上移',
                                onPressed: i > 1
                                    ? () => change(() {
                                        final cols = [...draft.columns];
                                        final a = cols.indexOf(
                                              draft.visibleFields[i].id,
                                            ),
                                            b = cols.indexOf(
                                              draft.visibleFields[i - 1].id,
                                            );
                                        final item = cols.removeAt(a);
                                        cols.insert(b, item);
                                        draft = draft.copyWith(columns: cols);
                                      })
                                    : null,
                                icon: const Icon(Icons.arrow_upward, size: 18),
                              ),
                              IconButton(
                                tooltip: '欄位下移',
                                onPressed:
                                    i > 0 && i + 1 < draft.visibleFields.length
                                    ? () => change(() {
                                        final cols = [...draft.columns];
                                        final a = cols.indexOf(
                                              draft.visibleFields[i].id,
                                            ),
                                            b = cols.indexOf(
                                              draft.visibleFields[i + 1].id,
                                            );
                                        final item = cols.removeAt(a);
                                        cols.insert(b, item);
                                        draft = draft.copyWith(columns: cols);
                                      })
                                    : null,
                                icon: const Icon(
                                  Icons.arrow_downward,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, draft),
                    child: const Text('套用欄位設定'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _spec = result);
  }

  Set<String> get _sourceChoices => switch (_spec.kind) {
    ReportTableKind.daily => {'stay', 'daycare', 'payments'},
    ReportTableKind.revenue => {'stay', 'daycare', 'store', 'payments'},
    ReportTableKind.member => {'stay', 'daycare', 'members'},
    _ => {'stay', 'daycare'},
  };
  Future<void> _export() async {
    if (_bundle == null || _stale || _loading || _exporting) return;
    final bundle = _bundle!, spec = _spec, range = _range, query = _query;
    final datasets = <String, ReportExportTable>{};
    final current = ReportDataset.fromBundle(bundle, spec);
    datasets['current'] = ReportExportTable(
      name: '目前表格',
      spec: spec,
      rows: current.filtered(spec, query, _sort, _ascending),
    );
    for (final template in ReportTemplate.all.where(
      (t) => !['frontdesk', 'reconciliation', 'directory'].contains(t.id),
    )) {
      if (template.kind == ReportTableKind.member &&
          !spec.sources.contains('members')) {
        continue;
      }
      if (template.kind != ReportTableKind.member &&
          !spec.sources.any((s) => ['stay', 'daycare', 'store'].contains(s))) {
        continue;
      }
      if ([
            ReportTableKind.daily,
            ReportTableKind.room,
            ReportTableKind.addon,
          ].contains(template.kind) &&
          !spec.sources.any((s) => ['stay', 'daycare'].contains(s))) {
        continue;
      }
      var alternative = ReportTableSpec.preset(template).copyWith(
        sources: spec.sources,
        monthly: spec.monthly,
        hideEmpty: spec.hideEmpty,
        memberFilter: spec.memberFilter,
      );
      // Preserve explicit field choices if this is another view of the same table.
      if (alternative.kind == spec.kind) {
        alternative = alternative.copyWith(columns: spec.columns);
      }
      final dataset = ReportDataset.fromBundle(bundle, alternative);
      datasets[template.id] = ReportExportTable(
        name: template.name,
        spec: alternative,
        rows: dataset.filtered(
          alternative,
          query,
          alternative.visibleFields.first.id,
          true,
        ),
      );
    }
    var selected = <String>{'current'};
    final chosen = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, change) => AlertDialog(
          title: const Text('匯出 Excel 報表'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '可匯出目前表格，或勾選多張模板放進同一個 Excel。只使用已查詢的資料來源，不會額外抓取未勾選的資料。',
                  ),
                  const SizedBox(height: 12),
                  for (final entry in datasets.entries)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value.name),
                      subtitle: Text(
                        '${entry.value.rows.length} 筆・${entry.value.spec.visibleFields.length} 欄',
                      ),
                      value: selected.contains(entry.key),
                      onChanged: (value) => change(() {
                        if (value == true) {
                          selected.add(entry.key);
                        } else {
                          selected.remove(entry.key);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, selected),
              child: const Text('下載 Excel'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      final bytes = ReportWorkbenchExport.build(
        shopName: '${_access?['shopName'] ?? '本店'}',
        range: range,
        tables: chosen.map((id) => datasets[id]!).toList(),
        query: query,
      );
      final filename =
          'PetNest_報表_${range.startDate.year}${range.startDate.month.toString().padLeft(2, '0')}${range.startDate.day.toString().padLeft(2, '0')}.xlsx';
      if (widget.saveFile != null) {
        await widget.saveFile!(bytes, filename);
      } else {
        await downloadExcelFile(bytes: bytes, fileName: filename);
      }
      if (mounted) _message('Excel 已開始下載，包含全部篩選結果與報表說明。');
    } catch (_) {
      if (mounted) _message('匯出失敗，查詢結果仍保留，可重試。');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _templates({bool compact = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '報表模板',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      if (compact)
        DropdownButtonFormField<String>(
          key: ValueKey('preset-${_spec.templateId}'),
          initialValue: _spec.templateId,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final t in ReportTemplate.all)
              DropdownMenuItem(
                value: t.id,
                enabled: t.kind != ReportTableKind.member || _canMembers,
                child: Text(t.name),
              ),
          ],
          onChanged: _exporting
              ? null
              : (id) {
                  if (id != null) {
                    _choose(ReportTableSpec.preset(ReportTemplate.byId(id)));
                  }
                },
        )
      else
        for (final t in ReportTemplate.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              selected: _spec.templateId == t.id,
              selectedTileColor: const Color(0xFFE8EEF9),
              enabled:
                  !_exporting &&
                  (t.kind != ReportTableKind.member || _canMembers),
              title: Text(
                t.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                t.kind == ReportTableKind.member && !_canMembers
                    ? '需要會員管理權限'
                    : t.description,
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => _choose(ReportTableSpec.preset(t)),
            ),
          ),
      const SizedBox(height: 16),
      const Text('本機個人模板', style: TextStyle(fontWeight: FontWeight.w800)),
      if (_saved.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '調整欄位後，可另存常用模板。',
            style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
          ),
        ),
      for (var i = 0; i < _saved.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${_saved[i]['name']}'),
          onTap: () {
            final spec = ReportTableSpec.fromMap(_saved[i]['spec'] as Map);
            if (spec.kind == ReportTableKind.member && !_canMembers) {
              _message('需要會員管理權限。');
              return;
            }
            _choose(spec);
          },
          trailing: IconButton(
            tooltip: '刪除個人模板',
            onPressed: () => _deleteTemplate(i),
            icon: const Icon(Icons.close, size: 18),
          ),
        ),
      OutlinedButton.icon(
        onPressed: _exporting ? null : _saveTemplate,
        icon: const Icon(Icons.bookmark_add_outlined),
        label: const Text('儲存個人模板'),
      ),
      if (_preferenceError != null)
        Text(_preferenceError!, style: const TextStyle(fontSize: 12)),
    ],
  );
  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE3E8F0)),
    ),
    child: child,
  );
  Widget _metrics(List<Map<String, Object?>> rows) {
    final additive = _spec.visibleFields.where((f) => f.total).toList();
    final fields = [
      ...additive.where((f) => f.money),
      ...additive.where((f) => !f.money),
    ].take(3).toList();
    final values = <(String, String)>[('符合條件的列數', '${rows.length}')];
    for (final f in fields) {
      final sum = rows.fold<num>(
        0,
        (sum, row) => sum + (row[f.id] is num ? row[f.id] as num : 0),
      );
      values.add((f.label, ReportDataset.display(sum, f)));
    }
    return LayoutBuilder(
      builder: (context, c) {
        final count = c.maxWidth >= 700 ? 4 : 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final value in values)
              SizedBox(
                width: (c.maxWidth - (count - 1) * 10) / count,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.$1,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value.$2,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF33466D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _workspace() {
    final dataset = _bundle == null
        ? null
        : ReportDataset.fromBundle(_bundle!, _spec);
    final rows =
        dataset?.filtered(_spec, _query, _sort, _ascending) ??
        <Map<String, Object?>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ReportTemplate.byId(_spec.templateId).name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(ReportTemplate.byId(_spec.templateId).description),
              const SizedBox(height: 12),
              ReportRangeSelector(
                range: _range,
                onChanged: _exporting
                    ? (_) {}
                    : (range) => setState(() => _range = range),
              ),
              const SizedBox(height: 8),
              const Text('資料來源', style: TextStyle(fontWeight: FontWeight.w800)),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final source in _sourceChoices)
                    FilterChip(
                      label: Text(
                        '${ReportTableSpec.sourceNames[source]}${source == 'members' && !_canMembers || source == 'store' && !_canStore ? '（需權限）' : ''}',
                      ),
                      selected: _spec.sources.contains(source),
                      onSelected:
                          _exporting ||
                              source == 'members' && !_canMembers ||
                              source == 'store' && !_canStore
                          ? null
                          : (value) => setState(() {
                              final sources = {..._spec.sources};
                              if (value) {
                                sources.add(source);
                              } else {
                                sources.remove(source);
                              }
                              _spec = _spec.copyWith(sources: sources);
                            }),
                    ),
                ],
              ),
              if (!_validSources)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '請勾選此模板需要的資料來源。',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _loading || _exporting || !_validSources
                        ? null
                        : _load,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search, size: 18),
                    label: Text(_loading ? '查詢中…' : '套用查詢'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _exporting ? null : _columns,
                    icon: const Icon(Icons.view_column_outlined),
                    label: Text('欄位 ${_spec.visibleFields.length}'),
                  ),
                  if (_spec.kind == ReportTableKind.revenue)
                    FilterChip(
                      label: const Text('依月份彙整'),
                      selected: _spec.monthly,
                      onSelected: _exporting
                          ? null
                          : (v) => setState(
                              () => _spec = _spec.copyWith(monthly: v),
                            ),
                    ),
                  FilterChip(
                    label: const Text('隱藏無活動日期'),
                    selected: _spec.hideEmpty,
                    onSelected: _exporting
                        ? null
                        : (v) => setState(
                            () => _spec = _spec.copyWith(hideEmpty: v),
                          ),
                  ),
                  FilterChip(
                    label: const Text('緊湊表格'),
                    selected: _spec.compact,
                    onSelected: _exporting
                        ? null
                        : (v) => setState(
                            () => _spec = _spec.copyWith(compact: v),
                          ),
                  ),
                ],
              ),
              if (_stale && !_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    '條件已變更，請按「套用查詢」更新資料。',
                    style: TextStyle(color: Color(0xFF8A5A00)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          _panel(
            Column(
              children: [
                const Icon(Icons.cloud_off_outlined),
                const SizedBox(height: 10),
                const Text('報表讀取失敗，請確認網路或資料權限後重試；不會將失敗顯示為 0。'),
                TextButton(onPressed: _load, child: const Text('重新查詢')),
              ],
            ),
          )
        else if (_validSources && !_stale && dataset != null)
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '資料預覽 · ${rows.length} 筆',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed:
                          _loading ||
                              _exporting ||
                              (!kIsWeb && widget.saveFile == null)
                          ? null
                          : _export,
                      icon: const Icon(Icons.download_outlined),
                      label: Text(_exporting ? '匯出中…' : '匯出 Excel'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _metrics(rows),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜尋已顯示欄位（匯出同步套用）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                if (_spec.kind == ReportTableKind.member)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final e in {
                          'all': '全部會員',
                          'vip': '常客 VIP',
                          'blocked': '黑名單',
                          if (_spec.sources.contains('stay') ||
                              _spec.sources.contains('daycare'))
                            'active30': '近 30 天有有效訂單',
                          if (_spec.sources.contains('stay') ||
                              _spec.sources.contains('daycare'))
                            'inactive30': '近 30 天無有效訂單',
                        }.entries)
                          ChoiceChip(
                            label: Text(e.value),
                            selected: _spec.memberFilter == e.key,
                            onSelected: (_) => setState(
                              () => _spec = _spec.copyWith(memberFilter: e.key),
                            ),
                          ),
                      ],
                    ),
                  ),
                ReportDataGrid(
                  spec: _spec,
                  rows: rows,
                  sortId: _sort,
                  ascending: _ascending,
                  onSort: (id) => setState(() {
                    if (_sort == id) {
                      _ascending = !_ascending;
                    } else {
                      _sort = id;
                      _ascending = true;
                    }
                  }),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _panel(
          const ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('統計口徑與匯出說明'),
            children: [
              Text(
                '• 訂單依建立日歸屬；有效訂單為已確認、入住中與已完成，不含待確認及取消。\n• 入住／退房依對應日期；晚數為所選期間建立的有效住宿訂單晚數，安親不計住宿晚數。\n• 收款依付款日歸屬，與訂單建立日可能不同。待收款是依現有訂單／付款資料估計，跨期款項請搭配原始付款紀錄核對。\n• 會員金額為查詢期間有效訂單金額，不是實收或歷年累積；近 30／90 天以查詢結束日為基準。\n• 不抓未勾選的來源；欄位隱藏僅影響呈現與匯出。會員電話預設不匯出，需另行勾選。\n• Excel 匯出全部篩選結果與數字型金額，附日期、來源與口徑說明；目前支援 Web 下載。',
                style: TextStyle(height: 1.8, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F7FB),
    appBar: AppBar(
      title: const Text('營運報表工作台'),
      actions: [
        if (widget.showTaskCenter && _access?['canView'] == true)
          ShopTaskCenterButton(shopId: widget.shopId),
      ],
    ),
    body: _initializing
        ? const Center(child: CircularProgressIndicator())
        : _access?['canView'] != true
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error == null ? '需要查看報表權限。' : '無法讀取報表權限，請重試。'),
                if (_error != null)
                  TextButton(onPressed: _init, child: const Text('重新載入')),
              ],
            ),
          )
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 1100;
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 24 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '一份資料，多種報表視角',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '選擇模板 → 勾選資料與欄位 → 套用查詢 → 預覽及匯出',
                          style: TextStyle(
                            color: Color(0xFF667085),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 260, child: _panel(_templates())),
                              const SizedBox(width: 20),
                              Expanded(child: _workspace()),
                            ],
                          )
                        else ...[
                          _panel(_templates(compact: true)),
                          const SizedBox(height: 16),
                          _workspace(),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
  );
}
