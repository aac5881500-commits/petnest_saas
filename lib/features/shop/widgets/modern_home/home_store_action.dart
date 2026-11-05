import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/core/models/store_entry_builtin_images.dart';
import 'store_entry_photo.dart';

/// Uses the same editable shop title, photo and button copy as the standalone entrance.
class HomeStoreAction extends StatelessWidget {
  const HomeStoreAction({
    super.key,
    required this.setting,
    required this.theme,
    required this.onTap,
    this.photoCard = false,
  });
  final ModernStoreHomeSetting setting;
  final HomeThemeModel theme;
  final VoidCallback onTap;
  final bool photoCard;
  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.primaryColor,
        side: BorderSide(color: theme.primaryColor),
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!photoCard) ...[
            const Icon(Icons.shopping_bag_outlined, size: 17),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              setting.resolvedButtonText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: photoCard ? 11 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, size: 16),
        ],
      ),
    );
    if (!photoCard) return button;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          setting.resolvedTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: StoreEntryPhoto(
            setting.storeBannerImageUrl.isEmpty
                ? StoreEntryBuiltinImages.url('goods')
                : setting.storeBannerImageUrl,
            fit: setting.backgroundBoxFit,
            alignment: setting.backgroundAlignment,
          ),
        ),
        const SizedBox(height: 6),
        button,
      ],
    );
  }
}
