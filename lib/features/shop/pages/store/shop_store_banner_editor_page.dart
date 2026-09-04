// lib/features/shop/pages/store/shop_store_banner_editor_page.dart
// 🛒 活動海報編輯器：首頁 / 商城共用 StoreBannerView。
// scope 決定儲存位置與連結選項，不要複製第二套 Editor。

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/store_appearance_model.dart';
import 'package:petnest_saas/core/models/store_banner_templates.dart';
import 'package:petnest_saas/core/models/store_category_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/services/store_category_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_promotion_service.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_pick_flow.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_spec_hint.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_color_field.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_view.dart';

class ShopStoreBannerEditorPage extends StatefulWidget {
  const ShopStoreBannerEditorPage({
    super.key,
    required this.shopId,
    required this.banner,
    required this.existingBanners,
    this.isNew = false,
    this.shopTheme = HomeThemeModel.modernDefault,
    this.scope = PetNestBannerScope.store,
    this.persistBanners,
    this.imageFolder,
    this.imageType,
    this.pageTitle,
  });

  final String shopId;
  final StoreBannerModel banner;
  final List<StoreBannerModel> existingBanners;
  final bool isNew;
  final HomeThemeModel shopTheme;
  final PetNestBannerScope scope;
  final Future<void> Function(List<StoreBannerModel> banners)? persistBanners;
  final String? imageFolder;
  final String? imageType;
  final String? pageTitle;

  bool get isHomeScope => scope == PetNestBannerScope.home;

  @override
  State<ShopStoreBannerEditorPage> createState() =>
      _ShopStoreBannerEditorPageState();
}

typedef PetNestBannerEditorPage = ShopStoreBannerEditorPage;

