// 檔案名稱：lib/features/platform/pages/platform_sales_rep_manage_page.dart
// 功能說明：查看業務、篩選狀態，並把未綁定的舊業務接到既有平台帳號。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/platform_permission_keys.dart';
import 'package:petnest_saas/core/services/shop_commercial_service.dart';
import 'package:petnest_saas/features/platform/pages/platform_activation_code_manage_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_sales_performance_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_user_management_page.dart';

class PlatformSalesRepManagePage extends StatefulWidget {
  const PlatformSalesRepManagePage({super.key});

  @override
  State<PlatformSalesRepManagePage> createState() =>
      _PlatformSalesRepManagePageState();
}

class _PlatformSalesRepManagePageState extends State<PlatformSalesRepManagePage> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _reps = const [];
  String? _selectedId;
  String _status = '';
  String _nextCursor = '';
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _staleService;
  bool _permissionDenied = false;
  bool _mobileDetail = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loadingMore || _nextCursor.isEmpty)) return;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
        _staleService = null;
        _permissionDenied = false;
      }
    });
    try {
      final data = await ShopCommercialService.instance.listSalesRepsPage(
        query: _search.text.trim(),
        status: _status,
        cursor: more ? _nextCursor : '',
      );
      if (!mounted) return;
      final reps = (data['reps'] as List? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      final stale = !data.containsKey('nextCursor');
      setState(() {
        _reps = more ? <Map<String, dynamic>>[..._reps, ...reps] : reps;
        _nextCursor = (data['nextCursor'] ?? '').toString();
        _loading = false;
        _loadingMore = false;
        _error = null;
        _staleService = stale
            ? '目前連到的業務列表是舊版服務。缺少姓名的業務不會出現，這不代表沒有業務。需要部署 listSalesReps。'
            : null;
      });
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      final message = error.notFound
          ? '業務列表服務還沒有部署到正式環境。這不是「沒有業務」。'
          : error.message;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (!more) {
          _error = message;
          _permissionDenied = error.permissionDenied;
        }
      });
      if (more) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  Future<void> _openPersonnel() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlatformUserManagementPage()),
    );
    if (mounted) await _load();
  }

  Future<void> _bind(Map<String, dynamic> rep) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _BindMemberDialog(repId: '${rep['repId']}'),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _reps.cast<Map<String, dynamic>?>().firstWhere(
      (rep) => rep?['repId'] == _selectedId,
      orElse: () => null,
    );
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
      appBar: AppBar(
        title: const Text('業務管理'),
        leading: _mobileDetail
            ? BackButton(onPressed: () => setState(() => _mobileDetail = false))
            : null,
      ),
      floatingActionButton: _permissionDenied || _mobileDetail
          ? null
          : FloatingActionButton.extended(
              onPressed: _openPersonnel,
              icon: const Icon(Icons.badge_outlined),
              label: Text(wide ? '前往平台人員與權限' : '平台人員與權限'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _permissionDenied
          ? const Center(child: Text('沒有查看或管理業務的權限'))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('重試')),
                  ],
                ),
              ),
            )
          : _body(wide, selected),
    );
  }

  Widget _filters() {
    final enabledCount = _reps.where((rep) {
      return rep['enabled'] == true && rep['bindingStatus'] != 'pending';
    }).length;
    final disabledCount = _reps.where((rep) {
      return rep['enabled'] != true && rep['bindingStatus'] != 'pending';
    }).length;
    final pendingCount = _reps.where((rep) {
      return rep['bindingStatus'] == 'pending';
    }).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('本頁 ${_reps.length} 位')),
              Chip(label: Text('啟用 $enabledCount')),
              Chip(label: Text('停用 $disabledCount')),
              Chip(label: Text('待綁定 $pendingCount')),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: '搜尋業務',
              hintText: '姓名或 Email',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => _load(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('全部'),
                selected: _status.isEmpty,
                onSelected: (_) => _setStatus(''),
              ),
              ChoiceChip(
                label: const Text('啟用'),
                selected: _status == 'enabled',
                onSelected: (_) => _setStatus('enabled'),
              ),
              ChoiceChip(
                label: const Text('停用'),
                selected: _status == 'disabled',
                onSelected: (_) => _setStatus('disabled'),
              ),
              ChoiceChip(
                label: const Text('待綁定'),
                selected: _status == 'pending',
                onSelected: (_) => _setStatus('pending'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setStatus(String status) {
    setState(() => _status = status);
    _load();
  }

  Widget _body(bool wide, Map<String, dynamic>? selected) {
    if (_reps.isEmpty && _nextCursor.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          _filters(),
          const SizedBox(height: 32),
          Icon(
            _staleService == null ? Icons.badge_outlined : Icons.cloud_off,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            _staleService ?? '目前沒有業務資料',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '業務身分由平台人員與權限設定。不會另外建立登入帳號。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: _openPersonnel,
              child: const Text('前往平台人員與權限'),
            ),
          ),
        ],
      );
    }
    if (_reps.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          _filters(),
          const SizedBox(height: 24),
          const Text('這一段沒有符合的業務，後面還有資料。', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: FilledButton(
              onPressed: _loadingMore ? null : () => _load(more: true),
              child: Text(_loadingMore ? '載入中' : '繼續搜尋'),
            ),
          ),
        ],
      );
    }
    final list = ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 88),
      itemCount: _reps.length + 2,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _filters(),
              if (_staleService != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(_staleService!),
                ),
            ],
          );
        }
        if (index == _reps.length + 1) {
          if (_nextCursor.isEmpty) return const SizedBox(height: 8);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: _loadingMore ? null : () => _load(more: true),
              child: Text(_loadingMore ? '載入中' : '載入更多業務'),
            ),
          );
        }
        final rep = _reps[index - 1];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _RepCard(
          rep: rep,
          selected: rep['repId'] == _selectedId,
          onTap: () {
            setState(() {
              _selectedId = '${rep['repId']}';
              if (!wide) _mobileDetail = true;
            });
          },
        ),
        );
      },
    );
    final detail = selected == null
        ? const Center(child: Text('請選擇一位業務'))
        : _RepDetail(rep: selected, onBind: () => _bind(selected));
    if (!wide) {
      return _mobileDetail && selected != null ? detail : list;
    }
    return Row(
      children: [
        SizedBox(width: 360, child: list),
        const VerticalDivider(width: 1),
        Expanded(child: detail),
      ],
    );
  }
}

