import 'package:petnest_saas/features/shop/widgets/shop_feature_tour.dart';
// 檔案名稱：lib/features/shop/pages/shop_policy_page.dart
// 功能說明：條款設定：住宿／安親／退款分頁編輯，同意紀錄在同一頁查看

import 'dart:async';
import 'dart:convert';
import 'package:petnest_saas/core/services/policy_url_validation.dart';
import 'package:petnest_saas/features/shop/widgets/shop_policy_parameters_dialog.dart';
import 'package:petnest_saas/features/shop/models/shop_policy_templates.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_policy_history.dart';

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/features/shop/pages/policy_version_detail_page.dart';
import 'package:petnest_saas/features/shop/pages/policy_version_history_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_logs_page.dart';

class ShopPolicyPage extends StatefulWidget {
  const ShopPolicyPage({super.key, required this.shopId, this.canEdit = true});

  final String shopId;

  /// 沒有編輯條款權限時只顯示同意紀錄，不開放修改。
  final bool canEdit;

  @override
  State<ShopPolicyPage> createState() => _ShopPolicyPageState();
}

class _ShopPolicyPageState extends State<ShopPolicyPage>
    with
        SingleTickerProviderStateMixin,
        ShopDashboardLeaveAware<ShopPolicyPage> {
  @override
  bool get dashboardHasUnsavedChanges => widget.canEdit && _dirty;
  @override
  bool get dashboardIsBusy => _saving;
  TabController? _tabs;
  StreamSubscription<Map<String, dynamic>?>? _shopSub;
  bool _daycareOn = false;
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{
        'checkinTime': TextEditingController(),
        'checkOutFlow': TextEditingController(),
        'basicCondition': TextEditingController(),
        'ownerNotice': TextEditingController(),
        'checkinNotice': TextEditingController(),
        'facility': TextEditingController(),
        'specialCase': TextEditingController(),
        'activity': TextEditingController(),
        'extraNotice': TextEditingController(),
        'cancelPolicy': TextEditingController(),
      };
  Map<String, bool> _enabled = <String, bool>{
    'checkinTime': true,
    'checkOutFlow': true,
    'basicCondition': true,
    'ownerNotice': true,
    'checkinNotice': true,
    'facility': true,
    'specialCase': true,
    'activity': true,
    'extraNotice': true,
    'cancelPolicy': true,
  };
  final Map<String, Map<String, String>> _drafts =
      <String, Map<String, String>>{
        PolicyApplicableService.accommodation: <String, String>{},
        PolicyApplicableService.daycare: <String, String>{},
      };
  final Map<String, Map<String, bool>> _enabledDrafts =
      <String, Map<String, bool>>{
        PolicyApplicableService.accommodation: <String, bool>{},
        PolicyApplicableService.daycare: <String, bool>{},
      };
  final TextEditingController _refundTitle = TextEditingController(
    text: '退款條款',
  );
  final TextEditingController _refundDescription = TextEditingController();
  final TextEditingController _refundBody = TextEditingController();
  bool _refundEnabled = true;
  Object? _tourError;
  bool _loading = true;
  bool _dirty = false;
  bool _saving = false;
  bool _templateBusy = false;
  bool _confirmingPublish = false;
  String? _publishedRefundBody;
  String _savedRefundFingerprint = '';
  String get _refundFingerprint => jsonEncode([
    _refundTitle.text,
    _refundDescription.text,
    _refundBody.text,
    _refundEnabled,
  ]);

  Future<void> _refreshPublishedVersion() async {
    _storeDraftAt(_tabs!.index);
    final data = await ShopService.instance.getCheckinPolicy(widget.shopId);
    if (!mounted || data == null) return;
    setState(() {
      _policy = data;
      _stayVersion = ShopPolicyService.servicePolicyVersion(
        policy: data,
        serviceType: PolicyApplicableService.accommodation,
      );
      _daycareVersion = ShopPolicyService.servicePolicyVersion(
        policy: data,
        serviceType: PolicyApplicableService.daycare,
      );
      final at = data['updatedAt'];
      _policyUpdatedAt = at is Timestamp
          ? at.toDate()
          : at is DateTime
          ? at
          : null;
      _dirty =
          _refundFingerprint != _savedRefundFingerprint ||
          _customChanged.isNotEmpty;
      for (final entry in _drafts.entries) {
        final filtered = ShopPolicyService.instance.filterPolicyForService(
          policy: data,
          serviceType: entry.key,
        );
        final sections = Map<String, dynamic>.from(filtered['sections'] ?? {});
        final enabled = Map<String, dynamic>.from(filtered['enabled'] ?? {});
        if (entry.value.entries.any(
              (e) =>
                  e.value.trim() != (sections[e.key] ?? '').toString().trim(),
            ) ||
            (_enabledDrafts[entry.key] ?? {}).entries.any(
              (e) => e.value != (enabled[e.key] != false),
            )) {
          _dirty = true;
        }
      }
    });
  }

  bool get _canUseTemplate =>
      widget.canEdit &&
      !_loading &&
      !_saving &&
      !_confirmingPublish &&
      _tabs?.index == 0;

  Map<String, String> get _draftTexts =>
      _controllers.map((key, controller) => MapEntry(key, controller.text));
  List<ShopPolicyParameter> get _pendingParameters =>
      ShopPolicyTemplates.missing(_draftTexts, _enabled);
  final Map<String, GlobalKey> _textKeys = {};
  final Map<String, FocusNode> _textFocus = {};
  final Map<String, Map<String, List<String>>> _customDrafts = {};
  final Set<String> _customChanged = {};

  List<PolicyTextField> _policyFields(String service) {
    final filtered = ShopPolicyService.instance.filterPolicyForService(
      policy: _policy ?? {},
      serviceType: service,
    );
    return PolicyUrlValidation.policyFields({
      ...filtered,
      'sections': _draftTexts,
      'enabled': _enabled,
      if (_customChanged.contains(service)) ...{
        'customPoliciesPage1': _customDrafts[service]!['page1'],
        'customPoliciesPage2': _customDrafts[service]!['page2'],
      },
    }, service);
  }

  List<PolicyUrlIssue> get _urlIssues => PolicyUrlValidation.inspect(
    _tabs?.index == _refundIndex
        ? PolicyUrlValidation.refundFields(
            title: _refundTitle.text,
            description: _refundDescription.text,
            body: _refundBody.text,
            enabled: _refundEnabled,
          )
        : _policyFields(_activeService),
  );

  void _locateUrl(PolicyUrlIssue issue) {
    if (issue.key.startsWith('customPolicies')) {
      _editCustomIssue(issue);
      return;
    }
    final isRefund = issue.key.startsWith('refund');
    if (!isRefund) setState(() => _expanded.add(issue.key));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final locationKey = isRefund ? issue.key : '$_activeService:${issue.key}';
      final target = _textKeys[locationKey]?.currentContext;
      if (target == null) return;
      await Scrollable.ensureVisible(
        target,
        alignment: .25,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
      );
      if (!mounted) return;
      final controller = isRefund
          ? {
              'refundTitle': _refundTitle,
              'refundDescription': _refundDescription,
              'refundBody': _refundBody,
            }[issue.key]
          : _controllers[issue.key];
      if (controller == null) return;
      final fresh = PolicyUrlValidation.inspect([
        PolicyTextField(issue.key, issue.name, controller.text),
      ]);
      _textFocus[locationKey]?.requestFocus();
      if (fresh.isNotEmpty) {
        controller.selection = TextSelection(
          baseOffset: fresh.first.start,
          extentOffset: fresh.first.end,
        );
      }
    });
  }

  Future<void> _editCustomIssue(PolicyUrlIssue issue) async {
    final parts = issue.key.split('.');
    final page = parts.first.endsWith('1') ? 'page1' : 'page2';
    final index = int.tryParse(parts[1]);
    final service = _activeService;
    final texts = _customDrafts[service]?[page];
    if (index == null || texts == null || index >= texts.length) return;
    final controller = TextEditingController(text: texts[index]);
    controller.selection = TextSelection(
      baseOffset: issue.start.clamp(0, controller.text.length),
      extentOffset: issue.end.clamp(0, controller.text.length),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(issue.name),
        scrollable: true,
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(PolicyUrlValidation.message),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 5,
                maxLines: 12,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('套用到草稿'),
          ),
        ],
      ),
    );
    if (mounted && value != null) {
      setState(() {
        texts[index] = value;
        _customChanged.add(service);
        _dirty = true;
      });
    }
    // Dispose after the route's closing widgets have left the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }

  Widget _urlNotice(List<PolicyUrlIssue> issues) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('含網址，尚無法發布', style: TextStyle(color: Colors.red)),
      const Text(PolicyUrlValidation.message),
      for (final issue in issues) Text('${issue.name}：${issue.excerpt}'),
      TextButton(
        onPressed: () => _locateUrl(issues.first),
        child: const Text('前往修改'),
      ),
    ],
  );

  Future<void> _showPublishIssues(
    List<PolicyUrlIssue> issues, {
    bool includeMissing = true,
  }) async {
    if (_showingMissing) return;
    _showingMissing = true;
    try {
      final fill = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('條款含有網址，尚無法發布'),
          scrollable: true,
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('請移除以下內容中的網址，再重新發布。'),
                for (final issue in issues)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(issue.name),
                    subtitle: Text(issue.excerpt),
                    trailing: const Text('前往修改'),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _locateUrl(issue);
                    },
                  ),
                if (includeMissing &&
                    _tabs?.index == 0 &&
                    _pendingParameters.isNotEmpty) ...[
                  const Text('另外還有待填設定：'),
                  _missingGroups(
                    _pendingParameters,
                    dialogContext: dialogContext,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('返回編輯'),
            ),
            if (includeMissing &&
                _tabs?.index == 0 &&
                _pendingParameters.isNotEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('立即補齊'),
              ),
          ],
        ),
      );
      if (mounted && fill == true) await _completeParameters();
    } finally {
      _showingMissing = false;
    }
  }

  bool _completingParameters = false;
  bool _showingMissing = false;

  Future<void> _completeParameters([String? section]) async {
    if (!_canUseTemplate || _completingParameters) return;
    final pending = _pendingParameters
        .where((p) => section == null || p.sectionKey == section)
        .toList();
    if (pending.isEmpty) return;
    _completingParameters = true;
    try {
      final values = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => ShopPolicyParametersDialog(parameters: pending),
      );
      if (!mounted || values == null || !_canUseTemplate) return;
      final next = ShopPolicyTemplates.fill(_draftTexts, _enabled, values);
      _applyLocal(next, replace: true);
    } finally {
      _completingParameters = false;
    }
  }

  void _locateParameter(String section) {
    if (_tabs?.index != 0) return;
    setState(() => _expanded.add(section));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _tabs?.index != 0) return;
      final target =
          _textKeys['${PolicyApplicableService.accommodation}:$section']
              ?.currentContext;
      if (target == null) return;
      await Scrollable.ensureVisible(
        target,
        alignment: .25,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
      );
      if (!mounted || _tabs?.index != 0) return;
      _textFocus['${PolicyApplicableService.accommodation}:$section']
          ?.requestFocus();
      final controller = _controllers[section]!;
      final pending =
          ShopPolicyTemplates.parameters
              .where((p) => controller.text.contains(p.marker))
              .toList()
            ..sort(
              (a, b) => controller.text
                  .indexOf(a.marker)
                  .compareTo(controller.text.indexOf(b.marker)),
            );
      if (pending.isNotEmpty) {
        final index = controller.text.indexOf(pending.first.marker);
        controller.selection = TextSelection(
          baseOffset: index,
          extentOffset: index + pending.first.marker.length,
        );
      }
    });
  }

  Widget _missingGroups(
    List<ShopPolicyParameter> pending, {
    BuildContext? dialogContext,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final section in pending.map((p) => p.sectionKey).toSet())
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            ShopPolicyHistory.sectionLabel(
              section,
              PolicyApplicableService.accommodation,
            ),
          ),
          subtitle: Text(
            pending
                .where((p) => p.sectionKey == section)
                .map((p) => p.name)
                .join('、'),
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () {
            if (dialogContext != null) Navigator.pop(dialogContext);
            _locateParameter(section);
          },
        ),
    ],
  );

  Future<void> _showMissing({bool publishing = false}) async {
    if (_showingMissing || _saving || _loading) return;
    _showingMissing = true;
    try {
      final pending = _pendingParameters;
      final fill = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(publishing ? '還有資料尚未補齊' : '查看待填位置'),
          scrollable: true,
          content: SizedBox(
            width: 560,
            child: _missingGroups(pending, dialogContext: dialogContext),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('返回編輯'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('立即補齊'),
            ),
          ],
        ),
      );
      if (mounted && fill == true) await _completeParameters();
    } finally {
      _showingMissing = false;
    }
  }

  Widget _pendingCard() {
    final pending = _pendingParameters;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pending.isEmpty
                  ? '待填資料已補齊，請預覽並確認條款內容。'
                  : '還有 ${pending.length} 項店家資料需要補齊',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (pending.isNotEmpty) ...[
              const Text('模板已帶入，請補上本店實際設定，再預覽並確認條款內容。'),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _canUseTemplate
                        ? () => _completeParameters()
                        : null,
                    child: const Text('立即補齊'),
                  ),
                  TextButton(
                    onPressed: () => _showMissing(),
                    child: const Text('查看待填位置'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _applyLocal(Map<String, String> values, {bool replace = false}) {
    if (!_canUseTemplate) return;
    setState(() {
      bool changed = false;
      values.forEach((key, text) {
        if ((replace || _controllers[key]!.text.trim().isEmpty) &&
            _controllers[key]!.text != text) {
          _controllers[key]!.text = text;
          changed = true;
        }
      });
      _storeDraftAt(0);
      _dirty = _dirty || changed;
    });
  }

  Future<bool> _confirmReplacement(String title, String content) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('確認取代'),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _applyTemplate() async {
    if (!_canUseTemplate || _templateBusy) return;
    _templateBusy = true;
    try {
      bool replace = false;
      final selected = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text(ShopPolicyTemplates.name),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(ShopPolicyTemplates.description),
                    const Text('僅填入草稿；【】內為必要待填設定，請補齊或停用該欄位。'),
                    DropdownButtonFormField<bool>(
                      initialValue: false,
                      items: const [
                        DropdownMenuItem(value: false, child: Text('只填入空白欄位')),
                        DropdownMenuItem(value: true, child: Text('取代目前十個欄位')),
                      ],
                      onChanged: (value) =>
                          update(() => replace = value ?? false),
                    ),
                    for (final entry in ShopPolicyTemplates.sections.entries)
                      ExpansionTile(
                        title: Text(
                          ShopPolicyHistory.sectionLabel(
                            entry.key,
                            PolicyApplicableService.accommodation,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(entry.value),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, replace),
                child: const Text('套用到草稿'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || selected == null || !_canUseTemplate) return;
      if (selected &&
          !await _confirmReplacement(
            '取代目前十個欄位？',
            '此操作會取代十個欄位的文字，保留啟用開關與自訂條款。取消不會更動內容。',
          )) {
        return;
      }
      if (mounted) _applyLocal(ShopPolicyTemplates.sections, replace: selected);
    } finally {
      _templateBusy = false;
    }
  }

  Future<void> _applyExample(String key) async {
    if (!_canUseTemplate || _templateBusy) return;
    _templateBusy = true;
    try {
      final example = ShopPolicyTemplates.sections[key]!;
      if (_controllers[key]!.text.trim().isNotEmpty &&
          !await _confirmReplacement('取代此項內容？', example)) {
        return;
      }
      if (mounted) _applyLocal({key: example}, replace: true);
    } finally {
      _templateBusy = false;
    }
  }

  Future<void> _importRefund() async {
    if (!_canUseTemplate || _templateBusy || _publishedRefundBody == null) {
      return;
    }
    _templateBusy = true;
    try {
      bool checked = false;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('帶入已發布的退款條款'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_publishedRefundBody!),
                    CheckboxListTile(
                      value: checked,
                      onChanged: (value) =>
                          update(() => checked = value == true),
                      title: const Text(
                        '我已確認此版本適用住宿，且包含完整金額、計算方式及期限；帶入將取代目前取消政策草稿。',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: checked
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('確認帶入'),
              ),
            ],
          ),
        ),
      );
      if (mounted && accepted == true) {
        _applyLocal({'cancelPolicy': _publishedRefundBody!}, replace: true);
      }
    } finally {
      _templateBusy = false;
    }
  }

  Future<void> _previewDraft() async {
    if (_loading || _saving || _tabs?.index != 0) return;
    final filtered = ShopPolicyService.instance.filterPolicyForService(
      policy: _policy ?? {},
      serviceType: PolicyApplicableService.accommodation,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShopPolicyViewPage(
          shopId: widget.shopId,
          theme: HomeThemeModel.modernDefault,
          readOnly: true,
          draftPendingCount: _pendingParameters.length,
          draftContainsUrls: _urlIssues.isNotEmpty,
          draftPolicy: {
            ...filtered,
            if (_customDrafts[PolicyApplicableService.accommodation] !=
                null) ...{
              'customPoliciesPage1':
                  _customDrafts[PolicyApplicableService
                      .accommodation]!['page1'],
              'customPoliciesPage2':
                  _customDrafts[PolicyApplicableService
                      .accommodation]!['page2'],
            },
            'sections': _controllers.map(
              (key, controller) => MapEntry(key, controller.text),
            ),
            'enabled': Map<String, bool>.from(_enabled),
          },
        ),
      ),
    );
  }

  int _stayVersion = 0;
  int _daycareVersion = 0;
  int _refundVersion = 0;
  Map<String, dynamic>? _policy;
  DateTime? _policyUpdatedAt;
  final Set<String> _expanded = <String>{};

  int get _refundIndex => _daycareOn ? 2 : 1;

  int get _logsIndex => _daycareOn ? 3 : 2;

  bool _isEditorIndex(int index) {
    if (index == 0) {
      return true;
    }
    return _daycareOn && index == 1;
  }

  String _serviceForIndex(int index) {
    if (_daycareOn && index == 1) {
      return PolicyApplicableService.daycare;
    }
    return PolicyApplicableService.accommodation;
  }

  String get _activeService => _serviceForIndex(_tabs?.index ?? 0);

  @override
  void initState() {
    super.initState();
    _shopSub = ShopService.instance.streamShop(widget.shopId).listen((
      Map<String, dynamic>? shop,
    ) {
      final bool on = DaycareSettingsService.instance.isEnabledForShop(
        shop: shop,
      );
      if (!mounted || (_tabs != null && on == _daycareOn)) {
        return;
      }
      _replaceTabs(on);
    });
    _loadPolicy();
  }

  void _onTabs() {
    final TabController? tabs = _tabs;
    if (tabs == null) {
      return;
    }
    if (tabs.indexIsChanging) {
      _storeCurrentDraft();
      return;
    }
    if (_isEditorIndex(tabs.index)) {
      _restoreDraft(_serviceForIndex(tabs.index));
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _replaceTabs(bool daycareOn) {
    final TabController? old = _tabs;
    final int previous = old?.index ?? 0;
    if (old != null) {
      _storeDraftAt(old.index);
      old.removeListener(_onTabs);
    }
    final int length = daycareOn ? 4 : 3;
    int nextIndex = 0;
    if (old != null && old.length == 4 && !daycareOn) {
      nextIndex = previous <= 1 ? 0 : previous - 1;
    } else if (old != null && old.length == 3 && daycareOn) {
      nextIndex = previous == 0 ? 0 : previous + 1;
    } else if (old != null) {
      nextIndex = previous.clamp(0, length - 1);
    }
    _daycareOn = daycareOn;
    _tabs = TabController(length: length, vsync: this, initialIndex: nextIndex);
    _tabs!.addListener(_onTabs);
    if (!_loading && _isEditorIndex(nextIndex)) {
      _restoreDraft(_serviceForIndex(nextIndex));
    }
    if (mounted) {
      setState(() {});
    }
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
      });
    }
  }

  @override
  void dispose() {
    for (final node in _textFocus.values) {
      node.dispose();
    }
    _shopSub?.cancel();
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    _refundTitle.dispose();
    _refundDescription.dispose();
    _refundBody.dispose();
    _tabs?.removeListener(_onTabs);
    _tabs?.dispose();
    super.dispose();
  }

  void _markDirty() {
    setState(() => _dirty = true);
  }

  void _storeCurrentDraft() {
    final TabController? tabs = _tabs;
    if (tabs == null) {
      return;
    }
    _storeDraftAt(tabs.previousIndex);
  }

  void _storeDraftAt(int from) {
    if (!_isEditorIndex(from)) {
      return;
    }
    final String service = _serviceForIndex(from);
    _drafts[service] = _controllers.map(
      (String key, TextEditingController ctrl) => MapEntry(key, ctrl.text),
    );
    _enabledDrafts[service] = Map<String, bool>.from(_enabled);
  }

  void _restoreDraft(String service) {
    final Map<String, String> draft = _drafts[service] ?? <String, String>{};
    _controllers.forEach((String key, TextEditingController ctrl) {
      ctrl.text = draft[key] ?? '';
    });
    _enabled = Map<String, bool>.from(_enabledDrafts[service] ?? _enabled);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadPolicy() async {
    try {
      final Map<String, dynamic>? data = await ShopService.instance
          .getCheckinPolicy(widget.shopId);
      if (data != null) {
        for (final String service in <String>[
          PolicyApplicableService.accommodation,
          PolicyApplicableService.daycare,
        ]) {
          final Map<String, dynamic> filtered = ShopPolicyService.instance
              .filterPolicyForService(policy: data, serviceType: service);
          final Map<String, dynamic> sections = Map<String, dynamic>.from(
            filtered['sections'] ?? <String, dynamic>{},
          );
          _customDrafts[service] = {
            for (final page in ['page1', 'page2'])
              page: PolicyApplicableService.normalizeCustomPolicies(
                filtered[page == 'page1'
                    ? 'customPoliciesPage1'
                    : 'customPoliciesPage2'],
              ).map((e) => e['text'].toString()).toList(),
          };
          _drafts[service] = <String, String>{
            for (final String key in _controllers.keys)
              key: (sections[key] ?? '').toString(),
          };
          final Map<String, dynamic> enabled = Map<String, dynamic>.from(
            filtered['enabled'] ?? <String, dynamic>{},
          );
          _enabledDrafts[service] = <String, bool>{
            for (final String key in _controllers.keys)
              key: enabled[key] != false,
          };
        }
        _policy = data;
        final dynamic updatedAt = data['updatedAt'];
        _policyUpdatedAt = updatedAt is Timestamp
            ? updatedAt.toDate()
            : updatedAt is DateTime
            ? updatedAt
            : null;
        _stayVersion = ShopPolicyService.servicePolicyVersion(
          policy: data,
          serviceType: PolicyApplicableService.accommodation,
        );
        _daycareVersion = ShopPolicyService.servicePolicyVersion(
          policy: data,
          serviceType: PolicyApplicableService.daycare,
        );
        _restoreDraft(PolicyApplicableService.accommodation);
      }
      final Map<String, dynamic>? refund = await ShopPolicyService.instance
          .getRefundPolicy(widget.shopId);
      if (refund != null) {
        _publishedRefundBody =
            refund['enabled'] != false &&
                refund['serviceType'] != PolicyApplicableService.daycare &&
                (refund['status'] == null || refund['status'] == 'published') &&
                (refund['applicableServices'] is! List ||
                    (refund['applicableServices'] as List).contains(
                      PolicyApplicableService.accommodation,
                    )) &&
                ShopPolicyService.parsePolicyVersion(
                      refund['refundPolicyVersion'] ?? refund['version'],
                    ) >
                    0 &&
                (refund['body'] ?? '').toString().trim().isNotEmpty
            ? refund['body'].toString().trim()
            : null;
        _refundTitle.text = (refund['title'] ?? '退款條款').toString();
        _refundDescription.text = (refund['description'] ?? '').toString();
        _refundBody.text = (refund['body'] ?? '').toString();
        _refundEnabled = refund['enabled'] != false;
        _refundVersion =
            (refund['refundPolicyVersion'] as num?)?.toInt() ??
            (refund['version'] as num?)?.toInt() ??
            0;
      }
      if (mounted) {
        setState(() {
          _savedRefundFingerprint = _refundFingerprint;
          _loading = false;
          _dirty = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _tourError = e);
    }
  }

  Future<void> _save() async {
    if (!widget.canEdit ||
        _loading ||
        _saving ||
        _confirmingPublish ||
        _showingMissing ||
        _completingParameters ||
        _templateBusy) {
      return;
    }
    final TabController? tabs = _tabs;
    if (tabs == null || tabs.index == _logsIndex) {
      return;
    }
    final intendedService = _activeService;
    final issues = _urlIssues;
    if (issues.isNotEmpty) {
      await _showPublishIssues(issues);
      return;
    }
    if (tabs.index == _refundIndex) {
      await _saveRefund();
      return;
    }
    final stay = _activeService == PolicyApplicableService.accommodation;
    if (!mounted) return;
    if (stay && _pendingParameters.isNotEmpty) {
      await _showMissing(publishing: true);
      return;
    }
    final confirmation = stay
        ? _confirmStayPublish()
        : showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('發布新版條款？'),
                content: const Text('發布後，尚未確認此版本的顧客，需在下次使用本店預約相關功能前確認新版條款。'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('確認發布'),
                  ),
                ],
              );
            },
          );
    final confirm = await confirmation;
    if (confirm != true || !mounted) return;
    if (_activeService != intendedService ||
        (intendedService == PolicyApplicableService.daycare && !_daycareOn)) {
      return;
    }
    setState(() => _saving = true);
    try {
      _storeDraftAt(tabs.index);
      final publishingService = intendedService;
      final Map<String, dynamic> sections = <String, dynamic>{
        for (final MapEntry<String, TextEditingController> e
            in _controllers.entries)
          e.key: e.value.text.trim(),
      };
      await ShopPolicyService.instance.updateServicePolicy(
        shopId: widget.shopId,
        serviceType: publishingService,
        sections: sections,
        enabled: _enabled,
        customPoliciesPage1: _customChanged.contains(publishingService)
            ? (_customDrafts[publishingService]?['page1'] ?? const <String>[])
            : const <String>[],
        customPoliciesPage2: _customChanged.contains(publishingService)
            ? (_customDrafts[publishingService]?['page2'] ?? const <String>[])
            : const <String>[],
        replaceCustomPolicies: _customChanged.contains(publishingService),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            publishingService == PolicyApplicableService.daycare
                ? '安親條款已更新'
                : '住宿條款已更新',
          ),
        ),
      );
      _customChanged.remove(publishingService);
      await _refreshPublishedVersion();
    } on PolicyUrlValidationException catch (error) {
      if (mounted) await _showPublishIssues(error.issues);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('發布失敗：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveRefund() async {
    setState(() => _saving = true);
    try {
      await ShopPolicyService.instance.updateRefundPolicy(
        shopId: widget.shopId,
        title: _refundTitle.text,
        description: _refundDescription.text,
        body: _refundBody.text,
        enabled: _refundEnabled,
      );
      final data = await ShopPolicyService.instance.getRefundPolicy(
        widget.shopId,
      );
      if (!mounted) return;
      setState(() {
        _savedRefundFingerprint = _refundFingerprint;
        _refundVersion = ShopPolicyService.parsePolicyVersion(
          data?['refundPolicyVersion'] ?? data?['version'],
        );
        _publishedRefundBody =
            _refundEnabled && _refundBody.text.trim().isNotEmpty
            ? _refundBody.text.trim()
            : null;
      });
      await _refreshPublishedVersion();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已更新退款條款')));
      }
    } on PolicyUrlValidationException catch (error) {
      if (mounted) {
        await _showPublishIssues(error.issues, includeMissing: false);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('發布失敗：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmStayPublish() async {
    setState(() => _confirmingPublish = true);
    try {
      bool checked = false;
      return await showDialog<bool>(
            context: context,
            builder: (dialogContext) => StatefulBuilder(
              builder: (context, update) => AlertDialog(
                title: const Text('發布前，請確認條款內容'),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '這些條款發布後，將顯示於顧客端，供顧客在預約時閱讀與確認。\n\n快速模板是編輯參考，請逐項確認營業時間、入住條件、照護服務、設備、收費及退款規則，均符合本店實際提供的內容。未提供的服務請刪除或停用，不適用的內容請先修改。\n\n本模板不代表平台已代店家完成法律審核，請勿將尚未確認的範例直接公開。',
                        ),
                        TextButton(
                          onPressed: _previewDraft,
                          child: const Text('查看顧客預覽'),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: checked,
                          onChanged: (value) =>
                              update(() => checked = value == true),
                          title: const Text(
                            '我已逐項檢查並完成必要修改，確認內容符合本店實際情況，可向顧客公開。',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('返回檢查'),
                  ),
                  FilledButton(
                    onPressed: checked
                        ? () => Navigator.pop(dialogContext, true)
                        : null,
                    child: const Text('確認發布'),
                  ),
                ],
              ),
            ),
          ) ==
          true;
    } finally {
      if (mounted) setState(() => _confirmingPublish = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canEdit) {
      return Scaffold(
        appBar: AppBar(title: const Text('條款設定')),
        body: ShopPolicyLogsPage(shopId: widget.shopId, embedded: true),
      );
    }
    return ShopTourPage(
      id: 'ShopPolicyPage',
      shopId: widget.shopId,
      ready: !_loading && _tabs != null,
      error: _tourError,
      onPoint: (point) async {
        if (!_loading && _tabs != null) {
          final panel = shopTourPanel('ShopPolicyPage', point);
          _tabs!.index = panel == 1
              ? _refundIndex
              : panel == 2
              ? _logsIndex
              : 0;
        }
      },
      child: PopScope(
        canPop: !_dirty,
        onPopInvokedWithResult: (bool didPop, Object? result) async {
          if (didPop || !_dirty) {
            return;
          }
          final bool? leave = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('尚未儲存'),
              content: const Text('離開此頁將捨棄未儲存的條款變更。'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('繼續編輯'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('離開'),
                ),
              ],
            ),
          );
          if (leave == true && context.mounted) {
            Navigator.pop(context);
          }
        },
        child: _tabs == null
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : Scaffold(
                appBar: AppBar(
                  title: const Text('條款設定'),
                  bottom: _policyTabBar(),
                ),
                body: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            children: <Widget>[
                              Expanded(
                                child: TabBarView(
                                  controller: _tabs!,
                                  children: <Widget>[
                                    _serviceEditor(isDaycare: false),
                                    if (_daycareOn)
                                      _serviceEditor(isDaycare: true),
                                    ShopTourAnchor(
                                      ids: const ['ShopPolicyPage.1'],
                                      child: _refundEditor(),
                                    ),
                                    ShopPolicyLogsPage(
                                      shopId: widget.shopId,
                                      embedded: true,
                                    ),
                                  ],
                                ),
                              ),
                              if (_tabs!.index != _logsIndex)
                                SafeArea(
                                  top: false,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      16,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: FilledButton(
                                        onPressed: _saving ? null : _save,
                                        child: _saving
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Text(
                                                _tabs!.index == _refundIndex
                                                    ? '儲存退款條款'
                                                    : '發布此分頁條款',
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
      ),
    );
  }

  PreferredSizeWidget _policyTabBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kTextTabBarHeight),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final bool scrollable = width.isFinite && width < 720;
          return TabBar(
            controller: _tabs!,
            isScrollable: scrollable,
            tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
            tabs: <Widget>[
              const Tab(text: '預約／入住條款'),
              if (_daycareOn) const Tab(text: '安親條款'),
              const Tab(text: '退款條款'),
              const Tab(text: '條款同意紀錄'),
            ],
          );
        },
      ),
    );
  }

  Widget _serviceEditor({required bool isDaycare}) {
    final int version = isDaycare ? _daycareVersion : _stayVersion;
    final List<List<String>> sections = <List<String>>[
      <String>['checkinTime', '營業時間與環境參觀時間'],
      <String>['checkOutFlow', isDaycare ? '送達與接回安排' : '入住與退房安排'],
      <String>['basicCondition', '貓咪基本條件'],
      <String>['ownerNotice', '飼主應告知資訊'],
      <String>['checkinNotice', isDaycare ? '安親須知' : '入住須知'],
      <String>['facility', '本店提供的基本設施'],
      <String>['specialCase', '特殊情況處理'],
      <String>['activity', '探索活動安排'],
      <String>['extraNotice', '額外注意事項'],
      <String>['cancelPolicy', '取消政策'],
    ];
    final String publishedAt = _policyUpdatedAt == null
        ? '尚未記錄'
        : DateFormat('yyyy/MM/dd HH:mm').format(_policyUpdatedAt!);
    final String serviceTitle = isDaycare ? '安親須知' : '入住須知';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_activeService ==
              (isDaycare
                  ? PolicyApplicableService.daycare
                  : PolicyApplicableService.accommodation))
            for (final issue in _urlIssues.where(
              (e) => e.key.startsWith('customPolicies'),
            ))
              _urlNotice([issue]),
          if (!isDaycare) _pendingCard(),
          if (!isDaycare)
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _canUseTemplate ? _applyTemplate : null,
                  child: const Text('套用快速模板'),
                ),
                TextButton(
                  onPressed: !_loading && !_saving ? _previewDraft : null,
                  child: const Text('查看顧客預覽'),
                ),
              ],
            ),
          ShopTourAnchor(
            ids: isDaycare ? const [] : const ['ShopPolicyPage.0'],
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '目前已發布版本',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(serviceTitle),
                  const SizedBox(height: 4),
                  Text(
                    version > 0 ? '版本 v$version　發布日期 $publishedAt　生效中' : '尚未發布',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDaycare
                        ? '以下為草稿。發布新版本不會要求住宿客人重新勾選。已發布內容不可直接修改。'
                        : '以下為草稿。發布後才會成為最新版本，已發布內容不可直接修改。',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (version > 0 && _policy != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => PolicyVersionDetailPage(
                                data: _policy!,
                                serviceType: isDaycare
                                    ? PolicyApplicableService.daycare
                                    : PolicyApplicableService.accommodation,
                              ),
                            ),
                          );
                        },
                        child: const Text('查看目前版本'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              ShopTourAnchor(
                ids: isDaycare ? const [] : const ['ShopPolicyPage.2'],
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PolicyVersionHistoryPage(shopId: widget.shopId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('版本紀錄'),
                ),
              ),
              if (_daycareOn)
                TextButton(
                  onPressed: () {
                    final String other = isDaycare
                        ? PolicyApplicableService.accommodation
                        : PolicyApplicableService.daycare;
                    _storeDraftAt(_tabs!.index);
                    _drafts[other] = _controllers.map(
                      (String key, TextEditingController ctrl) =>
                          MapEntry(key, ctrl.text),
                    );
                    _enabledDrafts[other] = Map<String, bool>.from(_enabled);
                    _markDirty();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isDaycare ? '已複製到住宿條款草稿' : '已複製到安親條款草稿'),
                      ),
                    );
                  },
                  child: Text(isDaycare ? '複製到住宿條款' : '複製到安親條款'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...sections.map((List<String> item) {
            final String key = item.first;
            final String title = item.last;
            final bool open = _expanded.contains(key);
            final String preview = (_controllers[key]?.text ?? '').trim();
            final urlIssues = PolicyUrlValidation.inspect([
              PolicyTextField(
                key,
                title,
                _controllers[key]!.text,
                enabled: _enabled[key] != false,
              ),
            ]);
            final missing = ShopPolicyTemplates.missing(
              {key: preview},
              {key: true},
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Switch(
                          value: _enabled[key] ?? true,
                          onChanged: _saving
                              ? null
                              : (bool value) {
                                  setState(() {
                                    _enabled[key] = value;
                                    _dirty = true;
                                  });
                                },
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (open) {
                                _expanded.remove(key);
                              } else {
                                _expanded.add(key);
                              }
                            });
                          },
                          child: Text(open ? '收合' : '編輯'),
                        ),
                      ],
                    ),
                    if (!open)
                      Text(
                        preview.isEmpty ? '尚未填寫' : preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      )
                    else
                      TextField(
                        key: _textKeys.putIfAbsent(
                          '${isDaycare ? PolicyApplicableService.daycare : PolicyApplicableService.accommodation}:$key',
                          GlobalKey.new,
                        ),
                        focusNode: _textFocus.putIfAbsent(
                          '${isDaycare ? PolicyApplicableService.daycare : PolicyApplicableService.accommodation}:$key',
                          FocusNode.new,
                        ),
                        controller: _controllers[key],
                        readOnly: _saving,
                        minLines: 4,
                        maxLines: 10,
                        onChanged: (_) {
                          if (isDaycare) {
                            _markDirty();
                          } else {
                            setState(() {
                              _storeDraftAt(0);
                              _dirty = true;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                    if (urlIssues.isNotEmpty) _urlNotice(urlIssues),
                    if (!isDaycare &&
                        ShopPolicyTemplates.hasParameters(preview))
                      Text(
                        _enabled[key] != false
                            ? '尚需補充：${missing.map((p) => p.name).join('、')}'
                            : '此欄位已停用，待填內容不影響發布。',
                      ),
                    if (!isDaycare &&
                        missing.isNotEmpty &&
                        _enabled[key] != false)
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: _canUseTemplate
                                ? () => _completeParameters(key)
                                : null,
                            child: const Text('補齊此項'),
                          ),
                          TextButton(
                            onPressed: () => _locateParameter(key),
                            child: const Text('前往文字編輯'),
                          ),
                        ],
                      ),
                    if (!isDaycare &&
                        key == 'cancelPolicy' &&
                        _publishedRefundBody == null)
                      const Text('目前尚未設定退款條款，可先設定後帶入，或在此補齊取消政策。'),
                    if (open && !isDaycare)
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: _canUseTemplate
                                ? () => _applyExample(key)
                                : null,
                            child: const Text('帶入此項範例'),
                          ),
                          if (key == 'cancelPolicy' &&
                              _publishedRefundBody != null)
                            TextButton(
                              onPressed: _canUseTemplate ? _importRefund : null,
                              child: const Text('確認並帶入已發布退款條款'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _refundEditor() {
    Widget notice(String key) {
      final issues = _urlIssues.where((e) => e.key == key).toList();
      return issues.isEmpty ? const SizedBox.shrink() : _urlNotice(issues);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('退款條款版本：v$_refundVersion（申請退款時閱讀，不參與預約勾選）'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('啟用退款條款'),
            value: _refundEnabled,
            onChanged: _saving
                ? null
                : (bool value) {
                    setState(() {
                      _refundEnabled = value;
                      _dirty = true;
                    });
                  },
          ),
          TextField(
            key: _textKeys.putIfAbsent('refundTitle', GlobalKey.new),
            readOnly: _saving,
            focusNode: _textFocus.putIfAbsent('refundTitle', FocusNode.new),
            controller: _refundTitle,
            decoration: const InputDecoration(
              labelText: '標題',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _markDirty(),
          ),
          notice('refundTitle'),
          const SizedBox(height: 12),
          TextField(
            key: _textKeys.putIfAbsent('refundDescription', GlobalKey.new),
            readOnly: _saving,
            focusNode: _textFocus.putIfAbsent(
              'refundDescription',
              FocusNode.new,
            ),
            controller: _refundDescription,
            decoration: const InputDecoration(
              labelText: '簡短說明',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _markDirty(),
          ),
          notice('refundDescription'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _saving
                ? null
                : () {
                    setState(() {
                      _refundBody.text = ShopPolicyService.refundTemplate();
                      _dirty = true;
                    });
                  },
            child: const Text('一鍵套用退款模板'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: _textKeys.putIfAbsent('refundBody', GlobalKey.new),
            readOnly: _saving,
            focusNode: _textFocus.putIfAbsent('refundBody', FocusNode.new),
            controller: _refundBody,
            minLines: 12,
            maxLines: 20,
            onChanged: (_) => _markDirty(),
            decoration: const InputDecoration(
              labelText: '退款規則內容',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          notice('refundBody'),
        ],
      ),
    );
  }
}