class _ShopStoreBannerEditorPageState extends State<ShopStoreBannerEditorPage>
    with SingleTickerProviderStateMixin {
  late StoreBannerModel _draft;
  late final TabController _tabs;
  late final TextEditingController _text;
  late final TextEditingController _cta;
  String? _selectedTextId;
  String _pendingUrl = '';
  String _pendingPath = '';
  String _retiredUrl = '';
  String _retiredPath = '';
  bool _saving = false;
  bool _saved = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.banner.hydrateLegacyForEditor();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() {});
      }
    });
    _text = TextEditingController();
    _cta = TextEditingController(text: _draft.ctaText);
    if (_draft.textElements.isNotEmpty) {
      _selectText(_draft.textElements.first.id, updateController: true);
    }
    if (widget.isNew) {
      _pendingUrl = _draft.imageUrl;
      _pendingPath = _draft.imageStoragePath;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _text.dispose();
    _cta.dispose();
    if (!_saved) {
      _cleanupPending();
    }
    super.dispose();
  }

  StoreBannerInteractMode get _interactMode {
    switch (_tabs.index) {
      case 0:
        return StoreBannerInteractMode.image;
      case 2:
        return StoreBannerInteractMode.text;
      case 3:
        return StoreBannerInteractMode.cta;
      default:
        return StoreBannerInteractMode.none;
    }
  }

  StoreBannerTextElement? get _selected {
    if (_selectedTextId == null) {
      return null;
    }
    for (final StoreBannerTextElement item in _draft.resolvedTextElements) {
      if (item.id == _selectedTextId) {
        return item;
      }
    }
    return null;
  }

  void _selectText(String? id, {bool updateController = true}) {
    _selectedTextId = id;
    if (updateController) {
      _text.text = _selected?.text ?? '';
    }
  }

  void _replaceText(StoreBannerTextElement next) {
    final List<StoreBannerTextElement> items = _draft.resolvedTextElements
        .map((StoreBannerTextElement item) => item.id == next.id ? next : item)
        .toList();
    setState(() => _draft = _draft.copyWith(textElements: items));
  }

  Future<void> _cleanupPending() async {
    if (_pendingPath.isEmpty && _pendingUrl.isEmpty) {
      return;
    }
    await InventoryImageService.instance.tryDeleteImage(
      imageUrl: _pendingUrl,
      imageStoragePath: _pendingPath,
    );
  }

  Future<void> _pickImage() async {
    try {
      setState(() => _uploading = true);
      final FixedImageSpec spec = widget.isHomeScope
          ? FixedImageSpec.homeBanner
          : FixedImageSpec.storeBanner;
      final String itemId =
          '${_draft.id}/p_${DateTime.now().millisecondsSinceEpoch}';
      final result = await FixedImagePickFlow.pickCropAndUpload(
        context: context,
        spec: spec,
        title: widget.isHomeScope ? '裁切首頁活動海報' : '裁切商城活動海報',
        shopId: widget.shopId,
        itemId: itemId,
        folder:
            widget.imageFolder ??
            (widget.isHomeScope
                ? HomeBannerService.imageFolder
                : StoreConstants.bannerImageFolder),
        imageType:
            widget.imageType ??
            (widget.isHomeScope ? 'home_banner' : 'store_banner'),
        idMetadataKey: 'bannerId',
      );
      if (result == null) {
        return;
      }
      if (_pendingPath.isNotEmpty || _pendingUrl.isNotEmpty) {
        await InventoryImageService.instance.tryDeleteImage(
          imageUrl: _pendingUrl,
          imageStoragePath: _pendingPath,
        );
      } else if (_draft.hasImage) {
        _retiredUrl = _draft.imageUrl;
        _retiredPath = _draft.imageStoragePath;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingUrl = result.imageUrl;
        _pendingPath = result.imageStoragePath;
        _draft = _draft.copyWith(
          imageUrl: result.imageUrl,
          imageStoragePath: result.imageStoragePath,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(StoreBannerModel.imageUserMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _removeImage() async {
    if (_pendingPath.isNotEmpty || _pendingUrl.isNotEmpty) {
      await InventoryImageService.instance.tryDeleteImage(
        imageUrl: _pendingUrl,
        imageStoragePath: _pendingPath,
      );
      _pendingUrl = '';
      _pendingPath = '';
    } else if (_draft.hasImage) {
      _retiredUrl = _draft.imageUrl;
      _retiredPath = _draft.imageStoragePath;
    }
    setState(() {
      _draft = _draft.copyWith(imageUrl: '', imageStoragePath: '');
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    final DateTime now = DateTime.now();
    final StoreBannerModel next = _draft.copyWith(
      ctaText: _cta.text,
      createdAt: _draft.createdAt ?? now,
      updatedAt: now,
    );
    if (!next.hasImage) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先上傳海報圖片')));
      return;
    }
    final List<StoreBannerModel> all = List<StoreBannerModel>.from(
      widget.existingBanners,
    );
    final int index = all.indexWhere(
      (StoreBannerModel item) => item.id == next.id,
    );
    if (index >= 0) {
      all[index] = next;
    } else {
      all.add(next);
    }
    for (int i = 0; i < all.length; i++) {
      all[i] = all[i].copyWith(sortOrder: i);
    }
    try {
      final Future<void> Function(List<StoreBannerModel> banners) persist =
          widget.persistBanners ??
          (List<StoreBannerModel> banners) {
            return StoreSettingsService.instance.saveBanners(
              shopId: widget.shopId,
              banners: banners,
            );
          };
      await persist(all);
      if (_retiredPath.isNotEmpty || _retiredUrl.isNotEmpty) {
        if (widget.isHomeScope) {
          await HomeBannerService.instance.deleteBannerImage(
            shopId: widget.shopId,
            imageUrl: _retiredUrl,
            imageStoragePath: _retiredPath,
          );
        } else {
          await InventoryImageService.instance.tryDeleteImage(
            imageUrl: _retiredUrl,
            imageStoragePath: _retiredPath,
          );
        }
      }
      _saved = true;
      if (!mounted) {
        return;
      }
      Navigator.pop(context, all);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _applyTemplate(String template) async {
    if (_draft.hasLayoutToPreserve) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('套用快速版型？'),
            content: const Text('套用後會重新排列目前的文字與按鈕位置，是否繼續？'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('套用版型'),
              ),
            ],
          );
        },
      );
      if (!mounted || confirmed != true) {
        return;
      }
    }
    final String imageUrl = _draft.imageUrl;
    final String imagePath = _draft.imageStoragePath;
    setState(() {
      _draft = StoreBannerTemplates.apply(
        _draft,
        template,
      ).copyWith(imageUrl: imageUrl, imageStoragePath: imagePath);
      _cta.text = _draft.ctaText;
      if (_draft.textElements.isNotEmpty) {
        _selectText(_draft.textElements.first.id, updateController: true);
      } else {
        _selectText(null, updateController: true);
      }
    });
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已套用${StoreBannerTemplates.label(template)}')),
    );
  }

  void _addText() {
    if (_draft.resolvedTextElements.length >=
        StoreBannerModel.maxTextElements) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('最多 12 個文字元件')));
      return;
    }
    final int order = _draft.resolvedTextElements.length;
    final StoreBannerTextElement created = StoreBannerTextElement.create(
      id: 'te_${DateTime.now().millisecondsSinceEpoch}',
      text: '新文字',
      positionX: 0.08,
      positionY: (0.16 + order * 0.12).clamp(0.08, 0.72),
      fontSizePreset: StoreBannerFontSizes.title,
      fontSize: StoreBannerFontSizes.basePx(StoreBannerFontSizes.title),
      fontWeightPreset: StoreBannerFontWeights.bold,
      textColor: StoreBannerCommonColors.black,
      sortOrder: order,
    );
    setState(() {
      _draft = _draft.copyWith(
        textElements: <StoreBannerTextElement>[
          ..._draft.resolvedTextElements,
          created,
        ],
      );
      _selectText(created.id, updateController: true);
    });
    _tabs.animateTo(2);
  }

  void _deleteSelected() {
    final String? id = _selectedTextId;
    if (id == null) {
      return;
    }
    final List<StoreBannerTextElement> next = _draft.resolvedTextElements
        .where((StoreBannerTextElement item) => item.id != id)
        .toList();
    setState(() {
      _draft = _draft.copyWith(textElements: next);
      _selectText(next.isEmpty ? null : next.last.id, updateController: true);
    });
  }

  void _shiftLayer(int delta) {
    final StoreBannerTextElement? current = _selected;
    if (current == null) {
      return;
    }
    final List<StoreBannerTextElement> items =
        List<StoreBannerTextElement>.from(_draft.resolvedTextElements);
    final int index = items.indexWhere(
      (StoreBannerTextElement item) => item.id == current.id,
    );
    final int next = index + delta;
    if (index < 0 || next < 0 || next >= items.length) {
      return;
    }
    final StoreBannerTextElement other = items[next];
    items[index] = current.copyWith(sortOrder: other.sortOrder);
    items[next] = other.copyWith(sortOrder: current.sortOrder);
    setState(() => _draft = _draft.copyWith(textElements: items));
  }

  @override
  Widget build(BuildContext context) {
    final String title =
        widget.pageTitle ?? (widget.isHomeScope ? '編輯首頁海報' : '編輯商城海報');
    if (widget.isHomeScope) {
      return StreamBuilder<Map<String, dynamic>?>(
        stream: ShopService.instance.streamShop(widget.shopId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<Map<String, dynamic>?> snapshot,
            ) {
              return _buildScaffold(
                title: title,
                theme: widget.shopTheme,
                homeCanvas: ModernBannerFrameSetting.fromShop(snapshot.data),
              );
            },
      );
    }
    return StreamBuilder<Map<String, dynamic>>(
      stream: StoreSettingsService.instance.streamSettings(widget.shopId),
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
            final StoreHomeDisplaySettings home =
                StoreHomeDisplaySettings.fromMap(
                  snapshot.data ?? const <String, dynamic>{},
                );
            final HomeThemeModel theme = home.resolveTheme(widget.shopTheme);
            return _buildScaffold(title: title, theme: theme);
          },
    );
  }

  Widget _buildScaffold({
    required String title,
    required HomeThemeModel theme,
    ModernBannerFrameSetting? homeCanvas,
  }) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 900;
          final Widget preview = _PreviewBlock(
            banner: _draft.copyWith(ctaText: _cta.text),
            theme: theme,
            scope: widget.scope,
            canvasAspectRatio: homeCanvas?.aspectRatio,
            interactMode: _interactMode,
            selectedTextId: _interactMode == StoreBannerInteractMode.text
                ? _selectedTextId
                : null,
            onChanged: (StoreBannerModel value) {
              setState(() => _draft = value);
            },
            onTextSelected: (String? id) {
              setState(() => _selectText(id, updateController: true));
            },
            onTemplate: _applyTemplate,
          );
          final Widget editor = _EditorColumn(
            tabs: _tabs,
            draft: _draft,
            theme: theme,
            shopId: widget.shopId,
            scope: widget.scope,
            uploading: _uploading,
            textController: _text,
            ctaController: _cta,
            selected: _selected,
            onDraft: (StoreBannerModel value) {
              setState(() => _draft = value);
            },
            onPickImage: _pickImage,
            onRemoveImage: _removeImage,
            onAddText: _addText,
            onSelectText: (String id) {
              setState(() => _selectText(id, updateController: true));
            },
            onReplaceText: _replaceText,
            onDeleteText: _deleteSelected,
            onShiftLayer: _shiftLayer,
            onCtaChanged: () {
              setState(() {
                _draft = _draft.copyWith(ctaText: _cta.text);
              });
            },
          );
          if (wide) {
            return Row(
              children: <Widget>[
                Expanded(flex: 5, child: preview),
                const VerticalDivider(width: 1),
                Expanded(flex: 4, child: editor),
              ],
            );
          }
          return Column(
            children: <Widget>[
              preview,
              const Divider(height: 1),
              Expanded(child: editor),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '儲存中…' : '儲存海報'),
          ),
        ),
      ),
    );
  }
}

