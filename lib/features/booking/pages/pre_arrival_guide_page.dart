import 'dart:convert';
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
  });

  final PreArrivalGuideModel guide;
  final bool embedded;

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
  Future<void> _writeQueue = Future<void>.value();
  String? get _storageKey => widget.progressScope == null
      ? null
      : 'preparation/v1/${widget.progressScope}/${guide.serviceType}';
  String _itemKey(PreArrivalGuideBlock block) =>
      jsonEncode(<String>[block.id, block.text]);

  @override
  void initState() {
    super.initState();
    _loadProgress();
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
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目前無法保留勾選進度，離開後可能需要重新勾選。')),
        );
      }
    });
    await _writeQueue;
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
        return Scaffold(
          backgroundColor: BookingDetailUi.of(context).background,
          appBar: AppBar(
            automaticallyImplyLeading: !widget.embedded,
            title: Text(guide.displayTitle),
            backgroundColor: BookingDetailUi.of(context).background,
          ),
          body: BookingDetailUi.constrain(
            ListView(
              padding: const EdgeInsets.all(BookingDetailUi.pagePadding),
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF6F2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFD5E8DF)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.pets_rounded,
                        color: Color(0xFF537C6B),
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '小貓的出發準備',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF354F45),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '把需要的物品準備好，安心出發囉！',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF52695F), height: 1.5),
                      ),
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          '準備進度 $done / ${items.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF354F45),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(
                            value: done / items.length,
                            minHeight: 9,
                            color: const Color(0xFF648F79),
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          done == items.length
                              ? '都準備好了，出發前再確認一次吧！'
                              : '準備好一項，就點一下物品卡片。',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF52695F)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.progressScope == null
                              ? '預覽模式：可試勾，不會儲存進度。'
                              : '勾選已準備好的物品，進度保留在此裝置，供自己整理使用。',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF52695F),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (blocks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('尚未新增準備內容'),
                  ),
                ..._content(context, blocks),
              ],
            ),
          ),
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
                      child: _itemCard(group[n], start + n + 1),
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

  Widget _itemCard(PreArrivalGuideBlock block, int number) {
    final checked = _checked.contains(_itemKey(block));
    final (icon, tint) = _itemStyle(block.text);
    return Semantics(
      checked: checked,
      enabled: _ready,
      label: block.text,
      child: Material(
        color: checked ? const Color(0xFFEAF4EE) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: checked ? const Color(0xFF648F79) : const Color(0xFFE5E8E1),
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
                      backgroundColor: const Color(0xFF638878),
                      child: Text(
                        '$number',
                        style: const TextStyle(
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
                          ? const Color(0xFF557F68)
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
                  child: Icon(icon, size: 37, color: const Color(0xFF665D50)),
                ),
                const SizedBox(height: 12),
                Text(
                  block.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3E4C43),
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
                        ? const Color(0xFF557F68)
                        : const Color(0xFF737E76),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (IconData, Color) _itemStyle(String text) {
    if (RegExp('藥|特殊|需求|說明').hasMatch(text)) {
      return (Icons.medical_services_outlined, const Color(0xFFF4E9EF));
    }
    if (RegExp('飼料|食|餐|罐頭').hasMatch(text)) {
      return (Icons.restaurant_rounded, const Color(0xFFFFEDD6));
    }
    if (RegExp('籠|提袋|背包').hasMatch(text)) {
      return (Icons.work_outline_rounded, const Color(0xFFE3EDF8));
    }
    if (RegExp('毛毯|墊|被|安撫').hasMatch(text)) {
      return (Icons.bed_rounded, const Color(0xFFF7E4D9));
    }
    if (RegExp('碗|水').hasMatch(text)) {
      return (Icons.water_drop_outlined, const Color(0xFFE1F1F2));
    }
    if (RegExp('玩具').hasMatch(text)) {
      return (Icons.sports_baseball_outlined, const Color(0xFFF4EACF));
    }
    return (Icons.pets_rounded, const Color(0xFFEDE9F6));
  }

  Widget _block(BuildContext context, PreArrivalGuideBlock block) {
    if (block.type == PreArrivalGuideBlockType.heading) {
      return Row(
        children: [
          const Icon(Icons.pets_rounded, size: 18, color: Color(0xFF648F79)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              block.text,
              style: TextStyle(
                fontSize: BookingDetailUi.sectionTitleSize,
                fontWeight: FontWeight.w700,
                color: BookingDetailUi.of(context).text,
              ),
            ),
          ),
        ],
      );
    }
    if (block.type == PreArrivalGuideBlockType.text) {
      return Text(
        block.text,
        style: TextStyle(
          fontSize: BookingDetailUi.bodySize,
          color: BookingDetailUi.of(context).text,
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
                color: BookingDetailUi.of(context).muted,
              ),
            ),
          ),
      ],
    );
  }
}
