// lib/features/shop/widgets/store/store_appearance_editor.dart
// 🛒 商城外觀編輯器（賣場功能 → 設定 → 商城外觀）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_appearance_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_product_card.dart';

class StoreAppearanceEditor extends StatefulWidget {
  const StoreAppearanceEditor({
    super.key,
    required this.shopId,
    required this.value,
    required this.shopTheme,
    required this.onChanged,
    required this.onPickCardImage,
    required this.onRemoveCardImage,
    this.uploading = false,
  });

  final String shopId;
  final StoreAppearanceSetting value;
  final HomeThemeModel shopTheme;
  final ValueChanged<StoreAppearanceSetting> onChanged;
  final VoidCallback onPickCardImage;
  final VoidCallback onRemoveCardImage;
  final bool uploading;

  @override
  State<StoreAppearanceEditor> createState() => _StoreAppearanceEditorState();
}

class _StoreAppearanceEditorState extends State<StoreAppearanceEditor> {

  StoreAppearanceSetting get value => widget.value;

  HomeThemeModel get _previewTheme =>
      value.applyTo(HomeThemeModel.modernDefault, widget.shopTheme);

  @override
  Widget build(BuildContext context) {
    final StoreProductModel previewProduct = StoreProductModel(
      id: 'preview',
      shopId: widget.shopId,
      name: '測試罐頭',
      price: 999,
      enabled: true,
      featured: true,
      useInventory: true,
      inventoryItemId: 'preview',
      sortOrder: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      itemPromotionEnabled: true,
      itemPromotionType: StoreItemPromotionTypes.buyXGetY,
      itemPromotionBuyQuantity: 2,
      itemPromotionFreeQuantity: 1,
      publicStockStatus: StoreConstants.stockInStock,
      publicSellableQuantity: 12,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '此設定只影響點進寵物賣場之後的商城頁，不會改旅館首頁。',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        _label('商城頁面背景'),
        _chipWrap(
          options: StorePageBackgroundPresets.all,
          selected: value.pageBackgroundPreset,
          labelOf: StorePageBackgroundPresets.label,
          colorOf: (String item) => StorePageBackgroundPresets.colorOf(
            item,
            widget.shopTheme.backgroundColor,
          ),
          onSelected: (String next) {
            widget.onChanged(value.copyWith(pageBackgroundPreset: next));
          },
        ),
        const SizedBox(height: 18),
        _label('商品卡片'),
        _label('商品卡片背景'),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          title: const Text('純色背景'),
          value: StoreCardBackgroundModes.solid,
          groupValue: value.cardBackgroundMode,
          onChanged: (String? next) {
            if (next == null) {
              return;
            }
            widget.onChanged(value.copyWith(cardBackgroundMode: next));
          },
        ),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          title: const Text('使用圖片'),
          value: StoreCardBackgroundModes.image,
          groupValue: value.cardBackgroundMode,
          onChanged: (String? next) {
            if (next == null) {
              return;
            }
            widget.onChanged(value.copyWith(cardBackgroundMode: next));
          },
        ),
        if (value.cardBackgroundMode == StoreCardBackgroundModes.solid)
          _chipWrap(
            options: StoreCardColorPresets.all,
            selected: value.cardBackgroundPreset,
            labelOf: StoreCardColorPresets.label,
            colorOf: (String item) => StoreCardColorPresets.colorOf(
              item,
              widget.shopTheme.cardColor,
            ),
            onSelected: (String next) {
              widget.onChanged(value.copyWith(cardBackgroundPreset: next));
            },
          )
        else ...<Widget>[
          const Text(
            '建議比例 3:4（例如 1200 × 1600），最低 900 × 1200，最大 5MB，JPG / PNG / WEBP。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          if (value.cardBackgroundImageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(
                  value.cardBackgroundImageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: widget.uploading ? null : widget.onPickCardImage,
                icon: widget.uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_outlined),
                label: Text(
                  value.cardBackgroundImageUrl.isEmpty
                      ? '上傳卡片背景圖片'
                      : '更換卡片背景圖片',
                ),
              ),
              if (value.cardBackgroundImageUrl.isNotEmpty)
                TextButton(
                  onPressed: widget.onRemoveCardImage,
                  child: const Text('移除圖片'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _label('圖片顯示方式'),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text('填滿卡片'),
            value: StoreCardFits.fill,
            groupValue: value.cardBackgroundFit,
            onChanged: (String? next) {
              if (next == null) {
                return;
              }
              widget.onChanged(value.copyWith(cardBackgroundFit: next));
            },
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text('完整顯示'),
            value: StoreCardFits.contain,
            groupValue: value.cardBackgroundFit,
            onChanged: (String? next) {
              if (next == null) {
                return;
              }
              widget.onChanged(value.copyWith(cardBackgroundFit: next));
            },
          ),
          if (value.cardBackgroundFit == StoreCardFits.fill) ...<Widget>[
            _label('圖片位置'),
            Wrap(
              spacing: 8,
              children: StoreCardAlignments.all.map((String item) {
                return ChoiceChip(
                  label: Text(StoreCardAlignments.label(item)),
                  selected: value.cardBackgroundAlignment == item,
                  onSelected: (_) {
                    widget.onChanged(
                      value.copyWith(cardBackgroundAlignment: item),
                    );
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          _label('背景圖片淡化程度'),
          Wrap(
            spacing: 8,
            children: StoreCardOverlays.all.map((String item) {
              return ChoiceChip(
                label: Text(StoreCardOverlays.label(item)),
                selected: value.cardOverlay == item,
                onSelected: (_) {
                  widget.onChanged(value.copyWith(cardOverlay: item));
                },
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 18),
        _label('商品卡片文字'),
        _chipWrap(
          options: StoreCardTextPresets.all,
          selected: value.cardTextPreset,
          labelOf: StoreCardTextPresets.label,
          colorOf: (String item) {
            switch (item) {
              case StoreCardTextPresets.darkGray:
                return const Color(0xFF2A2A2A);
              case StoreCardTextPresets.white:
                return const Color(0xFF8A8A8A);
              case StoreCardTextPresets.brand:
                return widget.shopTheme.primaryColor;
              default:
                return const Color(0xFF3A2A20);
            }
          },
          onSelected: (String next) {
            widget.onChanged(value.copyWith(cardTextPreset: next));
          },
        ),
        const SizedBox(height: 18),
        _label('商城強調色'),
        _chipWrap(
          options: StoreAccentPresets.all,
          selected: value.accentPreset,
          labelOf: StoreAccentPresets.label,
          colorOf: (String item) => StoreAccentPresets.colorOf(
            item,
            widget.shopTheme.primaryColor,
          ),
          onSelected: (String next) {
            widget.onChanged(value.copyWith(accentPreset: next));
          },
        ),
        const SizedBox(height: 18),
        _label('主要按鈕色'),
        Text(
          '只影響加入購物車、立即購買、查看全部與商城 CTA，不影響預約或後台。',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        const Text('主要按鈕色', style: TextStyle(fontWeight: FontWeight.w700)),
        _chipWrap(
          options: StoreAccentPresets.all,
          selected: value.primaryButtonPreset,
          labelOf: StoreAccentPresets.label,
          colorOf: (String item) => StoreAccentPresets.colorOf(
            item,
            widget.shopTheme.primaryColor,
          ),
          onSelected: (String next) {
            widget.onChanged(value.copyWith(primaryButtonPreset: next));
          },
        ),
        const SizedBox(height: 8),
        const Text('次要按鈕色', style: TextStyle(fontWeight: FontWeight.w700)),
        _chipWrap(
          options: StoreAccentPresets.all,
          selected: value.secondaryButtonPreset,
          labelOf: StoreAccentPresets.label,
          colorOf: (String item) =>
              StoreAccentPresets.colorOf(item, const Color(0xFF4A4A4A)),
          onSelected: (String next) {
            widget.onChanged(value.copyWith(secondaryButtonPreset: next));
          },
        ),
        const SizedBox(height: 20),
        _label('即時預覽'),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 176,
            child: StoreProductCard(
              product: previewProduct,
              theme: _previewTheme,
              appearance: value,
              priced: StorePricedLine(
                product: previewProduct,
                quantity: 1,
                originalUnitPrice: 999,
                finalUnitPrice: 799,
                itemPromotionType: StoreItemPromotionTypes.buyXGetY,
              ),
              onTap: () {},
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: value.primaryButtonColor(_previewTheme),
              foregroundColor: StoreAppearanceSetting.onColor(
                value.primaryButtonColor(_previewTheme),
              ),
            ),
            onPressed: () {},
            child: const Text('立即購買'),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _chipWrap({
    required List<String> options,
    required String selected,
    required String Function(String value) labelOf,
    required Color Function(String value) colorOf,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((String item) {
        return ChoiceChip(
          avatar: CircleAvatar(backgroundColor: colorOf(item), radius: 8),
          label: Text(labelOf(item)),
          selected: selected == item,
          onSelected: (_) => onSelected(item),
        );
      }).toList(),
    );
  }
}
