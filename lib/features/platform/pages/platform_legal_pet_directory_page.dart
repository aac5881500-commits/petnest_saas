// 檔案名稱：lib/features/platform/pages/platform_legal_pet_directory_page.dart
// 功能說明：平台搜尋與篩選農業部業者，並維護 PetNest 對應與人工聯繫。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/legal_pet/directory_load_gate.dart';
import 'package:petnest_saas/core/services/legal_pet_service.dart';
import 'package:petnest_saas/core/services/shop_commercial_service.dart';

class PlatformLegalPetDirectoryPage extends StatefulWidget {
  const PlatformLegalPetDirectoryPage({super.key});

  @override
  State<PlatformLegalPetDirectoryPage> createState() =>
      _PlatformLegalPetDirectoryPageState();
}

class _PlatformLegalPetDirectoryPageState
    extends State<PlatformLegalPetDirectoryPage> {
  final DirectoryListController _lists = DirectoryListController();
  final TextEditingController _query = TextEditingController();
  String _appliedQuery = '';
  String _county = '';
  String _district = '';
  String _animal = '';
  String _bus = '';
  String _businessState = '';
  String _validity = '';
  String _linkStatus = '';
  String _contactStatus = '';
  bool _loading = true;
  bool _syncing = false;
  bool _backfilling = false;
  String _backfillProgress = '';
  String? _error;
  String _outcome = '';
  bool _needsBackfill = false;
  LegalPetSyncStatus _sync = const LegalPetSyncStatus(
    phase: 'unknown',
    successText: '',
    directoryReady: false,
    errorSummary: '',
  );
  List<LegalPetDirectoryItem> _items = const [];
  bool _hasMore = false;
  String _nextCursor = '';
  int _candidateReads = 0;
  bool _staleBackend = false;
  final Map<int, LegalPetDirectoryPage> _pageCache = {};
  Map<String, String> _counties = const {};
  Map<String, List<String>> _districts = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _clearPageCache() {
    _pageCache.clear();
  }

  void _rememberPage(LegalPetDirectoryPage page) {
    _pageCache[_lists.pageIndex] = page;
    if (_pageCache.length <= 8) return;
    final keys = _pageCache.keys.toList()..sort();
    _pageCache.remove(keys.first);
  }

  void _showPage(LegalPetDirectoryPage page, DirectoryResponseDecision decision) {
    final stillSelected = page.items.any(
      (item) => item.govId == _lists.selectedId,
    );
    _items = page.items;
    _hasMore = page.hasMore;
    _nextCursor = page.nextCursor;
    _candidateReads = page.candidateReads;
    _needsBackfill = page.needsBackfill;
    _outcome = page.outcome;
    _sync = page.sync;
    _staleBackend = decision.stale;
    if (page.counties.isNotEmpty) _counties = page.counties;
    if (page.districts.isNotEmpty) _districts = page.districts;
    _lists.selectedId = stillSelected
        ? _lists.selectedId
        : (page.items.isEmpty ? null : page.items.first.govId);
  }

  Future<void> _load({bool resetPage = false, bool allowCache = false}) async {
    if (resetPage) {
      _lists.beginRequest(resetPage: true);
      _clearPageCache();
    }
    if (allowCache) {
      final cached = _pageCache[_lists.pageIndex];
      if (cached != null) {
        setState(() {
          _showPage(
            cached,
            decideDirectoryResponse(
              apiVersion: cached.directoryApiVersion,
              constrained: _queryIsConstrained,
            ),
          );
          _loading = false;
          _error = null;
        });
        return;
      }
    }
    final requestId = _lists.issue();
    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
      _hasMore = false;
      _needsBackfill = false;
      _outcome = '';
      _candidateReads = 0;
      _staleBackend = false;
    });
    try {
      final page = await LegalPetService.instance.listBusinesses(
        query: _appliedQuery,
        countyCode: _county,
        district: _district,
        animal: _animal,
        bus: _bus,
        businessState: _businessState,
        validity: _validity,
        linkStatus: _linkStatus,
        contactStatus: _contactStatus,
        cursor: _lists.cursors[_lists.pageIndex],
      );
      if (!mounted || !_lists.isCurrent(requestId)) return;
      final decision = decideDirectoryResponse(
        apiVersion: page.directoryApiVersion,
        constrained: _queryIsConstrained,
      );
      if (!decision.acceptItems) {
        setState(() {
          _items = const [];
          _hasMore = false;
          _nextCursor = '';
          _needsBackfill = false;
          _outcome = 'stale_backend';
          _error = staleDirectoryBackendMessage;
          _staleBackend = true;
          _sync = page.sync;
          _lists.selectedId = null;
        });
        return;
      }
      setState(() {
        _showPage(page, decision);
        if (decision.acceptItems) _rememberPage(page);
      });
    } on LegalPetException catch (error) {
      if (!mounted || !_lists.isCurrent(requestId)) return;
      setState(() {
        _error = error.message;
        _items = [];
        _outcome = 'query_failed';
        _hasMore = false;
        _lists.selectedId = null;
      });
    } finally {
      if (mounted && _lists.isCurrent(requestId)) {
        setState(() => _loading = false);
      }
    }
  }

  bool get _queryIsConstrained {
    return _appliedQuery.isNotEmpty ||
        _county.isNotEmpty ||
        _district.isNotEmpty ||
        _animal.isNotEmpty ||
        _bus.isNotEmpty ||
        _businessState.isNotEmpty ||
        _validity.isNotEmpty ||
        _linkStatus.isNotEmpty ||
        _contactStatus.isNotEmpty;
  }

  void _resetPage() {
    _lists.beginRequest(resetPage: true);
    _clearPageCache();
  }

  void _applyFilters(Map<String, String> change) {
    setState(() {
      _county = change['county'] ?? _county;
      _district = change['district'] ?? _district;
      _animal = change['animal'] ?? _animal;
      _bus = change['bus'] ?? _bus;
      _businessState = change['businessState'] ?? _businessState;
      _validity = change['validity'] ?? _validity;
      _linkStatus = change['linkStatus'] ?? _linkStatus;
      _contactStatus = change['contactStatus'] ?? _contactStatus;
      if (change.containsKey('county')) {
        _district = change['district'] ?? '';
      }
      _resetPage();
    });
    _load();
  }

  void _submitSearch() {
    setState(() {
      _appliedQuery = _query.text.trim();
      _resetPage();
    });
    _load();
  }

  void _clearSearch() {
    _query.clear();
    setState(() {
      _appliedQuery = '';
      _resetPage();
    });
    _load();
  }

  void _clearAll() {
    _query.clear();
    setState(() {
      _appliedQuery = '';
      _county = '';
      _district = '';
      _animal = '';
      _bus = '';
      _businessState = '';
      _validity = '';
      _linkStatus = '';
      _contactStatus = '';
      _resetPage();
    });
    _load();
  }

  void _toggleQuick({
    String? animal,
    String? bus,
    String? businessState,
    String? linkStatus,
    String? contactStatus,
  }) {
    final sameAnimal = animal == null || _animal == animal;
    final sameBus = bus == null || _bus == bus;
    final sameState = businessState == null || _businessState == businessState;
    final sameLink = linkStatus == null || _linkStatus == linkStatus;
    final sameContact =
        contactStatus == null || _contactStatus == contactStatus;
    final active =
        sameAnimal && sameBus && sameState && sameLink && sameContact;
    if (active) {
      _applyFilters({
        if (animal != null) 'animal': '',
        if (bus != null) 'bus': '',
        if (businessState != null) 'businessState': '',
        if (linkStatus != null) 'linkStatus': '',
        if (contactStatus != null) 'contactStatus': '',
      });
      return;
    }
    _applyFilters({
      'animal': ?animal,
      'bus': ?bus,
      'businessState': ?businessState,
      'linkStatus': ?linkStatus,
      'contactStatus': ?contactStatus,
    });
  }

  Future<void> _runSync() async {
    if (_syncing || _backfilling) return;
    setState(() => _syncing = true);
    try {
      final summary = await LegalPetService.instance.syncNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary)));
      _resetPage();
      await _load();
    } on LegalPetException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _backfillLookup() async {
    if (_backfilling || _syncing) return;
    setState(() {
      _backfilling = true;
      _backfillProgress = '開始補齊字號查核欄位';
    });
    var cursor = '';
    var passId = '';
    var updated = 0;
    var skipped = 0;
    try {
      while (mounted) {
        final result = await LegalPetService.instance.backfillLicenseLookup(
          cursor: cursor,
          passId: passId,
        );
        updated += result.updated;
        skipped += result.skipped;
        passId = result.passId;
        if (!mounted) return;
        setState(() {
          _backfillProgress = '字號查核欄位已處理，更新 $updated 筆、略過 $skipped 筆';
        });
        if (result.done) {
          if (!result.ready) {
            throw LegalPetException('這次字號查核補齊沒有從第一筆完成，請再按一次補齊字號查核');
          }
          break;
        }
        cursor = result.nextCursor;
        if (cursor.isEmpty) {
          throw LegalPetException('字號查核補齊沒有取得下一筆位置，請再按一次補齊字號查核');
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('字號查核欄位已補齊，更新 $updated 筆、略過 $skipped 筆')),
      );
    } on LegalPetException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _backfilling = false;
          _backfillProgress = '';
        });
      }
    }
  }

  Future<void> _backfill() async {
    if (_backfilling || _syncing) return;
    setState(() {
      _backfilling = true;
      _backfillProgress = '開始補齊搜尋欄位';
    });
    var cursor = '';
    var passId = '';
    var updated = 0;
    try {
      while (mounted) {
        final result = await LegalPetService.instance.backfillDirectory(
          cursor: cursor,
          passId: passId,
        );
        if (result.directoryApiVersion < requiredDirectoryApiVersion) {
          throw LegalPetException(staleDirectoryBackendMessage);
        }
        updated += result.updated;
        passId = result.passId;
        if (!mounted) return;
        setState(() => _backfillProgress = '已更新 $updated 筆目錄欄位');
        if (result.done) {
          if (!result.ready) {
            throw LegalPetException('這次補齊沒有從第一筆完成，請再按一次補齊搜尋欄位');
          }
          break;
        }
        cursor = result.nextCursor;
        if (cursor.isEmpty) {
          throw LegalPetException('補齊沒有取得下一筆位置，請再按一次補齊搜尋欄位');
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('搜尋欄位已補齊，更新 $updated 筆')),
      );
      _resetPage();
      await _load();
    } on LegalPetException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _backfilling = false;
          _backfillProgress = '';
        });
      }
    }
  }

  Future<void> _onContactSaved(String govId) async {
    _clearPageCache();
    await _load();
    if (!mounted) return;
    final still = _items.any((item) => item.govId == govId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(still ? '聯繫紀錄已儲存' : '已儲存。這筆已不符合目前篩選'),
      ),
    );
  }

  void _openDetail(String govId, bool wide) {
    setState(() => _lists.selectedId = govId);
    if (wide) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _LegalPetDetailPage(
          govId: govId,
          onSaved: () => _onContactSaved(govId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final selectedId = _lists.selectedId;
        return Scaffold(
          appBar: AppBar(
            title: const Text('業者資料庫'),
            actions: [
              TextButton(
                onPressed: _syncing || _backfilling ? null : _runSync,
                child: Text(_syncing ? '同步中' : '手動同步'),
              ),
            ],
          ),
          body: Column(
            children: [
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.46,
                ),
                child: SingleChildScrollView(
                  child: _toolbar(constraints.maxWidth, wide),
                ),
              ),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                Expanded(child: _results(true)),
                                _pager(),
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            flex: 6,
                            child: selectedId == null
                                ? const Center(child: Text('請選擇一筆業者'))
                                : _LegalPetDetailPane(
                                    key: ValueKey(selectedId),
                                    govId: selectedId,
                                    onSaved: () => _onContactSaved(selectedId),
                                  ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: _results(false)),
                          _pager(),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _toolbar(double width, bool wide) {
    final searchWidth = width >= 720 ? 360.0 : width - 24;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: searchWidth < 180 ? width - 24 : searchWidth,
                child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: '搜尋店名或許可證字號',
                    helperText: '店名可輸入一個字或一段。字號比對完整許可證字號。Enter 或按搜尋才查詢。',
                  ),
                  onSubmitted: (_) => _submitSearch(),
                ),
              ),
              FilledButton(
                onPressed: _loading ? null : _submitSearch,
                child: const Text('搜尋'),
              ),
              OutlinedButton(
                onPressed: _loading ? null : _clearSearch,
                child: const Text('清除搜尋'),
              ),
              TextButton(
                onPressed: _loading ? null : _clearAll,
                child: const Text('清除全部'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('貓咪寄養'),
                selected: _animal == 'cat' &&
                    _bus == 'boarding' &&
                    _businessState == 'operating',
                onSelected: (_) => _toggleQuick(
                  animal: 'cat',
                  bus: 'boarding',
                  businessState: 'operating',
                ),
              ),
              FilterChip(
                label: const Text('尚無對應'),
                selected: _linkStatus == 'none',
                onSelected: (_) => _toggleQuick(linkStatus: 'none'),
              ),
              FilterChip(
                label: const Text('待跟進'),
                selected: _contactStatus == 'follow_up',
                onSelected: (_) => _toggleQuick(contactStatus: 'follow_up'),
              ),
              FilterChip(
                label: const Text('已認證綁定'),
                selected: _linkStatus == 'certified',
                onSelected: (_) => _toggleQuick(linkStatus: 'certified'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (wide) _filterMenus() else _moreFilters(),
          const SizedBox(height: 8),
          Text(
            directorySyncHeadline(
              phase: _sync.phase,
              successText: _sync.successText,
              hasItems: _items.isNotEmpty,
            ),
          ),
          if (_sync.checkedText.isNotEmpty)
            Text('最近成功檢查：${_sync.checkedText}'),
          Text(
            _sync.contentChangedText.isEmpty
                ? '政府內容最近變動：尚未記錄'
                : '政府內容最近變動：${_sync.contentChangedText}',
          ),
          if (_sync.sourceUnchanged) const Text('這次檢查的政府名單沒有變動'),
          if (_staleBackend && _error == null)
            const Text(staleDirectoryBackendMessage),
          if (!_sync.directoryReady && !_needsBackfill && _error == null)
            const Text(
              '目錄欄位尚未補齊。店名、字號與區域篩選不會改成列出全部業者。請按補齊搜尋欄位。',
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _syncing || _backfilling ? null : _backfillLookup,
              child: const Text('補齊字號查核'),
            ),
          ),
          if (_sync.phase == 'failed' && _sync.errorSummary.isNotEmpty)
            Text('失敗摘要：${_sync.errorSummary}'),
          if (_backfillProgress.isNotEmpty) Text(_backfillProgress),
        ],
      ),
    );
  }

  Widget _moreFilters() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('更多篩選'),
      children: [
        Align(alignment: Alignment.centerLeft, child: _filterMenus()),
      ],
    );
  }

  Widget _filterMenus() {
    final districtItems = <String, String>{
      '': '全部區域',
      'pending': '區域待確認',
      for (final name in _districts[_county] ?? const <String>[]) name: name,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _menu(
          label: '縣市',
          value: _county,
          items: {'': '全部縣市', ..._counties},
          onChanged: (value) => _applyFilters({'county': value, 'district': ''}),
        ),
        _menu(
          label: '區域',
          value: districtItems.containsKey(_district) ? _district : '',
          items: districtItems,
          onChanged: (value) => _applyFilters({'district': value}),
        ),
        _menu(
          label: '寵物',
          value: _animal,
          items: const {
            '': '全部',
            'cat': '含貓',
            'dog': '含狗',
            'both': '貓狗皆有',
          },
          onChanged: (value) => _applyFilters({'animal': value}),
        ),
        _menu(
          label: '營業項目',
          value: _bus,
          items: const {
            '': '全部',
            'boarding': '含寄養',
            'sale': '含買賣',
            'breeding': '含繁殖',
          },
          onChanged: (value) => _applyFilters({'bus': value}),
        ),
        _menu(
          label: '營業狀態',
          value: _businessState,
          items: const {
            '': '全部',
            'operating': '營業中',
            'closed': '歇業',
            'suspended': '停業',
            'revoked': '廢止',
            'unknown': '待確認',
          },
          onChanged: (value) => _applyFilters({'businessState': value}),
        ),
        _menu(
          label: '證照有效性',
          value: _validity,
          items: const {
            '': '全部',
            'valid': '有效',
            'expired': '已過期',
            'unknown': '日期不明',
          },
          onChanged: (value) => _applyFilters({'validity': value}),
        ),
        _menu(
          label: 'PetNest 對應',
          value: _linkStatus,
          items: const {
            '': '全部',
            'certified': '已認證綁定',
            'candidate': '待認證／疑似對應',
            'none': '尚無對應',
          },
          onChanged: (value) => _applyFilters({'linkStatus': value}),
        ),
        _menu(
          label: '聯繫進度',
          value: _contactStatus,
          items: const {
            '': '全部',
            'not_contacted': '未聯繫',
            'contacted': '已聯繫',
            'follow_up': '待跟進',
            'no_interest': '無意願',
          },
          onChanged: (value) => _applyFilters({'contactStatus': value}),
        ),
      ],
    );
  }

  Widget _menu({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    final current = items.containsKey(value) ? value : '';
    return DropdownButton<String>(
      value: current,
      items: items.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text('$label：${entry.value}'),
            ),
          )
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Widget _results(bool wide) {
    if (_error != null) {
      return _notice(
        _error!,
        action: FilledButton(onPressed: _load, child: const Text('重試')),
      );
    }
    if (_needsBackfill || _outcome == 'needs_backfill') {
      return _notice(
        '既有政府名單尚未補齊搜尋與分類欄位。補齊只更新目錄欄位，不會刪除政府資料、修改店家或覆蓋聯繫紀錄。',
        action: FilledButton(
          onPressed: _backfilling ? null : _backfill,
          child: Text(_backfilling ? '補齊中' : '補齊搜尋欄位'),
        ),
      );
    }
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_outcome == 'not_synced' && _items.isEmpty) {
      return _notice('尚未同步政府資料');
    }
    if (_items.isEmpty && _hasMore) {
      return _notice('這一段沒有符合的業者，可按下一頁繼續找。');
    }
    if (_items.isEmpty) {
      return _notice('沒有符合的業者');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final item = _items[index];
        final selected = item.govId == _lists.selectedId;
        final theme = Theme.of(context);
        return Material(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _openDetail(item.govId, wide),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.legalname.isEmpty ? '未提供名稱' : item.legalname,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(item.placeLabel),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Tag(item.animalLabel),
                      _Tag(item.busitemLabel),
                      _Tag(_linkLabel(item.linkStatus, item.candidateCount)),
                      _Tag(_contactLabel(item.contactStatus)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.validnum.isEmpty ? '未提供字號' : item.validnum,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _notice(String message, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 12),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _pager() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text('第 ${_lists.pageIndex + 1} 頁'),
          if (_candidateReads > 0)
            Text('本次讀取候選 $_candidateReads 筆'),
          OutlinedButton(
            onPressed: _lists.pageIndex == 0 || _loading
                ? null
                : () {
                    setState(() => _lists.pageIndex -= 1);
                    _load(allowCache: true);
                  },
            child: const Text('上一頁'),
          ),
          OutlinedButton(
            onPressed: !_hasMore || _loading
                ? null
                : () {
                    if (_lists.cursors.length <= _lists.pageIndex + 1) {
                      _lists.cursors.add(_nextCursor);
                    }
                    setState(() => _lists.pageIndex += 1);
                    _load();
                  },
            child: const Text('下一頁'),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

String _validityText(Object? value) {
  switch (value) {
    case 'valid':
      return '有效';
    case 'expired':
      return '已過期';
    case 'unknown':
      return '日期不明';
    default:
      return '日期不明';
  }
}

String _linkLabel(String value, int count) {
  switch (value) {
    case 'certified':
      return '已認證綁定';
    case 'candidate':
      return count > 1 ? '待認證／疑似對應 · $count' : '待認證／疑似對應';
    case 'unknown':
      return '對應狀態待補齊';
    default:
      return '尚無對應';
  }
}

String _contactLabel(String value) {
  switch (value) {
    case 'contacted':
      return '已聯繫';
    case 'follow_up':
      return '待跟進';
    case 'no_interest':
      return '無意願';
    case 'unknown':
      return '聯繫狀態待補齊';
    default:
      return '未聯繫';
  }
}

class _LegalPetDetailPage extends StatelessWidget {
  const _LegalPetDetailPage({required this.govId, required this.onSaved});

  final String govId;
  final Future<void> Function() onSaved;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('業者詳細資料')),
      body: _LegalPetDetailPane(govId: govId, onSaved: onSaved),
    );
  }
}

class _LegalPetDetailPane extends StatefulWidget {
  const _LegalPetDetailPane({
    super.key,
    required this.govId,
    required this.onSaved,
  });

  final String govId;
  final Future<void> Function() onSaved;

  @override
  State<_LegalPetDetailPane> createState() => _LegalPetDetailPaneState();
}

class _LegalPetDetailPaneState extends State<_LegalPetDetailPane> {
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _note = TextEditingController();
  final _follow = TextEditingController();
  final DirectoryLoadGate _gate = DirectoryLoadGate();
  String _status = 'not_contacted';
  String _salesRepId = '';
  List<Map<String, dynamic>> _reps = const [];
  bool _canAssignSales = false;
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReps();
    _load();
  }

  Future<void> _loadReps() async {
    try {
      final reps = await ShopCommercialService.instance.listSalesReps();
      if (!mounted) return;
      setState(() {
        _reps = reps;
        _canAssignSales = true;
      });
    } on ShopCommercialException {
      _canAssignSales = false;
    }
  }

  @override
  void didUpdateWidget(covariant _LegalPetDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.govId != widget.govId) {
      _load();
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _website.dispose();
    _note.dispose();
    _follow.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = _gate.issue();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await LegalPetService.instance.getBusiness(widget.govId);
      if (!mounted || !_gate.isCurrent(requestId)) return;
      final contact = data['contact'] is Map
          ? Map<String, dynamic>.from(data['contact'] as Map)
          : const <String, dynamic>{};
      _phone.text = (contact['phone'] ?? '').toString();
      _website.text = (contact['website'] ?? '').toString();
      _note.text = (contact['note'] ?? '').toString();
      _follow.text = (contact['nextFollowUpDate'] ?? '').toString();
      _status = (contact['contactStatus'] ?? 'not_contacted').toString();
      _salesRepId = (contact['salesRepId'] ?? '').toString();
      _data = data;
    } on LegalPetException catch (error) {
      if (!mounted || !_gate.isCurrent(requestId)) return;
      _error = error.message;
    } finally {
      if (mounted && _gate.isCurrent(requestId)) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await LegalPetService.instance.updateContact({
        'govId': widget.govId,
        'contactStatus': _status,
        'phone': _phone.text,
        'website': _website.text,
        'note': _note.text,
        'nextFollowUpDate': _follow.text.trim(),
        if (_canAssignSales) 'salesRepId': _salesRepId,
      });
      if (!mounted) return;
      await widget.onSaved();
    } on LegalPetException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重試')),
          ],
        ),
      );
    }
    final government = _data!['government'] is Map
        ? Map<String, dynamic>.from(_data!['government'] as Map)
        : const <String, dynamic>{};
    final activities = _data!['activities'] is List
        ? _data!['activities'] as List
        : const [];
    final districtPending = government['districtPending'] == true;
    final rawDistrict = (government['districtLabel'] ?? '').toString();
    final district = districtPending || rawDistrict.isEmpty
        ? '區域待確認'
        : rawDistrict;
    final followText = _follow.text.trim().isEmpty ? '尚未設定' : _follow.text.trim();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('政府資料', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text('來源：${government['sourceName'] ?? '農業部合法特定寵物業名單'}'),
        Text('名稱：${government['legalname'] ?? ''}'),
        Text('地址：${government['legaladdress'] ?? ''}'),
        Text('縣市：${government['countyLabel'] ?? ''}'),
        Text('區域：$district'),
        Text('字號：${government['validnum'] ?? ''}'),
        Text('有效日期：${government['validDate'] ?? government['validdateRaw'] ?? ''}'),
        Text('證照有效性：${_validityText(government['validity'])}'),
        Text('營業項目：${government['busitemLabel'] ?? ''}'),
        Text('寵物種類：${government['animalLabel'] ?? ''}'),
        Text('營業狀態：${government['stateLabel'] ?? ''}'),
        const SizedBox(height: 16),
        Text('PetNest 對應', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          '對應狀態：${_linkLabel((_data!['linkStatus'] ?? '').toString(), (_data!['candidateCount'] as num?)?.toInt() ?? activities.length)}',
        ),
        const Text('尚無對應只表示目前沒有對上平台店家，不代表對方沒有使用 PetNest。'),
        if ((_data!['attributionWarning'] ?? '').toString().isNotEmpty)
          Text('${_data!['attributionWarning']}'),
        if (_data!['commercial'] is Map)
          Text(
            '店家訂閱：${commercialStatusLabel('${(_data!['commercial'] as Map)['listStatus']}')}'
            '｜來源 ${commercialSourceLabel('${(_data!['commercial'] as Map)['shopSource']}')}'
            '｜負責 ${(_data!['commercial'] as Map)['currentSalesName'] ?? '未指派'}',
          ),
        if (activities.isEmpty) const Text('目前沒有可顯示的候選或已認證店家。'),
        ...activities.whereType<Map>().map((item) {
          final row = Map<String, dynamic>.from(item);
          final relation = row['relation'] == 'certified' ? '已認證綁定' : '候選';
          final active = (row['lastActiveAt'] ?? '').toString();
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '$relation｜${row['shopName'] ?? row['shopId']}｜'
              '公開：${row['isPublic'] == true ? '是' : '否'}｜'
              '字號認證：${row['licenseVerified'] == true ? '是' : '否'}｜'
              '店主最後活躍：${active.isEmpty ? '無' : active}',
            ),
          );
        }),
        const SizedBox(height: 16),
        if (_canAssignSales)
          DropdownButtonFormField<String>(
            initialValue: _reps.any((rep) => rep['repId'] == _salesRepId)
                ? _salesRepId
                : '',
            decoration: const InputDecoration(labelText: '負責開發業務'),
            items: [
              const DropdownMenuItem(value: '', child: Text('尚未指派')),
              ..._reps.map((rep) {
                return DropdownMenuItem(
                  value: '${rep['repId']}',
                  child: Text('${rep['displayName'] ?? ''}'),
                );
              }),
            ],
            onChanged: (value) => setState(() => _salesRepId = value ?? ''),
          ),
        Text('聯繫紀錄（平台人員）', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text('以下電話、網站、備註與進度是人工補登。這份政府名單沒有電話與 Email，政府同步不會覆蓋這裡。'),
        Text('目前下次跟進：$followText'),
        DropdownButton<String>(
          value: _status,
          items: const [
            DropdownMenuItem(value: 'not_contacted', child: Text('未聯繫')),
            DropdownMenuItem(value: 'contacted', child: Text('已聯繫')),
            DropdownMenuItem(value: 'follow_up', child: Text('待跟進')),
            DropdownMenuItem(value: 'no_interest', child: Text('無意願')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _status = value);
          },
        ),
        TextField(
          controller: _phone,
          decoration: const InputDecoration(labelText: '補登電話'),
        ),
        TextField(
          controller: _website,
          decoration: const InputDecoration(labelText: '補登網站'),
        ),
        TextField(
          controller: _follow,
          decoration: const InputDecoration(
            labelText: '下次跟進',
            hintText: '沒有就不填，格式 YYYY-MM-DD',
          ),
        ),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '備註'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '儲存中' : '儲存聯繫紀錄'),
        ),
      ],
    );
  }
}
