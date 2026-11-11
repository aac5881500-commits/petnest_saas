import 'package:petnest_saas/features/booking/models/pre_arrival_shortcut.dart';
import 'package:petnest_saas/features/booking/models/pre_arrival_item_presentation.dart';
import 'package:petnest_saas/features/booking/widgets/pre_arrival_appearance_surface.dart';
import 'package:petnest_saas/core/services/shop_contact_shortcut_service.dart';
import 'package:petnest_saas/features/booking/widgets/pre_arrival_styled_content.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 檔案名稱：lib/features/booking/pages/pre_arrival_guide_page.dart
// 功能說明：客戶端入住前準備完整內容（標題／文字／圖片），支援個人準備清單。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';

class PreArrivalGuidePage extends StatefulWidget {
  const PreArrivalGuidePage({
    super.key,
    required this.guide,
    this.progressScope,
    this.embedded = false,
    this.shortcut,
    this.backLabel = '返回訂單',
  });

  final PreArrivalGuideModel guide;
  final bool embedded;
  final PreArrivalShortcut? shortcut;
  final String backLabel;

  /// Null for shop previews: preview checks never alter customer progress.
  final String? progressScope;

  @override
  State<PreArrivalGuidePage> createState() => _PreArrivalGuidePageState();
}

class _PreArrivalGuidePageState extends State<PreArrivalGuidePage> {
  PreArrivalGuideModel get guide => widget.guide;
  final Set<String> _checked = <String>{};
  SharedPreferences? _preferences;
  bool _ready = false;
  bool _leaving = false;
  late final Future<void> _progressLoad;
  Future<void> _writeQueue = Future<void>.value();
  String? get _storageKey => widget.progressScope == null
      ? null
      : PreArrivalShortcut.progressKey(
          widget.progressScope!,
          guide.serviceType,
        );
  String _itemKey(PreArrivalGuideBlock block) =>
      PreArrivalShortcut.itemKey(block);

  @override
  void initState() {
    super.initState();
    _progressLoad = _loadProgress();
  }