class _RepCard extends StatelessWidget {
  const _RepCard({
    required this.rep,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> rep;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = rep['enabled'] == true;
    final pending = rep['bindingStatus'] == 'pending';
    final missing = rep['nameMissing'] == true;
    return Card(
      child: ListTile(
        selected: selected,
        title: Text(
          '${rep['displayName'] ?? '未命名業務'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (pending) '待綁定',
            if (!pending && enabled) '啟用中',
            if (!pending && !enabled) '已停用，歷史仍保留',
            if (missing) '資料不完整',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: pending ? const Icon(Icons.link_off) : null,
        onTap: onTap,
      ),
    );
  }
}

class _RepDetail extends StatefulWidget {
  const _RepDetail({required this.rep, required this.onBind});

  final Map<String, dynamic> rep;
  final VoidCallback onBind;

  @override
  State<_RepDetail> createState() => _RepDetailState();
}

class _RepDetailState extends State<_RepDetail> {
  String? _extra;
  bool _busy = false;

  Future<void> _shops() async {
    setState(() {
      _busy = true;
      _extra = null;
    });
    try {
      final data = await ShopCommercialService.instance.listResponsibleShops(
        repId: '${widget.rep['repId']}',
      );
      if (!mounted) return;
      final queried = (data['queriedRepId'] ?? '').toString();
      if (queried != '${widget.rep['repId']}') {
        setState(() {
          _busy = false;
          _extra = queried.isEmpty
              ? '負責店家需要部署後才能核對查詢範圍。'
              : '沒有查看這位業務負責店家的權限。';
        });
        return;
      }
      final items = (data['items'] as List? ?? const []).whereType<Map>();
      final names = items
          .map((item) => '${item['name'] ?? item['shopId'] ?? ''}')
          .where((name) => name.isNotEmpty)
          .take(8)
          .join('、');
      setState(() {
        _busy = false;
        _extra = '目前負責的付費店家 ${data['total'] ?? items.length} 間。$names';
      });
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _extra = error.message;
      });
    }
  }

