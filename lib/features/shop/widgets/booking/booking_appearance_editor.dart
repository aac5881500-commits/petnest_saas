import 'booking_confirmation_preview.dart';
import '../platform_media_asset_picker.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:image_picker/image_picker.dart';
import 'booking_service_template_editor.dart';
import 'booking_arrival_layout.dart';
import 'booking_calendar_settings.dart';
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
  String _suiteColorMode = 'template', _heroImage = '';
  int _previewStep = 1;
  bool _uploadingHero = false;
  String _serviceStyle = 'original';
  String _calendarStyle = 'classic',
      _calendarPresentation = 'dialog',
      _calendarDensity = 'compact';
  String _calendarColorMode = 'template';
  int _calendarBackground = 0xFFF0F7F2, _calendarAccent = 0xFF34786B;
  int _workspace = 0;
  final _settingsScroll = ScrollController(),
      _previewScroll = ScrollController();
  Map<String, BookingPageLook> _looks = {};
  bool get isBusy => _saving || _uploadingHero;
  BookingPageAppearance get _draft => BookingPageAppearance(
    reminderTitle: _title.text.trim().isEmpty ? '預約前提醒' : _title.text.trim(),
    note: _note.text.trim(),
    style: _style,
    serviceStyle: _serviceStyle,
    suiteColorMode: _suiteColorMode,
    heroImage: _heroImage,
    calendarStyle: _calendarStyle,
    calendarPresentation: _calendarPresentation,
    calendarDensity: _calendarDensity,
    calendarColorMode: _calendarColorMode,
    calendarBackground: _calendarBackground,
    calendarAccent: _calendarAccent,
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
    _serviceStyle = value.serviceStyle;
    _suiteColorMode = value.suiteColorMode;
    _heroImage = value.heroImage;
    _calendarStyle =
        const {
          'minimal': 'stay',
          'round': 'week',
          'soft': 'journal',
        }[value.calendarStyle] ??
        value.calendarStyle;
    _calendarPresentation = value.calendarPresentation;
    _calendarDensity = value.calendarDensity;
    _calendarColorMode = value.calendarColorMode;
    _calendarBackground = value.calendarBackground;
    _calendarAccent = value.calendarAccent;
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
    if (_saving || _uploadingHero || !hasChanges) return;
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
      _workspace = 0;
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
                  style == 'editorial'
                      ? 'booking-editorial-suite'
                      : style == 'cream' || style == 'house'
                      ? 'booking-quick-$style'
                      : 'booking-style-$style',
                ),
                style: style,
                compact: compactCards,
                selected: _style == style,
                onApply: _saving
                    ? null
                    : () => setState(() => _selectSuite(style)),
              );
            },
          );
        },
      ),
    ],
  );

  void _selectSuite(String style) {
    _style = style;
    _serviceStyle =
        BookingPageAppearance.suiteServiceStyles[style] ?? 'original';
  }

  Future<void> _uploadHero() async {
    if (_saving || _uploadingHero) return;
    final uploadShopId = widget.shopId;
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      setState(() => _uploadingHero = true);
      final bytes = await file.readAsBytes();
      final upload = await ShopService.instance.uploadAboutCoverImage(
        shopId: uploadShopId,
        bytes: bytes,
      );
      if (mounted && widget.shopId == uploadShopId) {
        setState(() => _heroImage = upload.imageUrl);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('圖片上傳失敗，請稍後再試。')));
      }
    } finally {
      if (mounted) setState(() => _uploadingHero = false);
    }
  }

  Widget _heroEditor(Map<String, dynamic>? shop) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('第一頁主圖', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 160,
          child: _heroImage.startsWith('https://')
              ? Image.network(
                  _heroImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, s) =>
                      const Icon(Icons.broken_image_outlined),
                )
              : Image.asset(
                  _heroImage.isEmpty
                      ? BookingPageAppearance.defaultHero
                      : _heroImage,
                  fit: BoxFit.cover,
                ),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: isBusy
                ? null
                : () async {
                    final asset = await showPlatformMediaAssetPicker(
                      context: context,
                      category: PlatformMediaCategories.shopHouse,
                      title: '選擇預約主圖',
                    );
                    if (asset != null && mounted) {
                      setState(() => _heroImage = asset.imageUrl);
                    }
                  },
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('選擇圖庫'),
          ),
          OutlinedButton.icon(
            onPressed: isBusy ? null : _uploadHero,
            icon: const Icon(Icons.upload_outlined),
            label: Text(_uploadingHero ? '上傳中…' : '上傳圖片'),
          ),
          TextButton(
            onPressed: isBusy ? null : () => setState(() => _heroImage = ''),
            child: const Text('恢復預設貓咪圖'),
          ),
        ],
      ),
      const Text('換圖後立即預覽，按儲存才套用到客人頁面。', style: TextStyle(fontSize: 12)),
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
              _templateSection('完整三頁套裝', const [
                'original',
                'editorial',
                'cream',
              ]),
              const SizedBox(height: 8),
              const Text('已完成的套裝與原始預設集中在這裡，選一次套用三頁。'),
              const Divider(height: 32),
              _templateSection('其他版型・待逐步調整', const [
                'house',
                'warm',
                'boutique',
                'minimal',
                'soft',
                'compact',
              ]),
              const SizedBox(height: 12),
              const Text('每張模板一次套用三頁。只更新草稿；按「儲存」後才會套用到客人頁面。'),
              const Divider(height: 36),
              Text('整套配色', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final mode in {
                    'template': '套裝預設',
                    'frontend': '與前台同色',
                    'custom': '自行設定',
                  }.entries)
                    ChoiceChip(
                      key: ValueKey('suite-color-${mode.key}'),
                      label: Text(mode.value),
                      selected: _suiteColorMode == mode.key,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() {
                              _suiteColorMode = mode.key;
                              if (mode.key == 'template') _looks.remove(_style);
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              BookingLookEditor(
                showColors: _suiteColorMode == 'custom',
                key: ValueKey('look-editor-$_style'),
                look: _draft.look,
                enabled: !_saving,
                onChanged: (v) => setState(() => _looks[_style] = v),
                onReset: () => setState(() => _looks.remove(_style)),
              ),
              if (_suiteColorMode == 'frontend')
                const Text('三頁同步使用前台的底色、文字色與重點色。'),
              const Divider(height: 30),
              if (_style == 'cream')
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.lock_outline),
                  title: Text('韓系奶油主圖固定'),
                  subtitle: Text('此套裝保留原有貓咪與小屋插畫，不提供換圖。'),
                )
              else
                _heroEditor(snapshot.data),
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
                      onPressed: hasChanges && !_saving && !_uploadingHero
                          ? _save
                          : null,
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
          final shopName = snapshot.data?['name']?.toString() ?? '貓咪旅館';
          final frontTheme = BookingPageAppearance.frontendThemeFromShop(
            snapshot.data,
          );
          final preview = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _narrow ? 340 : 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      for (final e in {
                        1: '1 日期與貓咪',
                        2: '2 房型與服務',
                        3: '3 費用確認',
                      }.entries)
                        ChoiceChip(
                          key: ValueKey('suite-preview-${e.key}'),
                          label: Text(e.value),
                          selected: _previewStep == e.key,
                          onSelected: (_) =>
                              setState(() => _previewStep = e.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Offstage(
                        offstage: _previewStep != 1,
                        child: BookingArrivalPreview(
                          appearance: _draft,
                          frontendTheme: frontTheme,
                          shopName: shopName,
                        ),
                      ),
                      Offstage(
                        offstage: _previewStep != 2,
                        child: BookingServicePreview(
                          appearance: _draft,
                          frontendTheme: frontTheme,
                          shopName: shopName,
                        ),
                      ),
                      Offstage(
                        offstage: _previewStep != 3,
                        child: BookingConfirmationPreview(
                          appearance: _draft,
                          frontendTheme: frontTheme,
                          shopName: shopName,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
          final calendarSettings = BookingCalendarSettings(
            appearance: _draft,
            pageTheme: BookingArrivalLayout.themeFor(
              _style,
              appearance: _draft,
              originalTheme: BookingPageAppearance.frontendThemeFromShop(
                snapshot.data,
              ),
            ),
            onColors: (mode, background, accent) => setState(() {
              _calendarColorMode = mode;
              _calendarBackground = background;
              _calendarAccent = accent;
            }),
            enabled: !_saving,
            onStyle: (v) => setState(() => _calendarStyle = v),
            onPresentation: (v) => setState(() => _calendarPresentation = v),
            onDensity: (v) => setState(() => _calendarDensity = v),
          );
          final workspaceTabs = Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final entry in {0: '外觀設定', 2: '月曆設定', 1: '即時預覽'}.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _workspace == entry.key,
                  onSelected: (_) {
                    FocusScope.of(context).unfocus();
                    setState(() => _workspace = entry.key);
                  },
                ),
            ],
          );
          if (desktop) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  workspaceTabs,
                  const SizedBox(height: 20),
                  if (_workspace == 2) ...[
                    calendarSettings,
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: hasChanges && !_saving && !_uploadingHero
                            ? _save
                            : null,
                        child: Text(_saving ? '儲存中…' : '儲存設定'),
                      ),
                    ),
                  ] else if (_workspace == 1)
                    preview
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: settings),
                        const SizedBox(width: 32),
                        SizedBox(width: 380, child: preview),
                      ],
                    ),
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
                    workspaceTabs,
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
                  index: _workspace,
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
                    SingleChildScrollView(
                      key: const PageStorageKey('booking-calendar-settings'),
                      padding: const EdgeInsets.all(16),
                      child: calendarSettings,
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
                            onPressed: hasChanges && !_saving && !_uploadingHero
                                ? _save
                                : null,
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