  Future<void> _loadProgress() async {
    if (_storageKey != null) {
      try {
        _preferences = await SharedPreferences.getInstance();
        _checked.addAll(
          _preferences!.getStringList(_storageKey!) ?? <String>[],
        );
      } catch (_) {
        // Remain usable when local storage is unavailable.
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _toggle(PreArrivalGuideBlock block, bool value) async {
    setState(() {
      if (value) {
        _checked.add(_itemKey(block));
      } else {
        _checked.remove(_itemKey(block));
      }
    });
    if (_storageKey == null) return;
    final key = _storageKey!;
    final currentKeys = guide.visibleBlocks
        .where((b) => b.type == PreArrivalGuideBlockType.checklist)
        .map(_itemKey)
        .toSet();
    final snapshot = _checked.intersection(currentKeys).toList();
    _writeQueue = _writeQueue.then((_) async {
      bool saved = false;
      try {
        saved = await _preferences?.setStringList(key, snapshot) ?? false;
      } catch (_) {
        /* Report local storage failures below. */
      }
      if (saved) PreArrivalShortcut.changes.value++;
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目前無法保留勾選進度，離開後可能需要重新勾選。')),
        );
      }
    });
    await _writeQueue;
  }

  Future<void> _returnToOrder() async {
    if (_leaving) return;
    _leaving = true;
    try {
      await _progressLoad;
      await _writeQueue;
      if (!mounted) return;
      final shortcut = widget.shortcut;
      final prefs = _preferences;
      if (shortcut != null && prefs != null && shortcut.choice(prefs) == null) {
        final choice = await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (sheetContext) => SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '下次更快找到準備清單',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text('加到這間店的首頁，入住前可以直接接著準備。'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('加到店家首頁'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: const Text('不用了，返回訂單'),
                    ),
                    const Text('辦理入住後，首頁卡片會自動收起。', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        );
        if (choice == null || !mounted) return;
        final saved = await shortcut.saveChoice(prefs, choice);
        if (!mounted) return;
        if (!saved) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('目前無法儲存首頁設定')));
        }
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      _leaving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<PreArrivalGuideBlock> blocks = guide.visibleBlocks;
    final items = blocks
        .where((b) => b.type == PreArrivalGuideBlockType.checklist)
        .toList();
    final done = items.where((b) => _checked.contains(_itemKey(b))).length;
    return ShopFrontendThemeScope(
      shopId: guide.shopId,
      builder: (BuildContext context) {
        return PreArrivalAppearanceSurface(
          guide: guide,
          builder: (context) {
            final page = Scaffold(
              backgroundColor: PreArrivalAppearanceScope.of(context).paper,
              appBar: guide.style == PreArrivalGuideStyle.classic
                  ? AppBar(
                      automaticallyImplyLeading: !widget.embedded,
                      title: Text(guide.displayTitle),
                      backgroundColor: PreArrivalAppearanceScope.of(
                        context,
                      ).paper,
                    )
                  : null,
              body: guide.style != PreArrivalGuideStyle.classic
                  ? PreArrivalStyledContent(
                      guide: guide,
                      palette: PreArrivalAppearanceScope.of(context),
                      done: done,
                      total: items.length,
                      isChecked: (block) => _checked.contains(_itemKey(block)),
                      onToggle: _ready
                          ? (block, value) => _toggle(block, value)
                          : null,
                      imageBuilder: (block) => _block(context, block),
                      preview: widget.progressScope == null,
                      backLabel: widget.backLabel,
                      onBack: () {
                        if (widget.embedded) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('此為客戶畫面預覽；正式頁面可返回訂單。'),
                            ),
                          );
                        } else {
                          if (widget.shortcut == null) {
                            Navigator.of(context).maybePop();
                          } else {
                            _returnToOrder();
                          }
                        }
                      },
                      onContact: () async {
                        if (widget.progressScope == null ||
                            guide.shopId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('預覽模式：正式頁面會開啟店家設定的聯絡方式。'),
                            ),
                          );
                          return;
                        }
                        try {
                          await ShopContactShortcutService.instance.contactShop(
                            context: context,
                            shopId: guide.shopId,
                          );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('目前無法開啟聯絡資訊，請稍後再試。'),
                              ),
                            );
                          }
                        }
                      },
                    )
                  : BookingDetailUi.constrain(
                      ListView(
                        padding: const EdgeInsets.all(
                          BookingDetailUi.pagePadding,
                        ),
                        children: <Widget>[
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: PreArrivalAppearanceScope.of(context).card,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFD5E8DF),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.pets_rounded,
                                  color: PreArrivalAppearanceScope.of(
                                    context,
                                  ).accent,
                                  size: 36,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '小貓的出發準備',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    color: PreArrivalAppearanceScope.of(
                                      context,
                                    ).ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '把需要的物品準備好，安心出發囉！',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: PreArrivalAppearanceScope.of(
                                      context,
                                    ).ink,
                                    height: 1.5,
                                  ),
                                ),
                                if (items.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  Text(
                                    '準備進度 $done / ${items.length}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: PreArrivalAppearanceScope.of(
                                        context,
                                      ).ink,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: LinearProgressIndicator(
                                      value: done / items.length,
                                      minHeight: 9,
                                      color: PreArrivalAppearanceScope.of(
                                        context,
                                      ).accent,
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    done == items.length
                                        ? '都準備好了，出發前再確認一次吧！'
                                        : '準備好一項，就點一下物品卡片。',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: PreArrivalAppearanceScope.of(
                                        context,
                                      ).ink,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.progressScope == null
                                        ? '預覽模式：可試勾，不會儲存進度。'
                                        : '勾選已準備好的物品，進度保留在此裝置，供自己整理使用。',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: PreArrivalAppearanceScope.of(
                                        context,
                                      ).ink,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (blocks.isEmpty)
                            Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('尚未新增準備內容'),
                            ),
                          ..._content(context, blocks),
                        ],
                      ),
                    ),
            );
            if (widget.shortcut == null) return page;
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _returnToOrder();
              },
              child: page,
            );
          },
        );
      },
    );
  }

  List<Widget> _content(
    BuildContext context,
    List<PreArrivalGuideBlock> blocks,
  ) {
    final result = <Widget>[];
    var number = 0;
    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.type != PreArrivalGuideBlockType.checklist) {
        result.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _block(context, block),
          ),
        );
        continue;
      }
      final group = <PreArrivalGuideBlock>[block];
      while (i + 1 < blocks.length &&
          blocks[i + 1].type == PreArrivalGuideBlockType.checklist) {
        group.add(blocks[++i]);
      }
      final start = number;
      number += group.length;
      result.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
              final columns = largeText || constraints.maxWidth < 340
                  ? 1
                  : constraints.maxWidth >= 760
                  ? 4
                  : constraints.maxWidth >= 540
                  ? 3
                  : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (int n = 0; n < group.length; n++)
                    SizedBox(
                      width: width,
                      child: _itemCard(context, group[n], start + n + 1),
                    ),
                ],
              );
            },
          ),
        ),
      );
    }
    return result;
  }

  Widget _itemCard(
    BuildContext context,
    PreArrivalGuideBlock block,
    int number,
  ) {
    final checked = _checked.contains(_itemKey(block));
    final presentation = PreArrivalItemPresentation.forBlock(block);
    final icon = presentation.icon;
    final tint = PreArrivalAppearanceScope.of(
      context,
    ).accent.withValues(alpha: .1);
    return Semantics(
      checked: checked,
      enabled: _ready,
      label: block.text,
      child: Material(
        color: checked
            ? Color.alphaBlend(
                PreArrivalAppearanceScope.of(
                  context,
                ).accent.withValues(alpha: .08),
                PreArrivalAppearanceScope.of(context).card,
              )
            : PreArrivalAppearanceScope.of(context).card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: checked
                ? PreArrivalAppearanceScope.of(context).accent
                : const Color(0xFFE5E8E1),
            width: checked ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>('preparation-check-${block.id}'),
          onTap: _ready ? () => _toggle(block, !checked) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: PreArrivalAppearanceScope.of(
                        context,
                      ).accent,
                      child: Text(
                        '$number',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      checked
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: checked
                          ? PreArrivalAppearanceScope.of(context).accent
                          : const Color(0xFFADB9B0),
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    icon,
                    size: 37,
                    color: PreArrivalAppearanceScope.of(context).ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  presentation.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: PreArrivalAppearanceScope.of(context).ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  block.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: PreArrivalAppearanceScope.of(context).ink,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  checked ? '已備妥 ✓' : '點一下，標記已備妥',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: checked
                        ? PreArrivalAppearanceScope.of(context).accent
                        : PreArrivalAppearanceScope.of(context).ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _block(BuildContext context, PreArrivalGuideBlock block) {
    if (block.type == PreArrivalGuideBlockType.heading) {
      return Row(
        children: [
          Icon(
            Icons.pets_rounded,
            size: 18,
            color: PreArrivalAppearanceScope.of(context).accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              block.text,
              style: TextStyle(
                fontSize: BookingDetailUi.sectionTitleSize,
                fontWeight: FontWeight.w700,
                color: PreArrivalAppearanceScope.of(context).ink,
              ),
            ),
          ),
        ],
      );
    }
    if (block.type == PreArrivalGuideBlockType.text) {
      if (block.id.startsWith('catalog-')) {
        final item = PreArrivalItemPresentation.forBlock(block);
        final palette = PreArrivalAppearanceScope.of(context);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, color: palette.accent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    block.text,
                    style: TextStyle(
                      fontSize: BookingDetailUi.bodySize,
                      color: palette.ink,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }
      return Text(
        block.text,
        style: TextStyle(
          fontSize: BookingDetailUi.bodySize,
          color: PreArrivalAppearanceScope.of(context).ink,
          height: 1.5,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                child: InteractiveViewer(
                  child: BookingDetailSoftNetworkImage(
                    url: block.imageUrl,
                    fit: BoxFit.contain,
                    fallbackIcon: Icons.broken_image_outlined,
                  ),
                ),
              ),
            );
          },
          child: BookingDetailSoftNetworkImage(
            url: block.imageUrl,
            height: 220,
            fit: BoxFit.cover,
            fallbackIcon: Icons.broken_image_outlined,
          ),
        ),
        if (block.caption.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              block.caption,
              style: TextStyle(
                fontSize: BookingDetailUi.captionSize,
                color: PreArrivalAppearanceScope.of(
                  context,
                ).ink.withValues(alpha: .7),
              ),
            ),
          ),
      ],
    );
  }
}