  Future<void> _commission() async {
    setState(() {
      _busy = true;
      _extra = null;
    });
    try {
      final data = await ShopCommercialService.instance.listCommissionEntries(
        repId: '${widget.rep['repId']}',
      );
      if (!mounted) return;
      final queried = (data['queriedRepId'] ?? '').toString();
      if (queried != '${widget.rep['repId']}') {
        setState(() {
          _busy = false;
          _extra = queried.isEmpty
              ? '分潤明細需要部署後才能核對查詢範圍。'
              : '沒有查看這位業務分潤的權限。';
        });
        return;
      }
      final items = (data['items'] as List? ?? const []).whereType<Map>();
      setState(() {
        _busy = false;
        _extra = '這位業務的分潤明細 ${data['pageCount'] ?? items.length} 筆。金額只在有結算權限時出現。';
      });
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _extra = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rep = widget.rep;
    final pending = rep['bindingStatus'] == 'pending';
    final events = (rep['recentEvents'] as List? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${rep['displayName'] ?? '未命名業務'}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(pending ? '平台帳號：待綁定' : '平台帳號：已綁定'),
        Text('業務狀態：${rep['enabled'] == true ? '啟用' : '停用'}'),
        if (rep['nameMissing'] == true)
          const Text('資料不完整：缺少姓名。這筆舊資料仍保留，沒有被刪除。'),
        if ('${rep['phone'] ?? ''}'.isNotEmpty) Text('電話：${rep['phone']}'),
        if ('${rep['email'] ?? ''}'.isNotEmpty) Text('Email：${rep['email']}'),
        if ('${rep['note'] ?? ''}'.isNotEmpty) Text('備註：${rep['note']}'),
        const SizedBox(height: 12),
        const Text('負責店家只看激活碼與開發歸屬，不會因為兼任業務就把全部店家算進來。'),
        const SizedBox(height: 8),
        Text(
          '業務權限沿用平台人員的個別權限，例如${PlatformPermissionKeys.label(PlatformPermissionKeys.viewOwnSales)}。兼任業務不會自動變成平台管理員。',
        ),
        const SizedBox(height: 12),
        if (pending)
          FilledButton(
            onPressed: widget.onBind,
            child: const Text('綁定既有平台會員'),
          ),
        if (pending) const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _shops,
          child: const Text('查看目前負責的付費店家'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlatformActivationCodeManagePage(
                  initialSalesRepId: '${rep['repId']}',
                ),
              ),
            );
          },
          child: const Text('查看專屬激活碼'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PlatformSalesPerformancePage(),
              ),
            );
          },
          child: const Text('查看業務績效'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _commission,
          child: const Text('查看分潤'),
        ),
        if (_extra != null) ...[
          const SizedBox(height: 12),
          Text(_extra!),
        ],
        if (events.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('操作紀錄', style: Theme.of(context).textTheme.titleMedium),
          for (final event in events)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${event['action'] ?? '更新'}'),
              subtitle: Text('${event['at'] ?? ''}'),
            ),
        ],
      ],
    );
  }
}

class _BindMemberDialog extends StatefulWidget {
  const _BindMemberDialog({required this.repId});

  final String repId;

  @override
  State<_BindMemberDialog> createState() => _BindMemberDialogState();
}

class _BindMemberDialogState extends State<_BindMemberDialog> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _members = const [];
  String _cursor = '';
  String? _selectedUid;
  String? _error;
  String? _staleService;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ShopCommercialService.instance.searchPlatformMembers(
        query: _search.text.trim(),
        cursor: more ? _cursor : '',
      );
      if (!mounted) return;
      final members = (data['members'] as List? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      setState(() {
        _members = more
            ? <Map<String, dynamic>>[..._members, ...members]
            : members;
        _cursor = (data['nextCursor'] ?? '').toString();
        _staleService = data.containsKey('nextCursor')
            ? null
            : '會員搜尋仍是舊版，不能當成超過原本一批的完整結果。需要部署 listAssignablePlatformMembers。';
        _loading = false;
      });
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _save() async {
    final uid = _selectedUid;
    if (uid == null || uid.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ShopCommercialService.instance.saveSalesRep({
        'repId': widget.repId,
        'platformUid': uid,
        'enabled': true,
      });
      if (mounted) Navigator.pop(context, true);
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('綁定既有平台會員'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('綁定後沿用原來的業務編號並啟用這筆業務。不會刪除舊業績、激活碼或分潤。'),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: '搜尋平台會員',
                hintText: '姓名或 Email',
                suffixIcon: IconButton(
                  onPressed: () => _load(),
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
            if (_staleService != null) ...[
              const SizedBox(height: 8),
              Text(_staleService!),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('重試'),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _members.length + (_cursor.isEmpty ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (index == _members.length) {
                          return TextButton(
                            onPressed: () => _load(more: true),
                            child: const Text('繼續搜尋'),
                          );
                        }
                        final member = _members[index];
                        final uid = '${member['uid']}';
                        final bound = '${member['boundRepId'] ?? ''}';
                        final taken = bound.isNotEmpty && bound != widget.repId;
                        final disabled = member['enabled'] == false;
                        return ListTile(
                          enabled: !taken && !disabled,
                          selected: _selectedUid == uid,
                          onTap: taken || disabled
                              ? null
                              : () => setState(() => _selectedUid = uid),
                          title: Text(
                            '${member['name'] ?? '未命名'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            taken
                                ? '已指派'
                                : disabled
                                ? '平台帳號已停用'
                                : '${member['email'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selectedUid == null || _saving ? null : _save,
          child: Text(_saving ? '綁定中' : '綁定'),
        ),
      ],
    );
  }
}
