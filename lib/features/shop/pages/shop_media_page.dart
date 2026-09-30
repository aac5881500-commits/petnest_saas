// 檔案名稱：lib/features/shop/pages/shop_media_page.dart
// 功能說明：首頁活動海報管理。手機先看清單，桌機左側預覽完整新版首頁。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_banner_display.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_banner_editor_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_editor_preview.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_view.dart';

class ShopMediaPage extends StatefulWidget {
  const ShopMediaPage({
    super.key,
    required this.shopId,
    this.seedBanners,
    this.omitLivePreview = false,
  });

  final String shopId;

  /// 只給清單版面測試使用，正式頁面不會傳入。
  @visibleForTesting
  final List<StoreBannerModel>? seedBanners;

  /// 版面測試略過會連線的前台預覽，正式頁面保持即時預覽。
  @visibleForTesting
  final bool omitLivePreview;

  @override
  State<ShopMediaPage> createState() => _ShopMediaPageState();
}

enum _HomePreviewWidth { phone, tablet, desktop }

class _ShopMediaPageState extends State<ShopMediaPage> {
  bool _loaded = false;
  bool _busy = false;
  List<StoreBannerModel> _banners = <StoreBannerModel>[];
  StoreBannerModel? _pendingDraft;
  StoreBannerModel? _editDraft;
  HomeThemeModel _theme = HomeThemeModel.modernDefault;
  String? _editingId;
  _HomePreviewWidth _previewWidth = _HomePreviewWidth.phone;
  final StoreBannerEditorController _editor = StoreBannerEditorController();
  final HomeBannerImageCleanup _removedImages = HomeBannerImageCleanup();

  StoreBannerModel? get _editing {
    final String? id = _editingId;
    if (id == null) {
      return null;
    }
    final StoreBannerModel? pending = _pendingDraft;
    if (pending != null && pending.id == id) {
      return pending;
    }
    final StoreBannerModel? editing = _editDraft;
    if (editing != null && editing.id == id) {
      return editing;
    }
    for (final StoreBannerModel banner in _banners) {
      if (banner.id == id) {
        return banner;
      }
    }
    return null;
  }

  List<StoreBannerModel> get _previewBanners {
    final StoreBannerModel? selected = _editing;
    final List<StoreBannerModel> visible = <StoreBannerModel>[];
    for (final StoreBannerModel banner in _banners) {
      if (!banner.enabled && banner.id != selected?.id) {
        continue;
      }
      final StoreBannerModel? editing = _editDraft;
      visible.add(
        editing != null && editing.id == banner.id ? editing : banner,
      );
    }
    final StoreBannerModel? pending = _pendingDraft;
    if (pending != null && selected?.id == pending.id) {
      visible.add(pending);
    }
    return visible;
  }

  void _selectPublished(String id) {
    setState(() {
      if (_pendingDraft != null && _pendingDraft!.id != id) {
        _pendingDraft = null;
      }
      if (_editDraft != null && _editDraft!.id != id) {
        _editDraft = null;
      }
      _editingId = id;
    });
  }

  @override
  void initState() {
    super.initState();
    final List<StoreBannerModel>? seeded = widget.seedBanners;
    if (seeded != null) {
      _banners = List<StoreBannerModel>.from(seeded);
      _loaded = true;
      _editingId = _banners.isEmpty ? null : _banners.first.id;
      return;
    }
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    final Map<String, dynamic>? shop = await ShopService.instance.getShop(
      widget.shopId,
    );
    if (!mounted) {
      return;
    }
    final List<StoreBannerModel> banners = HomeBannerService.instance
        .parseBanners(shop?['banners']);
    final bool keepSelection = banners.any(
      (StoreBannerModel banner) => banner.id == _editingId,
    );
    setState(() {
      _banners = banners;
      _theme = HomeBannerService.instance.themeFromShop(shop);
      _loaded = true;
      _editingId = banners.isEmpty
          ? null
          : (keepSelection ? _editingId : banners.first.id);
    });
  }

