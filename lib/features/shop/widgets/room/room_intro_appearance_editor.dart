import 'room_intro_typography.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'room_intro_related.dart';
import 'room_intro_comparison.dart';
import 'room_intro_look_editor.dart';
import 'room_intro_surface.dart';
// 功能：房型列表／詳細頁共用外觀草稿工作區，只局部儲存外觀，不修改房型資料。
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/services/shop_permission_service.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/room_intro_appearance.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import '../shop_room_type_workspace.dart';
import '../shop_room_type_live_preview.dart';
import 'room_intro_appearance_scope.dart';
import 'room_intro_list.dart';
import 'room_layout_thumbnail.dart';

class RoomIntroAppearanceEditor extends StatefulWidget {
  const RoomIntroAppearanceEditor({
    super.key,
    required this.shopId,
    required this.detailMode,
    this.roomTypesStream,
    this.onManage,
    this.saveAppearance,
  });
  final String shopId;
  final bool detailMode;
  final Stream<List<Map<String, dynamic>>>? roomTypesStream;
  final VoidCallback? onManage;
  final Future<void> Function(Map<String, dynamic>)? saveAppearance;
  @override
  State<RoomIntroAppearanceEditor> createState() =>
      RoomIntroAppearanceEditorState();
}

class RoomIntroAppearanceEditorState extends State<RoomIntroAppearanceEditor> {
  late Stream<List<Map<String, dynamic>>> _types;
  RoomIntroAppearance _draft = const RoomIntroAppearance(),
      _saved = const RoomIntroAppearance();
  bool _loaded = false, _saving = false, _preview = false;
  String? _roomId;
  final _title = TextEditingController(),
      _description = TextEditingController();
  bool get isBusy => _saving;
  bool get hasChanges =>
      jsonEncode(_draft.toMap()) != jsonEncode(_saved.toMap());
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _types =
        widget.roomTypesStream ??
        ShopService.instance.streamRoomTypes(widget.shopId);
  }

  @override
  void didUpdateWidget(covariant RoomIntroAppearanceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) {
      _loaded = false;
      _roomId = null;
      _bind();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = RoomIntroAppearanceScope.maybeOf(context);
    if (!_loaded && scope?.ready == true) {
      _draft = _saved = scope!.appearance;
      _loaded = true;
      _syncText();
    }
  }

  void _syncText() {
    _title.text = _draft.list.title;
    _description.text = _draft.list.description;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<bool> confirmLeave() async {
    if (_saving) return false;
    if (!hasChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('外觀設定尚未儲存'),
        content: const Text('要放棄列表與詳細頁的外觀變更嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('繼續編輯'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放棄變更並離開'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return false;
    setState(() {
      _draft = _saved;
      _syncText();
    });
    return true;
  }

  Future<void> _save() async {
    if (_saving || !_loaded || !hasChanges) return;
    final shopId = widget.shopId, next = _draft;
    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
        if (next.showComparison != _saved.showComparison)
          '${RoomIntroAppearance.path}.showComparison': next.showComparison,
        if (jsonEncode(next.list.toMap()) != jsonEncode(_saved.list.toMap()))
          '${RoomIntroAppearance.path}.list': next.list.toMap(),
        if (jsonEncode(next.detail.toMap()) !=
            jsonEncode(_saved.detail.toMap()))
          '${RoomIntroAppearance.path}.detail': next.detail.toMap(),
      };
      if (widget.saveAppearance != null) {
        await widget.saveAppearance!(updates);
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) throw StateError('未登入');
        final member = await ShopService.instance.getUserMemberInShop(
          shopId: shopId,
          uid: uid,
        );
        final shop =
            (await FirebaseFirestore.instance
                    .collection('shops')
                    .doc(shopId)
                    .get())
                .data();
        if (!mounted || widget.shopId != shopId) return;
        if (FirebaseAuth.instance.currentUser?.uid != uid ||
            shop == null ||
            !ShopPermissionService.canEditShopData(shop) ||
            !ShopService.instance.hasPermission(
              member,
              ShopPermissionKeys.manageFrontendContent,
            )) {
          throw StateError('無外觀設定權限');
        }
        await ShopService.instance.updateShop(shopId: shopId, data: updates);
      }
      if (!mounted || widget.shopId != shopId) return;
      setState(() => _saved = next);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('房型外觀已儲存')));
    } catch (_) {
      if (mounted && widget.shopId == shopId) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('儲存失敗，草稿已保留；請確認權限或稍後重試。')));
      }
    } finally {
      if (mounted && widget.shopId == shopId) setState(() => _saving = false);
    }
  }

  void _list(RoomListAppearance value) =>
      setState(() => _draft = _draft.copyWith(list: value));
  void _detail(RoomDetailAppearance value) =>
      setState(() => _draft = _draft.copyWith(detail: value));
  @override
  Widget build(BuildContext context) {
    final scope = RoomIntroAppearanceScope.maybeOf(context)!;
    if (!_loaded) {
      return Center(
        child: scope.error != null
            ? const Text('外觀設定讀取失敗，請重新開啟頁面。')
            : const CircularProgressIndicator(),
      );
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _types,
      builder: (context, snapshot) {
        final rooms = snapshot.data ?? const <Map<String, dynamic>>[];
        final room =
            rooms.where((r) => r['id'] == _roomId).firstOrNull ??
            rooms.firstOrNull;
        final editor = Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('套用於顧客端房型介紹頁，不影響價格、庫存與預約規則。\n首頁的房型展示請至前台外觀設定調整。'),
            ),
            Expanded(
              child: IgnorePointer(
                ignoring: _saving,
                child: ListView(
                  key: PageStorageKey(
                    widget.detailMode
                        ? 'room-detail-appearance'
                        : 'room-list-appearance',
                  ),
                  padding: const EdgeInsets.all(16),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('顯示比較房型'),
                      subtitle: const Text('關閉後，房型列表與房型詳細頁將隱藏比較入口。'),
                      value: _draft.showComparison,
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(showComparison: value),
                      ),
                    ),
                    if (widget.detailMode)
                      ..._detailSettings(rooms, room?['id']?.toString())
                    else
                      ..._listSettings(rooms),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: Text(hasChanges ? '有未儲存變更' : '已儲存')),
                    FilledButton(
                      onPressed: hasChanges && !_saving ? _save : null,
                      child: Text(_saving ? '儲存中…' : '儲存外觀'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        final preview = snapshot.hasError
            ? const Center(child: Text('房型讀取失敗'))
            : snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData
            ? const Center(child: CircularProgressIndicator())
            : rooms.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('目前沒有房型可預覽'),
                    if (widget.onManage != null)
                      TextButton(
                        onPressed: widget.onManage,
                        child: const Text('前往房型與房間'),
                      ),
                  ],
                ),
              )
            : widget.detailMode
            ? ShopRoomTypeLivePreview(
                draft: ShopRoomTypeDraft.fromRoomType(room!),
                theme: scope.theme,
                appearance: _draft.detail,
                related: RoomIntroRelated(
                  shopId: widget.shopId,
                  theme: scope.theme,
                  previewOnly: true,
                  showComparison: _draft.showComparison,
                  layout: _draft.detail.layout,
                  compare: TextButton.icon(
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('比較房型'),
                    onPressed: () => _comparePreview(
                      rooms,
                      scope.theme,
                      room['id']?.toString(),
                    ),
                  ),
                ),
              )
            : Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 390,
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(size: const Size(390, 740)),
                    child: Material(
                      color: scope.theme.backgroundColor,
                      child: RoomIntroSurface(
                        look: _draft.list.look,
                        theme: scope.theme,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: RoomIntroList(
                            rooms: rooms,
                            setting: _draft.list,
                            showComparison: _draft.showComparison,
                            theme: scope.theme,
                            onCompare: () =>
                                _comparePreview(rooms, scope.theme, _roomId),
                            onOpen: (room) => setState(
                              () => _roomId = room['id']?.toString(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
        return ShopRoomTypeWorkspace(
          editor: editor,
          preview: preview,
          showPreview: _preview,
          onPreviewChanged: (value) => setState(() => _preview = value),
          editLabel: '設定',
          previewLabel: '預覽',
        );
      },
    );
  }

  void _comparePreview(
    List<Map<String, dynamic>> rooms,
    HomeThemeModel theme,
    String? id,
  ) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 800,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: '關閉比較預覽',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: RoomIntroComparison(
                  rooms: rooms,
                  theme: theme,
                  initialId: id,
                  onOpen: (r) {
                    Navigator.pop(context);
                    setState(() => _roomId = r['id']?.toString());
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _combo() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: OutlinedButton.icon(
      icon: const Icon(Icons.hotel_outlined),
      label: const Text('套用旅宿瀏覽組合'),
      onPressed: () => setState(
        () => _draft = _draft.copyWith(
          list: _draft.list.copyWith(layout: 'lodging'),
          detail: _draft.detail.copyWith(layout: 'lodging'),
        ),
      ),
    ),
  );
  Widget _choices(
    String label,
    String value,
    Map<String, String> choices,
    ValueChanged<String> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in choices.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: e.key == value,
                onSelected: (_) => onChanged(e.key),
              ),
          ],
        ),
      ],
    ),
  );
  Widget _toggle(String label, bool value, ValueChanged<bool> change) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: change,
      );
  Widget _layouts(
    String selected,
    Map<String, String> names,
    Map<String, String> descriptions,
    ValueChanged<String> change,
  ) => LayoutBuilder(
    builder: (context, c) => Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final e in names.entries)
          SizedBox(
            width: c.maxWidth >= 600 ? (c.maxWidth - 10) / 2 : c.maxWidth,
            child: Card(
              color: selected == e.key
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: InkWell(
                onTap: () => change(e.key),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RoomLayoutThumbnail(
                        layout: e.key,
                        detail: names.containsKey('classic'),
                      ),
                      Text(
                        e.value,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(descriptions[e.key]!),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
  Widget _pageFont(RoomIntroLook look, ValueChanged<RoomIntroLook> update) =>
      Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.detailMode ? '房型詳細：整頁字體' : '房間介紹：整頁字體',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text('選一次，整頁標題、內文、價格與按鈕一起套用。兩頁分別設定、各自保留。'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  'room-page-font-${widget.detailMode}-${look.fontFamily}',
                ),
                initialValue: look.appliedFontFamily ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: '整頁字體'),
                items: <DropdownMenuItem<String>>[
                  for (final entry in RoomIntroLook.fonts.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontFamily: entry.key.isEmpty ? null : entry.key,
                        ),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) update(look.copyWith(fontFamily: value));
                },
              ),
              const SizedBox(height: 12),
              RoomIntroTypography(
                look: look,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '舒適貓咪客房',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('溫暖安心的住宿空間 · NT\$ 800 / 晚'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  List<Widget> _listSettings(List<Map<String, dynamic>> rooms) {
    final s = _draft.list;
    final ordered = s.ordered(rooms);
    return [
      _pageFont(s.look, (look) => _list(s.copyWith(look: look))),
      _combo(),
      const Text('排版選擇', style: TextStyle(fontWeight: FontWeight.bold)),
      _layouts(
        s.layout,
        const {
          'vertical': '照片直式卡',
          'horizontal': '精簡橫式卡',
          'columns': '雙欄展示卡',
          'carousel': '滑動展示',
          'switcher': '房型切換',
          'comparison': '房型比較',
          'lodging': '旅宿雙欄',
        },
        const {
          'carousel': '左右滑動，一次瀏覽一個房型',
          'switcher': '選擇名稱切換目前展示的房型',
          'comparison': '兩個房型逐列對照',
          'lodging': '照片相簿雙欄，搭配容量與價格',
          'vertical': '照片在上、內容自然增高',
          'horizontal': '左照片右資訊，適合快速比較',
          'columns': '一排兩張；窄畫面安全改單欄',
        },
        (v) => _list(s.copyWith(layout: v)),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('目前排版設定', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      if (s.layout != 'comparison') ...[
        _toggle(
          '顯示容量',
          s.showCapacity,
          (v) => _list(s.copyWith(showCapacity: v)),
        ),
        _toggle(
          '顯示特色摘要（沿用房型資料）',
          s.showFeatures,
          (v) => _list(s.copyWith(showFeatures: v)),
        ),
      ],
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('圖片與文字', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      TextField(
        controller: _title,
        decoration: const InputDecoration(labelText: '頁面標題'),
        onChanged: (v) => _list(s.copyWith(title: v)),
      ),
      TextField(
        controller: _description,
        decoration: const InputDecoration(labelText: '簡短說明'),
        maxLines: 3,
        onChanged: (v) => _list(s.copyWith(description: v)),
      ),
      _toggle(
        '顯示簡短說明',
        s.showDescription,
        (v) => _list(s.copyWith(showDescription: v)),
      ),
      if (s.layout != 'comparison') ...[
        _choices('圖片比例', s.imageAspect, const {
          'square': '正方形',
          'landscape': '4:3',
          'wide': '16:9',
        }, (v) => _list(s.copyWith(imageAspect: v))),
        _choices('圖片顯示', s.imageFit, const {
          'cover': '填滿裁切',
          'contain': '完整顯示',
        }, (v) => _list(s.copyWith(imageFit: v))),
      ],
      if (s.layout != 'comparison')
        ExpansionTile(
          key: const PageStorageKey<String>('room-list-card-advanced'),
          title: const Text('卡片與按鈕'),
          children: [
            _choices('卡片間距', s.spacing, const {
              'compact': '緊湊',
              'standard': '標準',
              'wide': '寬鬆',
            }, (v) => _list(s.copyWith(spacing: v))),
            _choices('查看房型介紹按鈕', s.buttonStyle, const {
              'tonal': '淡色圓角',
              'filled': '實心按鈕',
              'text': '文字箭頭',
            }, (v) => _list(s.copyWith(buttonStyle: v))),
          ],
        ),
      if (s.layout != 'comparison')
        RoomIntroLookEditor(
          value: s.look,
          onChanged: (v) => _list(s.copyWith(look: v)),
          storageId: 'room-list-structure-advanced',
        ),
      const Text(
        '房型展示順序（只影響介紹列表）',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ordered.length,
        onReorder: (oldIndex, newIndex) {
          final ids = ordered.map((r) => r['id'].toString()).toList();
          if (newIndex > oldIndex) newIndex--;
          ids.insert(newIndex, ids.removeAt(oldIndex));
          _list(s.copyWith(roomOrder: ids));
        },
        itemBuilder: (context, i) => ListTile(
          key: ValueKey(ordered[i]['id']),
          title: Text((ordered[i]['name'] ?? '未命名房型').toString()),
          leading: const Icon(Icons.drag_handle),
        ),
      ),
    ];
  }

  List<Widget> _detailSettings(
    List<Map<String, dynamic>> rooms,
    String? selected,
  ) {
    final s = _draft.detail;
    return [
      _pageFont(s.look, (look) => _detail(s.copyWith(look: look))),
      _combo(),
      DropdownButtonFormField<String>(
        initialValue: selected,
        key: ValueKey(selected),
        decoration: const InputDecoration(labelText: '預覽房型'),
        items: [
          for (final room in rooms)
            DropdownMenuItem(
              value: room['id'].toString(),
              child: Text(
                (room['name'] ?? '未命名房型').toString(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) => setState(() => _roomId = v),
      ),
      _layouts(
        s.layout,
        const {
          'classic': '經典介紹',
          'compact': '精簡分區',
          'sideBySide': '圖文並排',
          'tabs': '分頁閱讀',
          'panel': '照片＋展開面板',
          'anchors': '區段導覽',
          'lodging': '旅宿詳情',
        },
        const {
          'tabs': '照片下切換介紹、尺寸與設備',
          'panel': '照片為主，展開完整介紹面板',
          'anchors': '連續長頁，點區段直接定位',
          'lodging': '大相簿、圓角資訊及相關資訊',
          'classic': '照片置頂，熟悉的閱讀順序',
          'compact': '價格與容量整理成緊湊資訊區',
          'sideBySide': '寬螢幕左照片右資訊，手機上下排列',
        },
        (v) => _detail(s.copyWith(layout: v)),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('目前排版設定', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      _choices('房間尺寸', s.dimensionsStyle, const {
        'tiles': '三格資訊（僅顯示有資料項目）',
        'line': '簡約文字列',
      }, (v) => _detail(s.copyWith(dimensionsStyle: v))),
      _choices('介紹與設備順序', s.contentOrder, const {
        'descriptionFirst': '介紹在前',
        'featuresFirst': '設備在前',
      }, (v) => _detail(s.copyWith(contentOrder: v))),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('圖片與文字', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      _choices('照片排版', s.photoLayout, const {
        'bottom': '下方縮圖',
        'left': '左側縮圖',
        'right': '右側縮圖',
        'overlay': '照片內浮動縮圖',
        'collage': '主圖＋多圖拼貼',
        'grid': '多圖網格',
      }, (v) => _detail(s.copyWith(photoLayout: v))),
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text('照片排版可搭配上方任一詳細頁版型。拼貼與網格會同時呈現多張照片，點照片可放大；僅一張時自動顯示主圖。'),
      ),
      _choices('照片比例', s.imageAspect, const {
        'square': '正方形',
        'landscape': '4:3',
        'wide': '16:9',
      }, (v) => _detail(s.copyWith(imageAspect: v))),
      _choices('照片顯示', s.imageFit, const {
        'cover': '填滿裁切',
        'contain': '完整顯示',
      }, (v) => _detail(s.copyWith(imageFit: v))),
      _toggle(
        '顯示縮圖導覽（拼貼與網格仍會顯示多張照片）',
        s.showThumbnails,
        (v) => _detail(s.copyWith(showThumbnails: v)),
      ),
      RoomIntroLookEditor(
        value: s.look,
        onChanged: (v) => _detail(s.copyWith(look: v)),
        storageId: 'room-detail-structure-advanced',
        showDimensions: false,
        showRadius: false,
        extra: [
          _choices('卡片底色', s.surface, const {
            'theme': '沿用主題',
            'pale': '淡色底',
            'transparent': '透明',
          }, (v) => _detail(s.copyWith(surface: v))),
          _choices('圓角', s.radius, const {
            'small': '小',
            'standard': '標準',
            'large': '大',
          }, (v) => _detail(s.copyWith(radius: v))),
          _choices('區塊間距', s.spacing, const {
            'compact': '緊湊',
            'standard': '標準',
            'wide': '寬鬆',
          }, (v) => _detail(s.copyWith(spacing: v))),
        ],
      ),
    ];
  }
}
