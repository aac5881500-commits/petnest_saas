import 'package:flutter/material.dart';
import '../../../core/models/shop_house_appearance.dart';

/// 模式只決定是否顯示裝飾，原本逐部位的圖庫選擇仍保留。
class ShopHouseModeSelector extends StatelessWidget {
  const ShopHouseModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
    required this.onApply,
    required this.saving,
  });
  final String mode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onApply;
  final bool saving;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('外觀模式', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth >= 600
              ? (box.maxWidth - 12) / 2
              : box.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final plain in [false, true])
                SizedBox(width: width, child: _option(context, plain)),
            ],
          );
        },
      ),
      const SizedBox(height: 10),
      const Text('切換只改變呈現方式，原有小屋圖片設定會完整保留。'),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const ValueKey('apply-house-mode'),
        onPressed: onApply,
        icon: const Icon(Icons.check),
        label: Text(saving ? '儲存中' : '套用並儲存外觀'),
      ),
    ],
  );

  Widget _option(BuildContext context, bool plain) {
    final value = plain
        ? ShopHouseAppearance.minimalPlainMode
        : ShopHouseAppearance.houseMode;
    final selected = plain
        ? mode == value
        : mode != ShopHouseAppearance.minimalPlainMode;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? colors.primaryContainer.withValues(alpha: .25)
            : colors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('select-house-mode-$value'),
          borderRadius: BorderRadius.circular(16),
          onTap: onChanged == null ? null : () => onChanged!(value),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 76,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: plain
                        ? Container(
                            width: 150,
                            height: 48,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.photo_outlined,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        height: 5,
                                        color: colors.outlineVariant,
                                      ),
                                      const SizedBox(height: 5),
                                      Container(
                                        height: 4,
                                        color: colors.surfaceContainerHighest,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Icon(
                            Icons.cottage_outlined,
                            size: 52,
                            color: colors.primary,
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  plain ? '極簡素面（無裝飾）' : '小屋外觀',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(plain ? '不使用小屋裝飾，呈現簡約的店家資訊卡片。' : '沿用目前的木質、浪漫花園或現代日式圖片設定。'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