  Future<void> _persist(List<StoreBannerModel> banners) {
    return HomeBannerService.instance.saveBanners(
      shopId: widget.shopId,
      banners: banners,
    );
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addBanner() async {
    if (_banners.length >= HomeBannerService.maxCount) {
      _toast('最多只能 5 張海報');
      return;
    }
    if (_pendingDraft != null) {
      setState(() => _editingId = _pendingDraft!.id);
      if (MediaQuery.sizeOf(context).width < 1100) {
        await _openMobileEditor(_pendingDraft!);
      }
      return;
    }
    final StoreBannerModel created = StoreBannerModel(
      id: 'home_${DateTime.now().millisecondsSinceEpoch}',
      enabled: true,
      sortOrder: _banners.length,
      actionType: HomeBannerActionTypes.none,
      createdAt: DateTime.now(),
    );
    setState(() {
      _pendingDraft = created;
      _editingId = created.id;
    });
    if (MediaQuery.sizeOf(context).width < 1100) {
      await _openMobileEditor(created);
    }
  }

  Future<void> _openMobileEditor(StoreBannerModel banner) async {
    final StoreBannerModel snapshot = banner;
    final String? result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => _HomeBannerMobileEditor(
          shopId: widget.shopId,
          banner: banner,
          banners: List<StoreBannerModel>.from(_banners),
          theme: _theme,
          onDraft: _onDraft,
          persist: _persist,
          onPublished: (List<StoreBannerModel> banners) {
            if (!mounted) {
              return;
            }
            setState(() {
              _banners = banners;
              _editDraft = null;
              if (_pendingDraft != null &&
                  banners.any(
                    (StoreBannerModel item) => item.id == _pendingDraft!.id,
                  )) {
                _pendingDraft = null;
              }
            });
          },
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (result == 'published') {
      _pendingDraft = null;
      _toast('海報已發布，前台將使用固定成品圖');
      return;
    }
    if (result == 'deleted') {
      if (_pendingDraft?.id == snapshot.id) {
        setState(() {
          _pendingDraft = null;
          _editingId = _banners.isEmpty ? null : _banners.first.id;
        });
      }
      return;
    }
    setState(() {
      if (_pendingDraft?.id == snapshot.id) {
        _pendingDraft = null;
        _editingId = _banners.isEmpty ? null : _banners.first.id;
        return;
      }
      if (_editDraft?.id == snapshot.id) {
        _editDraft = null;
      }
    });
  }

  void _onDraft(StoreBannerModel draft) {
    if (!mounted) {
      return;
    }
    if (_pendingDraft?.id == draft.id) {
      setState(() => _pendingDraft = draft);
      return;
    }
    setState(() => _editDraft = draft);
  }

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      await _editor.publish();
      if (!mounted) {
        return;
      }
      _toast('海報已發布，前台將使用固定成品圖');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteEditing() async {
    final StoreBannerModel? banner = _editing;
    if (banner == null) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('刪除海報'),
          content: const Text('確定刪除此活動海報？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    if (_pendingDraft?.id == banner.id) {
      setState(() {
        _pendingDraft = null;
        _editingId = _banners.isEmpty ? null : _banners.first.id;
      });
      return;
    }
    final List<HomeBannerStoredImage> images = _editor.detachStoredImages();
    for (final HomeBannerStoredImage image in images) {
      _removedImages.retireSaved(image);
    }
    final int removedIndex = _banners.indexWhere(
      (StoreBannerModel item) => item.id == banner.id,
    );
    final List<StoreBannerModel> next = _banners
        .where((StoreBannerModel item) => item.id != banner.id)
        .toList();
    final String? nextId;
    if (next.isEmpty) {
      nextId = null;
    } else {
      final int index = removedIndex < 0
          ? 0
          : removedIndex >= next.length
          ? next.length - 1
          : removedIndex;
      nextId = next[index].id;
    }
    setState(() {
      _banners = next;
      _editingId = nextId;
    });
    try {
      await _persist(next);
      final List<HomeBannerStoredImage> doomed = _removedImages.commitSave();
      for (final HomeBannerStoredImage image in doomed) {
        await HomeBannerService.instance.deleteBannerImage(
          shopId: widget.shopId,
          imageUrl: image.url,
          imageStoragePath: image.path,
        );
      }
    } catch (error) {
      _removedImages.retireAfterSave.clear();
      _toast('刪除失敗，已發布圖片未刪除：$error');
      await _loadBanners();
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex--;
      }
      final StoreBannerModel item = _banners.removeAt(oldIndex);
      _banners.insert(newIndex, item);
      for (int i = 0; i < _banners.length; i++) {
        _banners[i] = _banners[i].copyWith(sortOrder: i);
      }
    });
    _persist(_banners);
  }