class _PreviewBlock extends StatelessWidget {
  const _PreviewBlock({
    required this.banner,
    required this.theme,
    required this.scope,
    this.canvasAspectRatio,
    required this.interactMode,
    required this.selectedTextId,
    required this.onChanged,
    required this.onTextSelected,
    required this.onTemplate,
  });

  final StoreBannerModel banner;
  final HomeThemeModel theme;
  final PetNestBannerScope scope;
  final double? canvasAspectRatio;
  final StoreBannerInteractMode interactMode;
  final String? selectedTextId;
  final ValueChanged<StoreBannerModel> onChanged;
  final ValueChanged<String?> onTextSelected;
  final ValueChanged<String> onTemplate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (canvasAspectRatio == null)
              StoreBannerView(
                banner: banner,
                theme: theme,
                scope: scope,
                interactMode: interactMode,
                selectedTextId: selectedTextId,
                onChanged: onChanged,
                onTextSelected: onTextSelected,
              )
            else
              AspectRatio(
                aspectRatio: canvasAspectRatio!,
                child: StoreBannerView(
                  banner: banner,
                  theme: theme,
                  scope: scope,
                  interactMode: interactMode,
                  selectedTextId: selectedTextId,
                  onChanged: onChanged,
                  onTextSelected: onTextSelected,
                ),
              ),
            const SizedBox(height: 8),
            Text(switch (interactMode) {
              StoreBannerInteractMode.image => '在預覽中拖曳圖片，調整實際顯示範圍',
              StoreBannerInteractMode.cta => '拖曳按鈕調整位置',
              StoreBannerInteractMode.text => '直接拖曳海報文字調整位置',
              StoreBannerInteractMode.none => '切到「圖片」分頁可拖曳調整顯示位置',
            }, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            const Text('快速版型', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: StoreBannerTemplates.all.map((String value) {
                final String label =
                    value == StoreBannerTemplates.promo &&
                        scope == PetNestBannerScope.home
                    ? '活動宣傳'
                    : StoreBannerTemplates.label(value);
                return ActionChip(
                  label: Text(label),
                  onPressed: () => onTemplate(value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorColumn extends StatelessWidget {
  const _EditorColumn({
    required this.tabs,
    required this.draft,
    required this.theme,
    required this.shopId,
    required this.scope,
    required this.uploading,
    required this.textController,
    required this.ctaController,
    required this.selected,
    required this.onDraft,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onAddText,
    required this.onSelectText,
    required this.onReplaceText,
    required this.onDeleteText,
    required this.onShiftLayer,
    required this.onCtaChanged,
  });

  final TabController tabs;
  final StoreBannerModel draft;
  final HomeThemeModel theme;
  final String shopId;
  final PetNestBannerScope scope;
  final bool uploading;
  final TextEditingController textController;
  final TextEditingController ctaController;
  final StoreBannerTextElement? selected;
  final ValueChanged<StoreBannerModel> onDraft;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onAddText;
  final ValueChanged<String> onSelectText;
  final ValueChanged<StoreBannerTextElement> onReplaceText;
  final VoidCallback onDeleteText;
  final ValueChanged<int> onShiftLayer;
  final VoidCallback onCtaChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TabBar(
          controller: tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const <Widget>[
            Tab(text: '圖片'),
            Tab(text: '漸層'),
            Tab(text: '文字'),
            Tab(text: '按鈕'),
            Tab(text: '連結'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: tabs,
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              _ImagePanel(
                draft: draft,
                scope: scope,
                uploading: uploading,
                onDraft: onDraft,
                onPickImage: onPickImage,
                onRemoveImage: onRemoveImage,
              ),
              _GradientPanel(draft: draft, theme: theme, onDraft: onDraft),
              _TextPanel(
                draft: draft,
                theme: theme,
                scope: scope,
                textController: textController,
                selected: selected,
                onAddText: onAddText,
                onSelectText: onSelectText,
                onReplaceText: onReplaceText,
                onDeleteText: onDeleteText,
                onShiftLayer: onShiftLayer,
              ),
              _CtaPanel(
                draft: draft,
                theme: theme,
                ctaController: ctaController,
                onDraft: onDraft,
                onCtaChanged: onCtaChanged,
              ),
              _LinkPanel(
                shopId: shopId,
                scope: scope,
                draft: draft,
                onDraft: onDraft,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImagePanel extends StatelessWidget {
  const _ImagePanel({
    required this.draft,
    required this.scope,
    required this.uploading,
    required this.onDraft,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  final StoreBannerModel draft;
  final PetNestBannerScope scope;
  final bool uploading;
  final ValueChanged<StoreBannerModel> onDraft;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        FixedImageSpecHint(
          spec: scope == PetNestBannerScope.home
              ? FixedImageSpec.homeBanner
              : FixedImageSpec.storeBanner,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            FilledButton.tonal(
              onPressed: uploading ? null : onPickImage,
              child: Text(draft.hasImage ? '更換圖片' : '上傳圖片'),
            ),
            if (draft.hasImage)
              TextButton(
                onPressed: uploading ? null : onRemoveImage,
                child: const Text('移除圖片'),
              ),
          ],
        ),
        if (uploading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 16),
        if (scope == PetNestBannerScope.home) ...<Widget>[
          Text(
            '首頁所有海報的顯示大小請到「前台外觀設定」統一調整。',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
        ] else ...<Widget>[
          const Text('海報尺寸', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _ChipRow(
            values: StoreBannerSizePresets.all,
            selected: draft.sizePreset,
            labelOf: StoreBannerSizePresets.label,
            onSelected: (String value) {
              onDraft(draft.copyWith(sizePreset: value));
            },
          ),
          const SizedBox(height: 16),
        ],
        const Text('圖片縮放', style: TextStyle(fontWeight: FontWeight.w700)),
        const Text(
          '1.0x 為原圖裁切。放大後可拖曳或用下方位置滑桿，決定框內露出的範圍。',
          style: TextStyle(fontSize: 12),
        ),
        Slider(
          min: 1,
          max: 2.5,
          divisions: 15,
          label: '${draft.imageScale.toStringAsFixed(1)}x',
          value: draft.imageScale.clamp(1.0, 2.5),
          onChanged: (double value) {
            onDraft(draft.copyWith(imageScale: value));
          },
        ),
        const SizedBox(height: 8),
        const Text('水平位置', style: TextStyle(fontWeight: FontWeight.w700)),
        const Text('愈左愈露出圖片左側，愈右愈露出右側。', style: TextStyle(fontSize: 12)),
        Slider(
          min: 0,
          max: 1,
          divisions: 20,
          label: draft.imageAlignmentX <= 0.05
              ? '左'
              : draft.imageAlignmentX >= 0.95
              ? '右'
              : '中',
          value: draft.imageAlignmentX.clamp(0.0, 1.0),
          onChanged: (double value) {
            onDraft(draft.copyWith(imageAlignmentX: value));
          },
        ),
        const SizedBox(height: 8),
        const Text('垂直位置', style: TextStyle(fontWeight: FontWeight.w700)),
        const Text('愈上愈露出圖片上方，愈下愈露出下方。', style: TextStyle(fontSize: 12)),
        Slider(
          min: 0,
          max: 1,
          divisions: 20,
          label: draft.imageAlignmentY <= 0.05
              ? '上'
              : draft.imageAlignmentY >= 0.95
              ? '下'
              : '中',
          value: draft.imageAlignmentY.clamp(0.0, 1.0),
          onChanged: (double value) {
            onDraft(draft.copyWith(imageAlignmentY: value));
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () {
              onDraft(
                draft.copyWith(
                  imageScale: 1,
                  imageAlignmentX: 0.5,
                  imageAlignmentY: 0.5,
                ),
              );
            },
            child: const Text('重設圖片位置'),
          ),
        ),
      ],
    );
  }
}

class _GradientPanel extends StatelessWidget {
  const _GradientPanel({
    required this.draft,
    required this.theme,
    required this.onDraft,
  });

  final StoreBannerModel draft;
  final HomeThemeModel theme;
  final ValueChanged<StoreBannerModel> onDraft;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        const Text('方向', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _ChipRow(
          values: StoreBannerOverlayModes.editorModes,
          selected: draft.overlayMode == StoreBannerOverlayModes.custom
              ? StoreBannerOverlayModes.left
              : draft.overlayMode,
          labelOf: StoreBannerOverlayModes.label,
          onSelected: (String value) {
            onDraft(draft.copyWith(overlayMode: value));
          },
        ),
        const SizedBox(height: 16),
        const Text('顏色', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _ChipRow(
          values: StoreBannerOverlayColors.editorModes,
          selected: draft.overlayColorMode,
          labelOf: StoreBannerOverlayColors.label,
          onSelected: (String value) {
            onDraft(draft.copyWith(overlayColorMode: value));
          },
        ),
        if (draft.overlayColorMode ==
            StoreBannerOverlayColors.custom) ...<Widget>[
          const SizedBox(height: 12),
          StoreBannerColorField(
            label: '自訂漸層色',
            argb: draft.overlayCustomColor,
            brandColor: theme.primaryColor,
            onChanged: (int value) {
              onDraft(draft.copyWith(overlayCustomColor: value));
            },
          ),
        ],
        const SizedBox(height: 16),
        const Text('範圍', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _ChipRow(
          values: StoreBannerOverlayExtents.all,
          selected: draft.overlayExtent,
          labelOf: StoreBannerOverlayExtents.label,
          onSelected: (String value) {
            onDraft(draft.copyWith(overlayExtent: value));
          },
        ),
        const SizedBox(height: 16),
        const Text('強度', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _ChipRow(
          values: StoreBannerOverlayStrengths.all,
          selected: draft.overlayStrength,
          labelOf: StoreBannerOverlayStrengths.label,
          onSelected: (String value) {
            onDraft(draft.copyWith(overlayStrength: value));
          },
        ),
      ],
    );
  }
}

class _TextPanel extends StatelessWidget {
  const _TextPanel({
    required this.draft,
    required this.theme,
    required this.scope,
    required this.textController,
    required this.selected,
    required this.onAddText,
    required this.onSelectText,
    required this.onReplaceText,
    required this.onDeleteText,
    required this.onShiftLayer,
  });

  final StoreBannerModel draft;
  final HomeThemeModel theme;
  final PetNestBannerScope scope;
  final TextEditingController textController;
  final StoreBannerTextElement? selected;
  final VoidCallback onAddText;
  final ValueChanged<String> onSelectText;
  final ValueChanged<StoreBannerTextElement> onReplaceText;
  final VoidCallback onDeleteText;
  final ValueChanged<int> onShiftLayer;

  @override
  Widget build(BuildContext context) {
    final List<StoreBannerTextElement> items = draft.resolvedTextElements;
    final StoreBannerTextElement? current = selected;
    final double canvasHeight = StoreBannerSizePresets.heightForWidth(
      draft.sizePreset,
      390,
      scope: scope,
    );
    final double sliderMax = StoreBannerFontSizes.sliderMaxForBanner(
      canvasHeight,
    );
    final int sliderDivisions = math.max(
      1,
      (sliderMax - StoreBannerFontSizes.minPx).round(),
    );
    final bool contrastWarn =
        current != null &&
        StoreBannerContrast.mayBeLow(
          Color(current.textColor),
          current.showsBackground && !draft.showsCta
              ? Color(current.backgroundColor).withValues(
                  alpha: StoreBannerBgOpacities.opacity(
                    current.backgroundOpacityPreset,
                  ),
                )
              : draft.overlayMode == StoreBannerOverlayModes.none
              ? const Color(0xFF888888)
              : draft.overlayColor(theme),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: onAddText,
            icon: const Icon(Icons.add),
            label: const Text('新增文字'),
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty) const Text('尚未新增文字。可先套用快速版型，或按「新增文字」。'),
        ...items.asMap().entries.map((
          MapEntry<int, StoreBannerTextElement> entry,
        ) {
          final StoreBannerTextElement item = entry.value;
          final bool active = current?.id == item.id;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            selected: active,
            title: Text('文字 ${entry.key + 1}'),
            subtitle: Text(
              item.hasText ? item.text : '（空白）',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelectText(item.id),
          );
        }),
        if (current != null) ...<Widget>[
          const Divider(),
          TextField(
            controller: textController,
            maxLength: 48,
            decoration: const InputDecoration(labelText: '文字內容'),
            onChanged: (String value) {
              onReplaceText(current.copyWith(text: value));
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '字體大小',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${current.sliderFontSize.round()} px',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              min: StoreBannerFontSizes.minPx,
              max: sliderMax,
              divisions: sliderDivisions,
              padding: EdgeInsets.zero,
              label: '${current.sliderFontSize.round()} px',
              value: current.sliderFontSize.clamp(
                StoreBannerFontSizes.minPx,
                sliderMax,
              ),
              onChanged: (double value) {
                final double px = StoreBannerFontSizes.clampForBanner(
                  value.roundToDouble(),
                  canvasHeight,
                );
                onReplaceText(
                  current.copyWith(
                    fontSize: px,
                    fontSizePreset: StoreBannerFontSizes.nearestPreset(px),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text('粗細', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _ChipRow(
            values: StoreBannerFontWeights.all,
            selected: current.fontWeightPreset,
            labelOf: StoreBannerFontWeights.label,
            onSelected: (String value) {
              onReplaceText(current.copyWith(fontWeightPreset: value));
            },
          ),
          const SizedBox(height: 12),
          StoreBannerColorField(
            label: '文字顏色',
            argb: current.textColor,
            brandColor: theme.primaryColor,
            onChanged: (int value) {
              onReplaceText(current.copyWith(textColor: value));
            },
          ),
          if (contrastWarn)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '⚠ 目前文字與背景對比可能不足',
                style: TextStyle(color: Color(0xFFB45309)),
              ),
            ),
          const SizedBox(height: 12),
          if (draft.showsCta)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '已啟用 CTA 按鈕時，標題與副標題改以字色、粗細與陰影維持可讀性，不再使用文字背景塊。',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            )
          else ...<Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('文字背景'),
              value: current.backgroundEnabled,
              onChanged: (bool value) {
                onReplaceText(
                  current.copyWith(
                    backgroundEnabled: value,
                    backgroundStyle:
                        value &&
                            current.backgroundStyle ==
                                StoreBannerTextBgStyles.none
                        ? StoreBannerTextBgStyles.capsule
                        : current.backgroundStyle,
                  ),
                );
              },
            ),
            if (current.backgroundEnabled) ...<Widget>[
              _ChipRow(
                values: StoreBannerTextBgStyles.all
                    .where(
                      (String item) => item != StoreBannerTextBgStyles.none,
                    )
                    .toList(),
                selected: current.backgroundStyle,
                labelOf: StoreBannerTextBgStyles.label,
                onSelected: (String value) {
                  onReplaceText(
                    current.copyWith(
                      backgroundStyle: value,
                      backgroundOpacityPreset:
                          value == StoreBannerTextBgStyles.translucent
                          ? StoreBannerBgOpacities.medium
                          : current.backgroundOpacityPreset,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              StoreBannerColorField(
                label: '背景顏色',
                argb: current.backgroundColor,
                brandColor: theme.primaryColor,
                onChanged: (int value) {
                  onReplaceText(current.copyWith(backgroundColor: value));
                },
              ),
              const SizedBox(height: 12),
              const Text(
                '背景透明度',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _ChipRow(
                values: StoreBannerBgOpacities.all,
                selected: current.backgroundOpacityPreset,
                labelOf: StoreBannerBgOpacities.label,
                onSelected: (String value) {
                  onReplaceText(
                    current.copyWith(backgroundOpacityPreset: value),
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text('內距', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _ChipRow(
                values: StoreBannerTextPaddings.all,
                selected: current.paddingPreset,
                labelOf: StoreBannerTextPaddings.label,
                onSelected: (String value) {
                  onReplaceText(current.copyWith(paddingPreset: value));
                },
              ),
            ],
          ],
          const SizedBox(height: 12),
          const Text('文字區寬度', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _ChipRow(
            values: StoreBannerTextWidthPresets.all,
            selected: current.maxWidthPreset,
            labelOf: StoreBannerTextWidthPresets.label,
            onSelected: (String value) {
              onReplaceText(current.copyWith(maxWidthPreset: value));
            },
          ),
          const SizedBox(height: 12),
          const Text('對齊', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _ChipRow(
            values: StoreBannerTextAligns.all,
            selected: current.textAlign,
            labelOf: StoreBannerTextAligns.label,
            onSelected: (String value) {
              onReplaceText(current.copyWith(textAlign: value));
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed: () => onShiftLayer(1),
                child: const Text('上移一層'),
              ),
              OutlinedButton(
                onPressed: () => onShiftLayer(-1),
                child: const Text('下移一層'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onDeleteText, child: const Text('刪除此文字')),
        ],
      ],
    );
  }
}

class _CtaPanel extends StatelessWidget {
  const _CtaPanel({
    required this.draft,
    required this.theme,
    required this.ctaController,
    required this.onDraft,
    required this.onCtaChanged,
  });

  final StoreBannerModel draft;
  final HomeThemeModel theme;
  final TextEditingController ctaController;
  final ValueChanged<StoreBannerModel> onDraft;
  final VoidCallback onCtaChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('啟用按鈕'),
          value: draft.ctaEnabled,
          onChanged: (bool value) {
            onDraft(
              draft.copyWith(
                ctaEnabled: value,
                ctaText: value && draft.ctaText.trim().isEmpty
                    ? '開始選購'
                    : draft.ctaText,
              ),
            );
            if (value && ctaController.text.trim().isEmpty) {
              ctaController.text = '開始選購';
            }
          },
        ),
        if (draft.ctaEnabled) ...<Widget>[
          TextField(
            controller: ctaController,
            decoration: const InputDecoration(labelText: '按鈕文字'),
            onChanged: (_) => onCtaChanged(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示箭頭'),
            value: draft.ctaShowArrow,
            onChanged: (bool value) {
              onDraft(draft.copyWith(ctaShowArrow: value));
            },
          ),
          const SizedBox(height: 8),
          StoreBannerColorField(
            label: '按鈕背景色',
            argb:
                draft.ctaBackgroundColor ??
                draft.resolvedCtaBackground(theme).toARGB32(),
            brandColor: theme.primaryColor,
            onChanged: (int value) {
              onDraft(draft.copyWith(ctaBackgroundColor: value));
            },
          ),
          const SizedBox(height: 12),
          StoreBannerColorField(
            label: '按鈕文字色',
            argb:
                draft.ctaTextColor ??
                draft.resolvedCtaForeground(theme).toARGB32(),
            brandColor: theme.primaryColor,
            onChanged: (int value) {
              onDraft(draft.copyWith(ctaTextColor: value));
            },
          ),
          const SizedBox(height: 12),
          const Text('按鈕大小', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _ChipRow(
            values: StoreBannerCtaSizes.all,
            selected: draft.ctaSize,
            labelOf: StoreBannerCtaSizes.label,
            onSelected: (String value) {
              onDraft(draft.copyWith(ctaSize: value));
            },
          ),
          const SizedBox(height: 12),
          const Text('圓角', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _ChipRow(
            values: StoreBannerCtaRadii.all,
            selected: draft.ctaRadius,
            labelOf: StoreBannerCtaRadii.label,
            onSelected: (String value) {
              onDraft(draft.copyWith(ctaRadius: value));
            },
          ),
        ],
      ],
    );
  }
}

class _LinkPanel extends StatelessWidget {
  const _LinkPanel({
    required this.shopId,
    required this.scope,
    required this.draft,
    required this.onDraft,
  });

  final String shopId;
  final PetNestBannerScope scope;
  final StoreBannerModel draft;
  final ValueChanged<StoreBannerModel> onDraft;

  @override
  Widget build(BuildContext context) {
    final bool isHome = scope == PetNestBannerScope.home;
    final List<String> types = isHome
        ? HomeBannerActionTypes.editorTypes
        : StoreBannerActionTypes.all;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        const Text(
          '海報與按鈕共用同一個前往目標。點整張海報或 CTA 都會前往此處。',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        _ChipRow(
          values: types,
          selected: types.contains(draft.actionType)
              ? draft.actionType
              : StoreBannerActionTypes.none,
          labelOf: isHome
              ? HomeBannerActionTypes.label
              : StoreBannerActionTypes.label,
          onSelected: (String value) {
            onDraft(draft.copyWith(actionType: value, actionTargetId: ''));
          },
        ),
        if (draft.actionType == StoreBannerActionTypes.product ||
            (!isHome && draft.actionType != StoreBannerActionTypes.none))
          StoreBannerActionTargetPicker(
            shopId: shopId,
            actionType: draft.actionType,
            selectedId: draft.actionTargetId,
            onSelected: (String id) {
              onDraft(draft.copyWith(actionTargetId: id));
            },
          ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final String Function(String value) labelOf;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((String value) {
        return ChoiceChip(
          label: Text(labelOf(value)),
          selected: selected == value,
          onSelected: (_) => onSelected(value),
        );
      }).toList(),
    );
  }
}

class StoreBannerActionTargetPicker extends StatelessWidget {
  const StoreBannerActionTargetPicker({
    super.key,
    required this.shopId,
    required this.actionType,
    required this.selectedId,
    required this.onSelected,
  });

  final String shopId;
  final String actionType;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (actionType == StoreBannerActionTypes.product) {
      return StreamBuilder<List<StoreProductModel>>(
        stream: StoreProductService.instance.streamEnabledProducts(shopId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<StoreProductModel>> snapshot,
            ) {
              return _dropdown(
                items: (snapshot.data ?? const <StoreProductModel>[])
                    .map(
                      (StoreProductModel item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
              );
            },
      );
    }
    if (actionType == StoreBannerActionTypes.category) {
      return StreamBuilder<List<StoreCategoryModel>>(
        stream: StoreCategoryService.instance.streamCategories(shopId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<StoreCategoryModel>> snapshot,
            ) {
              return _dropdown(
                items: (snapshot.data ?? const <StoreCategoryModel>[])
                    .where((StoreCategoryModel item) => item.enabled)
                    .map(
                      (StoreCategoryModel item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
              );
            },
      );
    }
    return StreamBuilder<List<StorePromotionModel>>(
      stream: StorePromotionService.instance.streamEnabledPromotions(shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<StorePromotionModel>> snapshot,
          ) {
            final List<StorePromotionModel> items =
                (snapshot.data ?? const <StorePromotionModel>[]).where((
                  StorePromotionModel item,
                ) {
                  if (actionType == StoreBannerActionTypes.bundle) {
                    return item.isBundle;
                  }
                  return true;
                }).toList();
            return _dropdown(
              items: items
                  .map(
                    (StorePromotionModel item) => DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
            );
          },
    );
  }

  Widget _dropdown({required List<DropdownMenuItem<String>> items}) {
    final bool hasSelected = items.any(
      (DropdownMenuItem<String> item) => item.value == selectedId,
    );
    return DropdownButtonFormField<String>(
      initialValue: hasSelected ? selectedId : null,
      decoration: const InputDecoration(labelText: '選擇目標'),
      items: items,
      onChanged: (String? value) {
        if (value != null) {
          onSelected(value);
        }
      },
    );
  }
}
