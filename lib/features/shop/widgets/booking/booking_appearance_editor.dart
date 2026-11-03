import 'booking_look_editor.dart';
import 'booking_quick_template_card.dart';
import 'booking_arrival_preview.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/services/shop_permission_service.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';

class BookingAppearanceEditor extends StatefulWidget {
  const BookingAppearanceEditor({
    super.key,
    required this.shopId,
    required this.shopStream,
  });
  final String shopId;
  final Stream<Map<String, dynamic>?> shopStream;
  @override
  State<BookingAppearanceEditor> createState() =>
      BookingAppearanceEditorState();
}

class BookingAppearanceEditorState extends State<BookingAppearanceEditor> {
  final _title = TextEditingController(), _note = TextEditingController();
  BookingPageAppearance _saved = const BookingPageAppearance();
  bool _loaded = false, _saving = false, _compact = false, _narrow = false;
  String _style = 'warm';
  bool _mobilePreview = false;
  final _settingsScroll = ScrollController(),
      _previewScroll = ScrollController();
  Map<String, BookingPageLook> _looks = {};
  bool get isBusy => _saving;
  BookingPageAppearance get _draft => BookingPageAppearance(
    reminderTitle: _title.text.trim().isEmpty ? '預約前提醒' : _title.text.trim(),
    note: _note.text.trim(),
    style: _style,
    looks: Map.of(_looks),
    compact: _compact,
    narrow: _narrow,
  );
  bool get hasChanges =>
      _loaded && jsonEncode(_draft.toMap()) != jsonEncode(_saved.toMap());
  void _reset(BookingPageAppearance value) {
    _title.text = value.reminderTitle;
    _note.text = value.note;
    _style = value.style;
    _looks = Map.of(value.looks);
    _compact = value.compact;
    _narrow = value.narrow;
  }