  Future<void> _toggle(StoreBannerModel banner, bool enabled) async {
    final int index = _banners.indexWhere(
      (StoreBannerModel item) => item.id == banner.id,
    );
    if (index < 0) {
      return;
    }
    setState(() {
      _banners[index] = banner.copyWith(enabled: enabled);
    });
    if (banner.hasImage || banner.hasPublishedPoster) {
      await _persist(_banners);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F0),
      appBar: AppBar(
        title: const Text('活動海報管理'),
        actions: <Widget>[
          if (_loaded && MediaQuery.sizeOf(context).width < 600)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: _countChip(
                  '${_banners.length} / ${HomeBannerService.maxCount} 張',
                ),
              ),
            ),
          if (_editingId != null && MediaQuery.sizeOf(context).width >= 1100)
            TextButton(
              onPressed: _busy ? null : _deleteEditing,
              child: const Text('刪除'),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth >= 1350) {
                  return _desktopTriple(constraints.maxWidth);
                }
                if (constraints.maxWidth >= 1100) {
                  return _desktopSplit();
                }
                if (constraints.maxWidth < 600) {
                  return _mobileManageList();
                }
                return _bannerList(mobile: true);
              },
            ),
    );
  }

  Widget _desktopTriple(double width) {
    final double left = (width * 0.36)
        .clamp(460.0, width - 320 - 482)
        .toDouble();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(width: left, child: _homepagePreview()),
        const VerticalDivider(width: 1),
        SizedBox(width: 320, child: _posterList(phone: false)),
        const VerticalDivider(width: 1),
        Expanded(child: _editorPane()),
      ],
    );
  }

  Widget _desktopSplit() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(flex: 42, child: _homepagePreview()),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 58,
          child: Column(
            children: <Widget>[
              SizedBox(height: 248, child: _posterList(phone: false)),
              const Divider(height: 1),
              Expanded(child: _editorPane()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _editorPane() {
    final StoreBannerModel? banner = _editing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (banner != null) _editingHeader(banner),
        Expanded(child: _editorOrHint()),
        _publishBar(),
      ],
    );
  }

  Widget _editingHeader(StoreBannerModel banner) {
    final int index = _banners.indexWhere(
      (StoreBannerModel item) => item.id == banner.id,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '正在編輯：${_cardTitle(banner, index < 0 ? 0 : index)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          _statusBadge(banner),
        ],
      ),
    );
  }

  Widget _countChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEAE4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B635C),
          height: 1.1,
        ),
      ),
    );
  }

  Widget _mobileManageList() {
    return _posterList(phone: true);
  }

  Widget _posterList({required bool phone}) {
    final int count = _banners.length;
    final bool canReorder = count >= 2;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double side = phone ? 16 : 12;
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.fromLTRB(side, phone ? 8 : 12, side, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text(
                      '已建立的海報',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$count / ${HomeBannerService.maxCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                if (canReorder)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      '長按拖曳可調整順序',
                      style: TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (count > 0)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: side),
            sliver: SliverReorderableList(
              itemCount: count,
              onReorder: _onReorder,
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) {
                    return Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(12),
                      child: child,
                    );
                  },
              itemBuilder: (BuildContext context, int index) {
                final StoreBannerModel banner = _banners[index];
                return Padding(
                  key: ValueKey<String>(banner.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _posterCard(
                    banner: banner,
                    index: index,
                    canReorder: canReorder,
                    phone: phone,
                  ),
                );
              },
            ),
          ),
        if (count < HomeBannerService.maxCount)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(side, 0, side, 0),
            sliver: SliverToBoxAdapter(child: _addPosterCard()),
          ),
        SliverToBoxAdapter(child: SizedBox(height: 16 + bottomInset)),
      ],
    );
  }

  Widget _addPosterCard() {
    final int remain = HomeBannerService.maxCount - _banners.length;
    return Material(
      key: const Key('home-banner-add-card'),
      color: const Color(0xFFF3EFEA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _busy ? null : _addBanner,
        child: CustomPaint(
          painter: const _DashedBorderPainter(),
          child: SizedBox(
            height: 88,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 22,
                  color: Color(0xFF6B635C),
                ),
                const SizedBox(height: 4),
                const Text(
                  '新增活動海報',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '還可新增 $remain 張',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _posterCard({
    required StoreBannerModel banner,
    required int index,
    required bool canReorder,
    required bool phone,
  }) {
    final bool selected = !phone && banner.id == _editingId;
    final double height = phone ? 112 : 88;
    final double thumbWidth = phone ? 132 : 96;
    final double thumbHeight = phone ? 74 : 54;
    final Color borderColor = selected
        ? _theme.primaryColor
        : const Color(0xFFE7E1DA);
    return Material(
      color: selected
          ? _theme.primaryColor.withValues(alpha: 0.08)
          : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: selected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        key: ValueKey<String>('home-banner-card-${banner.id}'),
        height: height,
        child: Row(
          children: <Widget>[
            if (canReorder)
              ReorderableDragStartListener(
                index: index,
                child: const SizedBox(
                  width: 28,
                  child: Icon(
                    Icons.drag_handle,
                    size: 18,
                    color: Color(0xFF8A8178),
                  ),
                ),
              ),
            Expanded(
              child: InkWell(
                onTap: () {
                  _selectPublished(banner.id);
                  if (phone) {
                    _openMobileEditor(banner);
                  }
                },
                child: Padding(
                  padding: EdgeInsets.fromLTRB(canReorder ? 4 : 12, 0, 4, 0),
                  child: Row(
                    children: <Widget>[
                      _posterThumb(
                        banner,
                        width: thumbWidth,
                        height: thumbHeight,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _cardTitle(banner, index),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: phone ? 16 : 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _statusBadge(banner),
                            if (phone) ...<Widget>[
                              const SizedBox(height: 4),
                              const Text(
                                '點選可編輯海報內容',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (phone)
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Color(0xFF8A8178),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 46,
              child: FittedBox(
                child: Switch(
                  value: banner.enabled,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (bool value) => _toggle(banner, value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _cardTitle(StoreBannerModel banner, int index) {
    final String named = banner.title.trim();
    if (named.isNotEmpty) {
      return named;
    }
    final String listed = banner.listTitle.trim();
    if (listed.isNotEmpty) {
      return listed;
    }
    return '海報 ${index + 1}';
  }

  Widget _statusBadge(StoreBannerModel banner) {
    final String label;
    final Color background;
    final Color foreground;
    if (!banner.enabled) {
      label = '已停用';
      background = const Color(0xFFE7E5E4);
      foreground = const Color(0xFF57534E);
    } else if (banner.hasPublishedPoster) {
      label = '已發布';
      background = const Color(0xFFDCF5E4);
      foreground = const Color(0xFF157A3A);
    } else {
      label = '草稿';
      background = const Color(0xFFFFF1E0);
      foreground = const Color(0xFFB86E00);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _posterThumb(
    StoreBannerModel banner, {
    required double width,
    required double height,
  }) {
    final String url = banner.frontImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: const Color(0xFFE7E1DA),
          child: url.isEmpty
              ? const Icon(Icons.image_outlined, size: 18)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image_outlined, size: 18),
                ),
        ),
      ),
    );
  }

  Widget _homepagePreview() {
    final double frameWidth = switch (_previewWidth) {
      _HomePreviewWidth.phone => 390,
      _HomePreviewWidth.tablet => 768,
      _HomePreviewWidth.desktop => 1200,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: const Text('手機'),
                selected: _previewWidth == _HomePreviewWidth.phone,
                onSelected: (_) =>
                    setState(() => _previewWidth = _HomePreviewWidth.phone),
              ),
              ChoiceChip(
                label: const Text('平板'),
                selected: _previewWidth == _HomePreviewWidth.tablet,
                onSelected: (_) =>
                    setState(() => _previewWidth = _HomePreviewWidth.tablet),
              ),
              ChoiceChip(
                label: const Text('電腦'),
                selected: _previewWidth == _HomePreviewWidth.desktop,
                onSelected: (_) =>
                    setState(() => _previewWidth = _HomePreviewWidth.desktop),
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.omitLivePreview
              ? const SizedBox.expand()
              : ModernHomeEditorPreview(
                  shopId: widget.shopId,
                  showPhoneChrome: false,
                  frameWidth: frameWidth,
                  draftHomeBanners: _previewBanners,
                  initialPreviewBannerId: _editingId,
                  previewImageBytes: _editor.localImageBytes,
                  previewSelectedTextId: _editor.selectedTextId,
                  previewCtaSelected: _editor.ctaFocused,
                  onPreviewBannerChanged: (StoreBannerModel draft) {
                    _editor.applyExternalDraft(draft);
                    _onDraft(draft);
                  },
                  onPreviewTextSelected: (String? id) {
                    _editor.focusText(id);
                  },
                  onPreviewCtaSelected: _editor.focusCta,
                ),
        ),
      ],
    );
  }

  Widget _bannerList({required bool mobile}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      children: <Widget>[
        if (_banners.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('尚未新增海報'),
          )
        else
          ReorderableListView(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: _onReorder,
            children: List<Widget>.generate(_banners.length, (int index) {
              final StoreBannerModel banner = _banners[index];
              final String title = banner.listTitle.trim().isEmpty
                  ? '海報 ${index + 1}'
                  : banner.listTitle.trim();
              return ListTile(
                key: ValueKey<String>(banner.id),
                selected: !mobile && banner.id == _editingId,
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                    const SizedBox(width: 8),
                    _thumb(banner),
                  ],
                ),
                title: Text(title),
                subtitle: Text(banner.enabled ? '啟用' : '停用'),
                trailing: mobile
                    ? const Icon(Icons.chevron_right)
                    : Switch(
                        value: banner.enabled,
                        onChanged: (bool value) => _toggle(banner, value),
                      ),
                onTap: () {
                  _selectPublished(banner.id);
                  if (mobile) {
                    _openMobileEditor(banner);
                  }
                },
              );
            }),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _addBanner,
          icon: const Icon(Icons.add),
          label: const Text('新增海報'),
        ),
        if (!mobile && _editingId != null) ...<Widget>[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy ? null : _deleteEditing,
              child: const Text('刪除海報'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _thumb(StoreBannerModel banner) {
    final String url = banner.frontImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 56,
        height: 32,
        child: ColoredBox(
          color: const Color(0xFFE7E1DA),
          child: url.isEmpty
              ? const Icon(Icons.image_outlined, size: 16)
              : Image.network(url, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _editorOrHint() {
    final StoreBannerModel? banner = _editing;
    if (banner == null) {
      return const Center(child: Text('尚未新增海報'));
    }
    return ShopStoreBannerEditorPage(
      key: ValueKey<String>('home-editor-${banner.id}'),
      shopId: widget.shopId,
      banner: banner,
      existingBanners: _banners,
      isNew: !banner.hasPublishedPoster && !banner.hasImage,
      shopTheme: _theme,
      scope: PetNestBannerScope.home,
      embedded: true,
      showInlinePreview: false,
      controller: _editor,
      persistBanners: _persist,
      onDraftChanged: _onDraft,
      onLocalImageBytes: (_) {
        if (mounted) {
          setState(() {});
        }
      },
      onPublished: (List<StoreBannerModel> banners) {
        if (!mounted) {
          return;
        }
        setState(() {
          _banners = banners;
          _editDraft = null;
          if (_pendingDraft != null &&
              banners.any(
                (StoreBannerModel item) => item.id == _pendingDraft!.id,
              )) {
            _pendingDraft = null;
          }
        });
      },
    );
  }

  Widget _publishBar() {
    if (_editingId == null) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: _busy ? null : _publish,
          child: Text(_busy ? '發布中…' : '發布海報'),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(12),
        ).deflate(1),
      );
    final Paint paint = Paint()
      ..color = const Color(0xFFC8BFB6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const double dash = 5;
    const double gap = 4;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = (distance + dash).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}

class _HomeBannerMobileEditor extends StatefulWidget {
  const _HomeBannerMobileEditor({
    required this.shopId,
    required this.banner,
    required this.banners,
    required this.theme,
    required this.onDraft,
    required this.persist,
    required this.onPublished,
  });

  final String shopId;
  final StoreBannerModel banner;
  final List<StoreBannerModel> banners;
  final HomeThemeModel theme;
  final ValueChanged<StoreBannerModel> onDraft;
  final Future<void> Function(List<StoreBannerModel> banners) persist;
  final ValueChanged<List<StoreBannerModel>> onPublished;

  @override
  State<_HomeBannerMobileEditor> createState() =>
      _HomeBannerMobileEditorState();
}

class _HomeBannerMobileEditorState extends State<_HomeBannerMobileEditor> {
  final StoreBannerEditorController _editor = StoreBannerEditorController();
  late StoreBannerModel _draft = widget.banner;
  bool _busy = false;

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      await _editor.publish();
      if (!mounted || !_editor.saved) {
        return;
      }
      Navigator.of(context).pop('published');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openFullPreview() async {
    final StoreBannerModel banner = _editor.draft ?? _draft;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(title: const Text('查看海報成品')),
            body: Center(
              child: AspectRatio(
                aspectRatio: HomeBannerDisplay.aspectRatio,
                child: StoreBannerView(
                  banner: banner,
                  theme: widget.theme,
                  scope: PetNestBannerScope.home,
                  composeLive: true,
                  borderRadius: 0,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final StoreBannerModel banner = _editor.draft ?? _draft;
    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯活動海報'),
        actions: <Widget>[
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final bool? confirmed = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('刪除海報'),
                          content: const Text('確定刪除此活動海報？'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('刪除'),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirmed != true || !context.mounted) {
                      return;
                    }
                    if (!widget.banner.hasPublishedPoster) {
                      Navigator.of(context).pop('deleted');
                      return;
                    }
                    final List<HomeBannerStoredImage> images = _editor
                        .detachStoredImages();
                    final List<StoreBannerModel> next = widget.banners
                        .where(
                          (StoreBannerModel item) =>
                              item.id != widget.banner.id,
                        )
                        .toList();
                    try {
                      await widget.persist(next);
                      for (final HomeBannerStoredImage image in images) {
                        await HomeBannerService.instance.deleteBannerImage(
                          shopId: widget.shopId,
                          imageUrl: image.url,
                          imageStoragePath: image.path,
                        );
                      }
                      widget.onPublished(next);
                      if (context.mounted) {
                        Navigator.of(context).pop('deleted');
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('刪除失敗，已發布圖片未刪除：$error')),
                        );
                      }
                    }
                  },
            child: const Text('刪除'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double rawHeight =
                        constraints.maxWidth / HomeBannerDisplay.aspectRatio;
                    final double height = rawHeight > 210 ? 210 : rawHeight;
                    return Center(
                      child: SizedBox(
                        width: height * HomeBannerDisplay.aspectRatio,
                        height: height,
                        child: StoreBannerView(
                          banner: banner,
                          theme: widget.theme,
                          scope: PetNestBannerScope.home,
                          composeLive: true,
                          borderRadius: 12,
                          interactMode: StoreBannerInteractMode.text,
                          previewImageBytes: _editor.localImageBytes,
                          selectedTextId: _editor.selectedTextId,
                          ctaSelected: _editor.ctaFocused,
                          onChanged: (StoreBannerModel value) {
                            _editor.applyExternalDraft(value);
                            setState(() => _draft = value);
                          },
                          onTextSelected: (String? id) {
                            _editor.focusText(id);
                          },
                          onCtaSelected: _editor.focusCta,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  banner.hasPublishedPoster ? '已發布成品' : '尚未發布',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('啟用'),
                  value: banner.enabled,
                  onChanged: (bool value) {
                    _editor.updateEnabled(value);
                    setState(() => _draft = _draft.copyWith(enabled: value));
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ShopStoreBannerEditorPage(
              key: ValueKey<String>('mobile-editor-${widget.banner.id}'),
              shopId: widget.shopId,
              banner: widget.banner,
              existingBanners: widget.banners,
              isNew:
                  !widget.banner.hasPublishedPoster && !widget.banner.hasImage,
              shopTheme: widget.theme,
              scope: PetNestBannerScope.home,
              embedded: true,
              showInlinePreview: false,
              controller: _editor,
              persistBanners: widget.persist,
              onDraftChanged: (StoreBannerModel draft) {
                widget.onDraft(draft);
                setState(() => _draft = draft);
              },
              onPublished: widget.onPublished,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _openFullPreview,
                  child: const Text('預覽海報'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _publish,
                  child: Text(_busy ? '發布中…' : '發布海報'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
