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
    return _encode(_accommodation) != _encode(_savedAccommodation) ||
        _encode(_daycare) != _encode(_savedDaycare);
  }

  String _encode(PreArrivalGuideModel? guide) {
    if (guide == null) {
      return '';
    }
    return '${guide.enabled}|${guide.title}|${guide.inheritAccommodation}|${guide.blocks.map((PreArrivalGuideBlock b) => '${b.id}:${b.type}:${b.text}:${b.imageUrl}:${b.caption}').join(';')}';
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

  Future<bool> _confirmLeave() async {
    if (!_dirty) {
      return true;
    }
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('尚未儲存'),
          content: const Text('離開此頁面將放棄未儲存的修改。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('繼續編輯'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('離開'),
            ),
          ],
        );
      },
    );
    return leave == true;
  }

  Future<void> _save() async {
    if (_accommodation == null || _daycare == null) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await PreArrivalGuideService.instance.saveGuide(_accommodation!);
      await PreArrivalGuideService.instance.saveGuide(_daycare!);
      for (final String path in _pendingDeletes) {
        await PreArrivalGuideService.instance.deleteImage(storagePath: path);
      }
      _pendingDeletes.clear();
      _sessionUploads.clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAccommodation = _accommodation;
        _savedDaycare = _daycare;
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存入住前準備')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShopTourPage(
      id: 'ShopPreArrivalGuideSettingPage',
      shopId: widget.shopId,
      ready: !_loading,
      error: _tourError,
      onPoint: (_) async {
        _tabs.index = 0;
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
                  return PopScope(
                    canPop: !_dirty,
                    onPopInvokedWithResult:
                        (bool didPop, Object? result) async {
                          if (didPop) {
                            return;
                          }
                          final bool leave = await _confirmLeave();
                          if (!context.mounted) {
                            return;
                          }
                          if (leave) {
                            Navigator.of(context).pop();
                          }
                        },
                    child: Scaffold(
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
                        actions: <Widget>[
                          TextButton(
                            onPressed: _saving ? null : _save,
                            child: Text(_saving ? '儲存中' : '儲存'),
                          ),
                        ],
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
                                        label: const Text('客戶預覽'),
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
    return AbsorbPointer(
      absorbing: _saving,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
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
              if (isDaycare)
                SwitchListTile(
                  title: const Text('沿用住宿內容'),
                  subtitle: const Text('開啟後，客戶安親訂單會顯示住宿的入住前準備內容'),
                  value: guide.inheritAccommodation,
                  onChanged: (bool value) {
                    setState(() {
                      _daycare = guide.copyWith(inheritAccommodation: value);
                    });
                  },
                ),
              const SizedBox(height: 12),
              const Text(
                '1. 寫好準備清單',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
              const SizedBox(height: 12),
              if (!inherit) ...<Widget>[
                const Text(
                  '客戶要帶什麼？',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text('一項物品寫一列，例如「飼料」「外出籠」。不知道怎麼寫，先用常用清單。'),
                const SizedBox(height: 12),
                ShopTourAnchor(
                  ids: isDaycare
                      ? const []
                      : const ['ShopPreArrivalGuideSettingPage.1'],
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.icon(
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
                        label: const Text('使用常用清單'),
                      ),
                      PopupMenuButton<String>(
                        tooltip: '其他新增方式',
                        onSelected: (value) {
                          if (value == 'batch') {
                            _addChecklist(isDaycare);
                          } else if (value == 'image') {
                            _addImage(isDaycare);
                          } else {
                            _addBlock(isDaycare, value);
                          }
                        },
                        itemBuilder: (_) => const [
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
                          PopupMenuItem(value: 'image', child: Text('加說明圖片')),
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
                              Text('加標題、說明或圖片'),
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
                for (int i = 0; i < guide.blocks.length; i++)
                  _blockEditor(
                    isDaycare: isDaycare,
                    index: i,
                    block: guide.blocks[i],
                  ),
              ],
              const SizedBox(height: 16),
              const Text(
                '2. 確認客戶看到的畫面',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text('可試勾物品，檢查內容和順序；預覽不會儲存。'),
              const SizedBox(height: 8),
              ShopTourAnchor(
                ids: isDaycare
                    ? const []
                    : const ['ShopPreArrivalGuideSettingPage.2'],
                child: OutlinedButton(
                  onPressed: () {
                    final PreArrivalGuideModel preview = inherit
                        ? _accommodation!
                        : guide;
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PreArrivalGuidePage(guide: preview),
                      ),
                    );
                  },
                  child: const Text('客戶畫面預覽'),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '3. 決定是否提供給客戶',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ShopTourAnchor(
                ids: isDaycare
                    ? const []
                    : const ['ShopPreArrivalGuideSettingPage.0'],
                child: SwitchListTile(
                  title: const Text('讓客戶在訂單中看到這份清單'),
                  subtitle: Text(
                    guide.enabled
                        ? '已選擇提供給客戶，請按「儲存內容」完成設定。'
                        : '目前關閉。可先儲存草稿，準備好再開啟。',
                  ),
                  value: guide.enabled,
                  onChanged: (bool value) {
                    setState(() {
                      if (isDaycare) {
                        _daycare = guide.copyWith(enabled: value);
                      } else {
                        _accommodation = guide.copyWith(enabled: value);
                      }
                    });
                  },
                ),
              ),
              const Text(
                '最後按下方「儲存內容」。開關關閉時只儲存草稿；開啟且有內容，客戶才能從訂單詳情查看。',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
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
                        ? '段落標題'
                        : block.type == PreArrivalGuideBlockType.image
                        ? '圖片'
                        : block.type == PreArrivalGuideBlockType.checklist
                        ? '準備物品 ${index + 1}'
                        : '補充說明',
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
                      ? '這一段的名稱'
                      : '想提醒客戶的事',
                  hintText: block.type == PreArrivalGuideBlockType.checklist
                      ? '例如：攜帶足量日常飼料'
                      : block.type == PreArrivalGuideBlockType.heading
                      ? '例如：必帶物品、特殊需求'
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
        title: const Text('加入完整示範到草稿？'),
        content: const Text('會在原有內容後方加入標題、說明與勾選項目，保留現有內容。請依店內服務調整，再預覽、啟用並儲存。'),
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
      if (isDaycare) {
        _daycare = updated;
      } else {
        _accommodation = updated;
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已加入示範草稿，尚未儲存；請往下調整內容。')));
  }

  Future<void> _addChecklist(bool isDaycare, {bool template = false}) async {
    String draft = template
        ? '日常飼料（分裝並標示份量）\n外出籠或提籠\n熟悉的毛毯或安撫物\n如需用藥：藥品及使用說明'
        : '';
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(template ? '常用準備清單' : '批次新增勾選項目'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('每行一個項目，可先修改再加入；會加在原有內容後方。'),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: draft,
                onChanged: (value) => draft = value,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '準備項目',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draft),
            child: const Text('加入清單'),
          ),
        ],
      ),
    );
    if (!mounted || text == null) return;
    final lines = text
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
      if (isDaycare) {
        _daycare = guide.copyWith(blocks: blocks);
      } else {
        _accommodation = guide.copyWith(blocks: blocks);
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