  Future<bool> confirmLeave() async {
    if (_saving) return false;
    if (!hasChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('預約頁外觀尚未儲存'),
        content: const Text('要放棄這次變更嗎？'),
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
    setState(() => _reset(_saved));
    return true;
  }

  Future<void> _save() async {
    if (_saving || !hasChanges) return;
    final next = _draft;
    final savingShopId = widget.shopId;
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('請先登入');
      final member = await ShopService.instance.getUserMemberInShop(
        shopId: savingShopId,
        uid: uid,
      );
      final shop =
          (await FirebaseFirestore.instance
                  .collection('shops')
                  .doc(savingShopId)
                  .get())
              .data();
      if (!mounted || widget.shopId != savingShopId) return;
      if (FirebaseAuth.instance.currentUser?.uid != uid ||
          shop == null ||
          !ShopPermissionService.canEditShopData(shop) ||
          !ShopService.instance.hasPermission(
            member,
            ShopPermissionKeys.manageFrontendContent,
          )) {
        throw StateError('目前無法儲存，請確認店家狀態與外觀編輯權限');
      }
      await ShopService.instance.updateShop(
        shopId: savingShopId,
        data: {BookingPageAppearance.path: next.toMap()},
      );
      if (!mounted || widget.shopId != savingShopId) return;
      setState(() => _saved = next);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('預約頁外觀已儲存')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('儲存失敗，請確認權限與網路後重試；草稿已保留')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void didUpdateWidget(covariant BookingAppearanceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) {
      _mobilePreview = false;
      _loaded = false;
      _saved = const BookingPageAppearance();
      _reset(_saved);
    }
  }

  @override
  void dispose() {
    _settingsScroll.dispose();
    _previewScroll.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Widget _templateSection(String title, List<String> styles) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 580
              ? 3
              : constraints.maxWidth >= 340
              ? 2
              : 1;
          final compactCards = MediaQuery.sizeOf(context).width < 900;
          final height = MediaQuery.textScalerOf(context).scale(14) > 21
              ? 320.0
              : compactCards
              ? 224.0
              : 258.0;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: styles.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: height,
            ),
            itemBuilder: (context, index) {
              final style = styles[index];
              return BookingQuickTemplateCard(
                key: ValueKey(
                  style == 'cream' || style == 'house'
                      ? 'booking-quick-$style'
                      : 'booking-style-$style',
                ),
                style: style,
                compact: compactCards,
                selected: _style == style,
                onApply: _saving ? null : () => setState(() => _style = style),
              );
            },
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>?>(
    stream: widget.shopStream,
    builder: (context, snapshot) {
      if (!_loaded) {
        if (snapshot.hasError) {
          return const Center(child: Text('無法載入預約頁外觀，請稍後重新開啟'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        _saved = BookingPageAppearance.fromShop(snapshot.data);
        _reset(_saved);
        _loaded = true;
      }
      return LayoutBuilder(
        builder: (context, viewport) {
          final desktop = viewport.maxWidth >= 900;
          final settings = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('預約頁外觀', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('先選模板，再調整內容與配色；可隨時切換即時預覽。'),
              const SizedBox(height: 20),
              _templateSection('快速模板', const ['cream', 'house']),
              const SizedBox(height: 20),
              _templateSection('其他排版', const [
                'original',
                'warm',
                'boutique',
                'minimal',
                'soft',
                'compact',
              ]),
              const SizedBox(height: 12),
              const Text('點選卡片可預覽；只更新草稿，保留提醒與寬度設定。按「儲存」後才會套用到客人頁面。'),
              const Divider(height: 36),
              if (_draft.lookEditable)
                BookingLookEditor(
                  key: ValueKey('look-editor-$_style'),
                  look: _draft.look,
                  enabled: !_saving,
                  onChanged: (value) => setState(() => _looks[_style] = value),
                  onReset: () => setState(() => _looks.remove(_style)),
                )
              else
                const Text(
                  '造型模板保留插畫、照片框與配色。可調整下方提醒內容與頁面寬度；底色、文字色與字型請至「其他排版」設定。',
                ),
              const Divider(height: 30),
              Text('內容與顯示', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                enabled: !_saving,
                maxLength: 30,
                decoration: const InputDecoration(labelText: '提醒標題'),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _note,
                enabled: !_saving,
                maxLength: 300,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '店家補充提醒',
                  hintText: '例如：首次入住請先聯繫店家確認疫苗資料',
                ),
                onChanged: (_) => setState(() {}),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('緊湊頁面留白'),
                value: _compact,
                onChanged: _saving ? null : (v) => setState(() => _compact = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('窄版內容'),
                subtitle: const Text('桌面內容寬度 600；標準為 760'),
                value: _narrow,
                onChanged: _saving ? null : (v) => setState(() => _narrow = v),
              ),
              const SizedBox(height: 16),
              if (desktop)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: hasChanges && !_saving ? _save : null,
                      child: Text(_saving ? '儲存中…' : '儲存'),
                    ),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(
                              () => _reset(
                                const BookingPageAppearance(style: 'original'),
                              ),
                            ),
                      child: const Text('恢復預設'),
                    ),
                  ],
                ),
            ],
          );
          final preview = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _narrow ? 340 : 420),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BookingArrivalPreview(
                  appearance: _draft,
                  frontendTheme: BookingPageAppearance.frontendThemeFromShop(
                    snapshot.data,
                  ),
                  shopName:
                      snapshot.data?['name']?.toString() ?? 'PetNest 貓咪旅店',
                  coverUrl: snapshot.data?['coverUrl']?.toString() ?? '',
                ),
              ),
            ),
          );
          if (desktop) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: settings),
                  const SizedBox(width: 32),
                  SizedBox(width: 380, child: preview),
                ],
              ),
            );
          }
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<bool>(
                      key: const ValueKey('booking-mobile-workspace-tabs'),
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: false,
                          icon: MediaQuery.textScalerOf(context).scale(14) > 21
                              ? null
                              : const Icon(Icons.tune, size: 18),
                          label: const Text('外觀設定'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: MediaQuery.textScalerOf(context).scale(14) > 21
                              ? null
                              : const Icon(Icons.phone_iphone, size: 18),
                          label: const Text('即時預覽'),
                        ),
                      ],
                      selected: {_mobilePreview},
                      onSelectionChanged: (values) {
                        FocusScope.of(context).unfocus();
                        setState(() => _mobilePreview = values.single);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '目前版型：${BookingPageAppearance.styles[_style]}${hasChanges ? ' · 尚未儲存' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _mobilePreview ? 1 : 0,
                  sizing: StackFit.expand,
                  children: [
                    SingleChildScrollView(
                      key: const PageStorageKey('booking-mobile-settings'),
                      controller: _settingsScroll,
                      padding: const EdgeInsets.all(16),
                      child: settings,
                    ),
                    SingleChildScrollView(
                      key: const PageStorageKey('booking-mobile-preview'),
                      controller: _previewScroll,
                      padding: const EdgeInsets.all(12),
                      child: preview,
                    ),
                  ],
                ),
              ),
              Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => setState(
                                  () => _reset(
                                    const BookingPageAppearance(
                                      style: 'original',
                                    ),
                                  ),
                                ),
                          child: const Text('恢復預設'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: hasChanges && !_saving ? _save : null,
                            child: Text(_saving ? '儲存中…' : '儲存設定'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
