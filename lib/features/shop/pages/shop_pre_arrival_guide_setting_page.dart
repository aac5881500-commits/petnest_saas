import 'package:petnest_saas/features/shop/widgets/pre_arrival_appearance_editor.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_workspace.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_style_picker.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_checklist_templates.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_guide_help.dart';
import 'package:petnest_saas/features/shop/widgets/shop_feature_tour.dart';
// 檔案名稱：lib/features/shop/pages/shop_pre_arrival_guide_setting_page.dart
// 功能說明：店家後台：入住前準備圖文設定（住宿／安親），不是條款。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/core/services/pre_arrival_guide_service.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/booking/pages/pre_arrival_guide_page.dart';
import 'package:petnest_saas/core/services/daycare_enabled.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';

class ShopPreArrivalGuideSettingPage extends StatefulWidget {
  const ShopPreArrivalGuideSettingPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopPreArrivalGuideSettingPage> createState() =>
      _ShopPreArrivalGuideSettingPageState();
}

enum _LeaveChoice { enable, draft, discard }

class _ShopPreArrivalGuideSettingPageState
    extends State<ShopPreArrivalGuideSettingPage>
    with
        SingleTickerProviderStateMixin,
        ShopDashboardLeaveAware<ShopPreArrivalGuideSettingPage> {
  @override
  bool get dashboardHasUnsavedChanges => _dirty;
  @override
  bool get dashboardIsBusy => _saving;
  @override
  Future<bool> dashboardConfirmLeave() async =>
      !_saving && await _confirmLeave();
  late final TabController _tabs;
  PreArrivalGuideModel? _accommodation;
  PreArrivalGuideModel? _daycare;
  PreArrivalGuideModel? _savedAccommodation;
  PreArrivalGuideModel? _savedDaycare;
  Object? _tourError;
  bool _loading = true;
  bool _saving = false;
  bool _confirmingLeave = false;
  bool _daycareOn = false;
  static const _blocksPerPage = 5;
  final _showSettings = <bool, bool>{};
  final _contentPage = <bool, int>{};
  final Set<String> _sessionUploads = <String>{};
  final Set<String> _pendingDeletes = <String>{};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _cleanupOrphans();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cleanupOrphans() async {
    final Set<String> savedPaths = <String>{
      ..._pathsOf(_savedAccommodation),
      ..._pathsOf(_savedDaycare),
    };
    for (final String path in _sessionUploads) {
      if (!savedPaths.contains(path)) {
        await PreArrivalGuideService.instance.deleteImage(storagePath: path);
      }
    }
  }

  Set<String> _pathsOf(PreArrivalGuideModel? guide) {
    if (guide == null) {
      return <String>{};
    }
    return guide.blocks
        .map((PreArrivalGuideBlock b) => b.storagePath)
        .where((String p) => p.isNotEmpty)
        .toSet();
  }

  bool get _dirty {
    return _pendingDeletes.isNotEmpty ||
        _encode(_accommodation) != _encode(_savedAccommodation) ||
        _encode(_daycare) != _encode(_savedDaycare);
  }

  String _encode(PreArrivalGuideModel? guide) {
    if (guide == null) {
      return '';
    }
    return '${guide.appearance.toMap()}|${guide.style}|${guide.enabled}|${guide.title}|${guide.inheritAccommodation}|${guide.blocks.map((PreArrivalGuideBlock b) => '${b.id}:${b.type}:${b.text}:${b.imageUrl}:${b.caption}').join(';')}';
  }

  Future<void> _load() async {
    try {
      final PreArrivalGuideModel acc = await PreArrivalGuideService.instance
          .getGuide(
            shopId: widget.shopId,
            serviceType: PreArrivalGuideServiceType.accommodation,
          );
      final PreArrivalGuideModel day = await PreArrivalGuideService.instance
          .getGuide(
            shopId: widget.shopId,
            serviceType: PreArrivalGuideServiceType.daycare,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _accommodation = acc;
        _daycare = day;
        _savedAccommodation = acc;
        _savedDaycare = day;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _tourError = e);
    }
  }

  List<PreArrivalGuideModel> get _hiddenOnLeave {
    final current = _daycareOn && _tabs.index == 1 ? _daycare : _accommodation;
    final effective = current?.inheritAccommodation == true
        ? _accommodation
        : current;
    return [
      for (final (guide, saved) in [
        (_accommodation, _savedAccommodation),
        (_daycare, _savedDaycare),
      ])
        if (guide != null &&
            !guide.inheritAccommodation &&
            !guide.enabled &&
            guide.visibleBlocks.isNotEmpty &&
            (identical(guide, effective) || _encode(guide) != _encode(saved)))
          guide,
    ];
  }

  Future<bool> _confirmLeave() async {
    if (_saving || _confirmingLeave) return false;
    _confirmingLeave = true;
    try {
      final hidden = _hiddenOnLeave;
      if (hidden.isEmpty && !_dirty) return true;
      final names = hidden
          .map(
            (guide) => guide.serviceType == PreArrivalGuideServiceType.daycare
                ? '安親'
                : '住宿',
          )
          .join('、');
      final choice = await showDialog<_LeaveChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(hidden.isEmpty ? '尚未儲存' : '準備清單尚未開放'),
          content: Text(
            hidden.isEmpty
                ? '儲存修改後離開，或放棄這次修改。'
                : '$names準備清單已有內容，但尚未開放，客戶在訂單中看不到。要開啟並儲存嗎？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('繼續編輯'),
            ),
            if (_dirty)
              TextButton(
                onPressed: () => Navigator.pop(context, _LeaveChoice.discard),
                child: const Text('放棄修改'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context, _LeaveChoice.draft),
              child: Text(hidden.isNotEmpty ? '保留草稿並離開' : '儲存並離開'),
            ),
            if (hidden.isNotEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(context, _LeaveChoice.enable),
                child: const Text('開啟並儲存'),
              ),
          ],
        ),
      );
      if (!mounted || choice == null) return false;
      if (choice == _LeaveChoice.discard) return true;
      if (choice == _LeaveChoice.enable) {
        setState(() {
          for (final guide in hidden) {
            if (guide.serviceType == PreArrivalGuideServiceType.daycare) {
              _daycare = guide.copyWith(enabled: true);
            } else {
              _accommodation = guide.copyWith(enabled: true);
            }
          }
        });
      }
      return !_dirty || (await _save() && !_dirty);
    } finally {
      _confirmingLeave = false;
    }
  }

  Future<bool> _save() async {
    if (_saving || _accommodation == null || _daycare == null) {
      return false;
    }
    final accommodation = _accommodation!;
    final daycare = _daycare!;
    final pendingDeletes = _pendingDeletes.toList();
    setState(() {
      _saving = true;
    });
    try {
      if (_encode(accommodation) != _encode(_savedAccommodation)) {
        await PreArrivalGuideService.instance.saveGuide(accommodation);
        _savedAccommodation = accommodation;
        _sessionUploads.removeAll(_pathsOf(accommodation));
      }
      if (_encode(daycare) != _encode(_savedDaycare)) {
        await PreArrivalGuideService.instance.saveGuide(daycare);
        _savedDaycare = daycare;
        _sessionUploads.removeAll(_pathsOf(daycare));
      }
      for (final path in pendingDeletes) {
        await PreArrivalGuideService.instance.deleteImage(storagePath: path);
        _pendingDeletes.remove(path);
      }
      if (!mounted) {
        return false;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存入住前準備')));
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShopTourPage(
      id: 'ShopPreArrivalGuideSettingPage',
      shopId: widget.shopId,
      ready: !_loading,
      error: _tourError,
      onPoint: (point) async {
        _tabs.index = 0;
        setState(() => _showSettings[false] = point == 0);
      },
      child: ShopFrontendThemeScope(
        shopId: widget.shopId,
        builder: (BuildContext context) {
          return StreamBuilder<Map<String, dynamic>?>(
            stream: ShopService.instance.streamShop(widget.shopId),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<Map<String, dynamic>?> shopSnap,
                ) {
                  final bool daycareOn = DaycareEnabled.isOn(
                    shop: shopSnap.data,
                  );
                  _daycareOn = daycareOn;
                  return dashboardGuard(
                    Scaffold(
                      backgroundColor: BookingDetailUi.of(context).background,
                      appBar: AppBar(
                        title: Text(daycareOn ? '入住／安親前準備' : '入住前準備'),
                        backgroundColor: BookingDetailUi.of(context).background,
                        bottom: daycareOn
                            ? TabBar(
                                controller: _tabs,
                                tabs: const <Widget>[
                                  Tab(text: '住宿'),
                                  Tab(text: '安親'),
                                ],
                              )
                            : null,
                      ),
                      bottomNavigationBar: _loading
                          ? null
                          : SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  12,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: ShopTourAnchor(
                                        ids: const [
                                          'ShopPreArrivalGuideSettingPage.2',
                                        ],
                                        child: OutlinedButton.icon(
                                          onPressed: _saving
                                              ? null
                                              : () => _previewGuide(
                                                  isDaycare:
                                                      daycareOn &&
                                                      _tabs.index == 1,
                                                ),
                                          icon: const Icon(
                                            Icons.preview_outlined,
                                          ),
                                          label: const Text('預覽客戶畫面'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: _saving || !_dirty
                                            ? null
                                            : _save,
                                        icon: const Icon(Icons.save_outlined),
                                        label: Text(_saving ? '儲存中…' : '儲存內容'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      body: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : daycareOn
                          ? TabBarView(
                              controller: _tabs,
                              children: <Widget>[
                                _editor(isDaycare: false),
                                _editor(isDaycare: true),
                              ],
                            )
                          : _editor(isDaycare: false),
                    ),
                  );
                },
          );
        },
      ),
    );
  }

  void _previewGuide({required bool isDaycare}) {
    final guide = isDaycare ? _daycare! : _accommodation!;
    final preview = isDaycare && guide.inheritAccommodation
        ? _accommodation!
        : guide;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PreArrivalGuidePage(guide: preview),
      ),
    );
  }

  Widget _editor({required bool isDaycare}) {
    final PreArrivalGuideModel guide = isDaycare ? _daycare! : _accommodation!;
    final bool inherit = isDaycare && guide.inheritAccommodation;
    final effective = inherit ? _accommodation! : guide;
    final savedEffective =
        !isDaycare || _savedDaycare?.inheritAccommodation == true
        ? _savedAccommodation
        : _savedDaycare;
    final settings = inherit || (_showSettings[isDaycare] ?? false);
    final pageCount = guide.blocks.isEmpty
        ? 1
        : (guide.blocks.length - 1) ~/ _blocksPerPage + 1;
    final page = (_contentPage[isDaycare] ?? 0).clamp(0, pageCount - 1);
    final start = page * _blocksPerPage;
    final end = (start + _blocksPerPage).clamp(0, guide.blocks.length);
    final editor = AbsorbPointer(
      absorbing: _saving,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    ShopTourAnchor(
                      ids: isDaycare
                          ? const []
                          : const ['ShopPreArrivalGuideSettingPage.0'],
                      child: Card(
                        child: SwitchListTile(
                          title: Text(inherit ? '沿用住宿的顯示設定' : '讓客戶在訂單中看到這份清單'),
                          subtitle: Text(
                            !effective.enabled
                                ? (savedEffective?.hasCustomerContent == true
                                      ? '目前設定為關閉，儲存後客戶就看不到。'
                                      : '尚未開放，客戶在訂單中看不到。')
                                : !effective.hasCustomerContent
                                ? '加入準備內容並儲存後，客戶才看得到。'
                                : savedEffective?.hasCustomerContent == true
                                ? '客戶可在訂單中查看已儲存的清單。'
                                : '已開啟，儲存後客戶就能查看。',
                          ),
                          value: effective.enabled,
                          onChanged: inherit
                              ? null
                              : (value) => setState(() {
                                  if (isDaycare) {
                                    _daycare = guide.copyWith(enabled: value);
                                  } else {
                                    _accommodation = guide.copyWith(
                                      enabled: value,
                                    );
                                  }
                                }),
                        ),
                      ),
                    ),

                    if (!inherit)
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('清單排序')),
                          ButtonSegment(value: true, label: Text('外觀與設定')),
                        ],
                        selected: {settings},
                        onSelectionChanged: (selection) => setState(
                          () => _showSettings[isDaycare] = selection.single,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: ValueKey(
                    'pre-arrival-editor-$isDaycare-$settings-$page',
                  ),
                  primary: false,
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    if (settings) ...[
                      const Text(
                        '準備一份清楚的行前清單',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('整理要帶的物品、店內提供的用品與到店提醒，讓家長輕鬆準備。'),
                      const SizedBox(height: 12),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('操作說明與範例'),
                        children: [
                          PreArrivalGuideHelpCard(
                            isDaycare: isDaycare,
                            inherit: inherit,
                            onDemo: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => PreArrivalGuidePage(
                                  guide: preArrivalExample(
                                    shopId: widget.shopId,
                                    isDaycare: isDaycare,
                                  ),
                                ),
                              ),
                            ),
                            onAddExample: () => _addExample(isDaycare),
                          ),
                        ],
                      ),
                      if (isDaycare)
                        SwitchListTile(
                          title: const Text('沿用住宿內容'),
                          subtitle: const Text('開啟後，客戶安親訂單會顯示住宿的入住前準備內容'),
                          value: guide.inheritAccommodation,
                          onChanged: (bool value) {
                            setState(() {
                              _daycare = guide.copyWith(
                                inheritAccommodation: value,
                              );
                            });
                          },
                        ),
                      if (!inherit) ...[
                        const SizedBox(height: 24),
                        PreArrivalStylePicker(
                          value: guide.style,
                          onChanged: (style) {
                            setState(() {
                              if (isDaycare) {
                                _daycare = guide.copyWith(style: style);
                              } else {
                                _accommodation = guide.copyWith(style: style);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        PreArrivalAppearanceEditor(
                          guide: guide,
                          onChanged: (updated) {
                            setState(() {
                              if (isDaycare) {
                                _daycare = updated;
                              } else {
                                _accommodation = updated;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        PreArrivalCatalogPicker(
                          guide: guide,
                          onChanged: (updated) {
                            setState(() {
                              if (isDaycare) {
                                _daycare = updated;
                              } else {
                                _accommodation = updated;
                              }
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        '清單內容',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('填寫客戶需要帶的物品，以及你想提醒的事。'),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: ValueKey<String>('guide-title-$isDaycare'),
                        initialValue: guide.title,
                        decoration: InputDecoration(
                          labelText: '客戶看到的頁面標題',
                          helperText: '例如：入住前請準備好這些物品',
                          hintText: isDaycare ? '安親前準備' : '入住前準備',
                        ),
                        enabled: !inherit,
                        onChanged: (String value) {
                          setState(() {
                            if (isDaycare) {
                              _daycare = guide.copyWith(title: value);
                            } else {
                              _accommodation = guide.copyWith(title: value);
                            }
                          });
                        },
                      ),
                    ],
                    if (!settings) ...<Widget>[
                      const Text(
                        '準備項目與提醒',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('建議依必須攜帶、視需要攜帶、店家提供及到店提醒分段整理。'),
                      const SizedBox(height: 12),
                      ShopTourAnchor(
                        ids: isDaycare
                            ? const []
                            : const ['ShopPreArrivalGuideSettingPage.1'],
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            if (guide.blocks.isEmpty)
                              FilledButton.icon(
                                onPressed: () => _addExample(isDaycare),
                                icon: const Icon(Icons.auto_awesome_outlined),
                                label: const Text('使用常用準備清單'),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => _addBlock(
                                isDaycare,
                                PreArrivalGuideBlockType.checklist,
                              ),
                              icon: const Icon(Icons.check_box_outlined),
                              label: const Text('加一項物品'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _addChecklist(isDaycare, template: true),
                              icon: const Icon(Icons.auto_awesome_outlined),
                              label: const Text('其他情境模板'),
                            ),
                            PopupMenuButton<String>(
                              tooltip: '其他新增方式',
                              onSelected: (value) {
                                if (value == 'section') {
                                  _addSection(isDaycare);
                                } else if (value == 'batch') {
                                  _addChecklist(isDaycare);
                                } else if (value == 'image') {
                                  _addImage(isDaycare);
                                } else {
                                  _addBlock(isDaycare, value);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'section',
                                  child: Text('新增分段'),
                                ),
                                PopupMenuItem(
                                  value: 'batch',
                                  child: Text('一次加多項物品（每行一項）'),
                                ),
                                PopupMenuItem(
                                  value: PreArrivalGuideBlockType.heading,
                                  child: Text('加段落標題，例如「必帶物品」'),
                                ),
                                PopupMenuItem(
                                  value: PreArrivalGuideBlockType.text,
                                  child: Text('加補充說明，例如分裝方式'),
                                ),
                                PopupMenuItem(
                                  value: 'image',
                                  child: Text('加說明圖片'),
                                ),
                              ],
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 18),
                                    SizedBox(width: 4),
                                    Text('更多內容'),
                                    Icon(Icons.arrow_drop_down, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (guide.blocks.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              children: <Widget>[
                                Icon(Icons.checklist_outlined, size: 36),
                                SizedBox(height: 8),
                                Text('還沒有準備清單'),
                                SizedBox(height: 4),
                                Text(
                                  '使用常用清單快速建立，再依店內需求修改；也可以自行新增文字與圖片。',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (pageCount > 1)
                        _pageControls(
                          isDaycare,
                          page,
                          pageCount,
                          start,
                          end,
                          guide.blocks.length,
                        ),
                      for (int i = start; i < end; i++)
                        _blockEditor(
                          isDaycare: isDaycare,
                          index: i,
                          block: guide.blocks[i],
                        ),
                      if (pageCount > 1)
                        _pageControls(
                          isDaycare,
                          page,
                          pageCount,
                          start,
                          end,
                          guide.blocks.length,
                        ),
                    ],
                    const SizedBox(height: 24),
                    const Divider(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return PreArrivalWorkspace(
      editor: editor,
      preview: PreArrivalGuidePage(
        key: ValueKey('live-preview-$isDaycare'),
        guide: inherit ? _accommodation! : guide,
        embedded: true,
      ),
      onFullscreen: () => _previewGuide(isDaycare: isDaycare),
    );
  }

  Widget _pageControls(
    bool isDaycare,
    int page,
    int count,
    int start,
    int end,
    int total,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          IconButton(
            tooltip: '上一頁',
            onPressed: page == 0
                ? null
                : () => setState(() => _contentPage[isDaycare] = page - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          DropdownButton<int>(
            value: page,
            items: [
              for (var i = 0; i < count; i++)
                DropdownMenuItem(value: i, child: Text('第 ${i + 1} 頁')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _contentPage[isDaycare] = value);
              }
            },
          ),
          IconButton(
            tooltip: '下一頁',
            onPressed: page + 1 == count
                ? null
                : () => setState(() => _contentPage[isDaycare] = page + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          Text('${start + 1}–$end 項，共 $total 項'),
        ],
      ),
    );
  }

  Widget _blockEditor({
    required bool isDaycare,
    required int index,
    required PreArrivalGuideBlock block,
  }) {
    return Card(
      key: ValueKey<String>(block.id),
      color: block.type == PreArrivalGuideBlockType.heading
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : null,
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
                    block.type == PreArrivalGuideBlockType.heading
                        ? '分段標題'
                        : block.type == PreArrivalGuideBlockType.image
                        ? '圖片'
                        : block.type == PreArrivalGuideBlockType.checklist
                        ? '準備物品 ${index + 1}'
                        : '本段說明',
                  ),
                ),
                IconButton(
                  tooltip: '往上移',
                  onPressed: index == 0
                      ? null
                      : () => _move(isDaycare, index, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: '往下移',
                  onPressed:
                      index ==
                          (isDaycare ? _daycare! : _accommodation!)
                                  .blocks
                                  .length -
                              1
                      ? null
                      : () => _move(isDaycare, index, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: '刪除區塊',
                  onPressed: () => _removeBlock(isDaycare, index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (block.type != PreArrivalGuideBlockType.image)
              TextFormField(
                initialValue: block.text,
                minLines: 1,
                maxLines: block.type == PreArrivalGuideBlockType.heading
                    ? 1
                    : 4,
                decoration: InputDecoration(
                  labelText: block.type == PreArrivalGuideBlockType.checklist
                      ? '客戶需要準備什麼？'
                      : block.type == PreArrivalGuideBlockType.heading
                      ? '這一段的名稱，例如「餐食準備」'
                      : '想提醒客戶的事',
                  hintText: block.type == PreArrivalGuideBlockType.checklist
                      ? '例如：攜帶足量日常飼料'
                      : block.type == PreArrivalGuideBlockType.heading
                      ? '例如：必帶物品、餐食準備、安心小物'
                      : '例如：飼料請分裝，並標示貓咪姓名與每餐份量',
                ),
                onChanged: (String value) {
                  _updateBlock(isDaycare, index, block.copyWith(text: value));
                },
              )
            else ...<Widget>[
              if (block.imageUrl.isNotEmpty)
                Image.network(
                  block.imageUrl,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? stack) {
                        return const SizedBox(
                          height: 80,
                          child: Center(child: Text('圖片載入失敗')),
                        );
                      },
                ),
              TextFormField(
                initialValue: block.caption,
                decoration: const InputDecoration(labelText: '圖片說明（可空白）'),
                onChanged: (String value) {
                  _updateBlock(
                    isDaycare,
                    index,
                    block.copyWith(caption: value),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addExample(bool isDaycare) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加入分類準備清單？'),
        content: const Text(
          '會加入必須攜帶、視需要攜帶、店家提供與到店提醒四個分段，保留現有內容。請確認並修改店內提供的用品，再儲存。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('加入草稿'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _saving) return;
    final guide = isDaycare ? _daycare! : _accommodation!;
    final updated = appendPreArrivalExample(
      guide,
      idPrefix: 'example-${DateTime.now().microsecondsSinceEpoch}',
    );
    setState(() {
      _showSettings[isDaycare] = false;
      _contentPage[isDaycare] = guide.blocks.length ~/ _blocksPerPage;
      if (isDaycare) {
        _daycare = updated;
      } else {
        _accommodation = updated;
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已加入分類清單；請依實際服務修改後儲存。')));
  }

  Future<void> _addChecklist(bool isDaycare, {bool template = false}) async {
    final text = await showDialog<PreArrivalTemplateDraft>(
      context: context,
      builder: (_) => PreArrivalChecklistTemplateDialog(
        isDaycare: isDaycare,
        useTemplate: template,
      ),
    );
    if (!mounted || text == null) return;
    if (template) {
      final guide = isDaycare ? _daycare! : _accommodation!;
      final updated = applyPreArrivalTemplate(
        guide,
        text,
        revision: DateTime.now().microsecondsSinceEpoch.toString(),
      );
      setState(() {
        if (isDaycare) {
          _daycare = updated;
        } else {
          _accommodation = updated;
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已套用分段模板，可在下方修改；尚未儲存。')));
      return;
    }
    final lines = text.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    final guide = isDaycare ? _daycare! : _accommodation!;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final blocks = <PreArrivalGuideBlock>[
      ...guide.blocks,
      for (int i = 0; i < lines.length; i++)
        PreArrivalGuideBlock(
          id: '$stamp-$i',
          type: PreArrivalGuideBlockType.checklist,
          text: lines[i],
          sortOrder: guide.blocks.length + i,
        ),
    ];
    setState(() {
      _contentPage[isDaycare] = guide.blocks.length ~/ _blocksPerPage;
      if (isDaycare) {
        _daycare = guide.copyWith(blocks: blocks);
      } else {
        _accommodation = guide.copyWith(blocks: blocks);
      }
    });
  }

  void _addSection(bool isDaycare) {
    final guide = isDaycare ? _daycare! : _accommodation!;
    final id = DateTime.now().microsecondsSinceEpoch;
    final updated = guide.copyWith(
      blocks: [
        ...guide.blocks,
        PreArrivalGuideBlock(
          id: 'section-$id-title',
          type: PreArrivalGuideBlockType.heading,
          sortOrder: guide.blocks.length,
        ),
        PreArrivalGuideBlock(
          id: 'section-$id-text',
          type: PreArrivalGuideBlockType.text,
          sortOrder: guide.blocks.length + 1,
        ),
      ],
    );
    setState(() {
      _showSettings[isDaycare] = false;
      _contentPage[isDaycare] = guide.blocks.length ~/ _blocksPerPage;
      if (isDaycare) {
        _daycare = updated;
      } else {
        _accommodation = updated;
      }
    });
  }

  void _addBlock(bool isDaycare, String type) {
    final PreArrivalGuideModel guide = isDaycare ? _daycare! : _accommodation!;
    final List<PreArrivalGuideBlock> blocks =
        List<PreArrivalGuideBlock>.from(guide.blocks)..add(
          PreArrivalGuideBlock(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: type,
            sortOrder: guide.blocks.length,
          ),
        );
    setState(() {
      _showSettings[isDaycare] = false;
      _contentPage[isDaycare] = guide.blocks.length ~/ _blocksPerPage;
      if (isDaycare) {
        _daycare = guide.copyWith(blocks: blocks);
      } else {
        _accommodation = guide.copyWith(blocks: blocks);
      }
    });
  }

  Future<void> _addImage(bool isDaycare) async {
    try {
      final picked = await PreArrivalGuideService.instance.pickImage();
      if (picked == null) {
        return;
      }
      final PreArrivalGuideImageUpload uploaded = await PreArrivalGuideService
          .instance
          .uploadImage(
            shopId: widget.shopId,
            serviceType: isDaycare
                ? PreArrivalGuideServiceType.daycare
                : PreArrivalGuideServiceType.accommodation,
            image: picked,
          );
      _sessionUploads.add(uploaded.storagePath);
      final PreArrivalGuideModel guide = isDaycare
          ? _daycare!
          : _accommodation!;
      final List<PreArrivalGuideBlock> blocks =
          List<PreArrivalGuideBlock>.from(guide.blocks)..add(
            PreArrivalGuideBlock(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              type: PreArrivalGuideBlockType.image,
              imageUrl: uploaded.imageUrl,
              storagePath: uploaded.storagePath,
              sortOrder: guide.blocks.length,
            ),
          );
      setState(() {
        _showSettings[isDaycare] = false;
        _contentPage[isDaycare] = guide.blocks.length ~/ _blocksPerPage;
        if (isDaycare) {
          _daycare = guide.copyWith(blocks: blocks);
        } else {
          _accommodation = guide.copyWith(blocks: blocks);
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _updateBlock(bool isDaycare, int index, PreArrivalGuideBlock block) {
    final PreArrivalGuideModel guide = isDaycare ? _daycare! : _accommodation!;
    final List<PreArrivalGuideBlock> blocks = List<PreArrivalGuideBlock>.from(
      guide.blocks,
    );
    blocks[index] = block;
    setState(() {
      if (isDaycare) {
        _daycare = guide.copyWith(blocks: blocks);
      } else {
        _accommodation = guide.copyWith(blocks: blocks);
      }
    });
  }

  void _move(bool isDaycare, int index, int delta) {
    final PreArrivalGuideModel guide = isDaycare ? _daycare! : _accommodation!;
    final int next = index + delta;
    if (next < 0 || next >= guide.blocks.length) {
      return;
    }
    final List<PreArrivalGuideBlock> blocks = List<PreArrivalGuideBlock>.from(
      guide.blocks,
    );
    final PreArrivalGuideBlock item = blocks.removeAt(index);
    blocks.insert(next, item);
    for (int i = 0; i < blocks.length; i++) {
      blocks[i] = blocks[i].copyWith(sortOrder: i);
    }
    setState(() {
      _contentPage[isDaycare] = next ~/ _blocksPerPage;
      if (isDaycare) {
        _daycare = guide.copyWith(blocks: blocks);
      } else {
        _accommodation = guide.copyWith(blocks: blocks);
      }
    });
  }

  void _removeBlock(bool isDaycare, int index) {
    final PreArrivalGuideModel guide = isDaycare ? _daycare! : _accommodation!;
    final PreArrivalGuideBlock removed = guide.blocks[index];
    if (removed.storagePath.isNotEmpty) {
      if (_sessionUploads.contains(removed.storagePath)) {
        PreArrivalGuideService.instance.deleteImage(
          storagePath: removed.storagePath,
        );
        _sessionUploads.remove(removed.storagePath);
      } else {
        _pendingDeletes.add(removed.storagePath);
      }
    }
    final List<PreArrivalGuideBlock> blocks = List<PreArrivalGuideBlock>.from(
      guide.blocks,
    )..removeAt(index);
    setState(() {
      if (isDaycare) {
        _daycare = guide.copyWith(blocks: blocks);
      } else {
        _accommodation = guide.copyWith(blocks: blocks);
      }
    });
  }
}
