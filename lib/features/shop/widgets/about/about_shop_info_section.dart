import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared by the published About page and its draft preview.
class AboutShopInfoSection extends StatelessWidget {
  const AboutShopInfoSection({
    super.key,
    required this.shopId,
    required this.theme,
    this.shopData,
    this.previewOnly = false,
    this.frameless = false,
    this.actionColor,
    this.layout = 'list',
  });
  final Map<String, dynamic>? shopData;
  final bool previewOnly, frameless;
  final Color? actionColor;
  final String shopId, layout;
  final HomeThemeModel theme;

  Future<void> _launch(BuildContext context, Uri uri) async {
    if (previewOnly) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('launch failed');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暫時無法開啟連結，請稍後再試。')));
      }
    }
  }

  Uri? _webLink(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
            ['https', 'http'].contains(uri.scheme) &&
            uri.host.isNotEmpty
        ? uri
        : null;
  }

  @override
  Widget build(BuildContext context) {
    if (shopData != null) return _content(context, shopData!);
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(shopId),
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _frame(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('店家資訊'),
                const SizedBox(height: 12),
                Text(
                  '店家資訊暫時無法載入，請稍後再試。',
                  style: TextStyle(color: theme.textColor),
                ),
              ],
            ),
          );
        }
        return _content(context, snapshot.data!);
      },
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> shop) {
    String value(String key) => '${shop[key] ?? ''}'.trim();
    final name = value('name');
    final phone = value('phone');
    final hours = value('businessHours');
    final address = aboutShopAddress(shop);
    final license = value('licenseNumber');
    final allowLinks = shop['externalLinksEnabled'] != false;
    final accent = actionColor ?? theme.primaryColor;
    final fields = <(IconData, String, String)>[
      if (hours.isNotEmpty) (Icons.schedule_outlined, '營業時間', hours),
      if (phone.isNotEmpty) (Icons.call_outlined, '聯絡電話', phone),
      if (address.isNotEmpty) (Icons.location_on_outlined, '店家地址', address),
      if (license.isNotEmpty) (Icons.badge_outlined, '特寵業許可字號', license),
    ];
    final mapUri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': address,
    });
    Widget identity() => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: value('logoUrl').isEmpty
              ? Icon(Icons.storefront_outlined, color: theme.primaryColor)
              : Image.network(
                  value('logoUrl'),
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) => Icon(
                    Icons.storefront_outlined,
                    color: theme.primaryColor,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? '店家資訊' : name,
                style: TextStyle(
                  fontSize: 21,
                  height: 1.4,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              if (name.isNotEmpty)
                Text(
                  '店家資訊',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.secondaryTextColor,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    Widget field((IconData, String, String) data, {bool tile = false}) =>
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(tile ? 14 : 0),
          decoration: tile
              ? BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.cardBorderColor),
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(data.$1, color: theme.primaryColor, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      data.$3,
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.textColor,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    final actions = <Widget>[];
    void action(String label, IconData icon, VoidCallback? onPressed) {
      actions.add(
        OutlinedButton.icon(
          onPressed: previewOnly ? () {} : onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(foregroundColor: accent),
        ),
      );
    }

    if (allowLinks && phone.isNotEmpty) {
      final dial = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      if (dial.isNotEmpty) {
        action(
          '撥打電話',
          Icons.call_outlined,
          () => _launch(context, Uri(scheme: 'tel', path: dial)),
        );
      }
    }
    if (allowLinks && address.isNotEmpty) {
      action('開啟地圖', Icons.near_me_outlined, () => _launch(context, mapUri));
    }
    for (final data in [
      ('igUrl', 'Instagram', Icons.camera_alt_outlined),
      ('lineUrl', 'LINE', Icons.chat_bubble_outline),
    ]) {
      final uri = _webLink(value(data.$1));
      if (allowLinks && uri != null) {
        action(data.$2, data.$3, () => _launch(context, uri));
      }
    }
    if (address.isNotEmpty) {
      action('複製地址', Icons.copy_outlined, () async {
        await Clipboard.setData(ClipboardData(text: address));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已複製店家地址')));
        }
      });
    }
    final tiles = layout == 'tiles';
    return _frame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (layout == 'brand') ...[
            identity(),
            const SizedBox(height: 18),
            Divider(color: theme.cardBorderColor),
            const SizedBox(height: 12),
          ] else ...[
            _heading('店家資訊'),
            if (name.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
              ),
            const SizedBox(height: 18),
          ],
          if (layout == 'visit' && address.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.near_me_outlined, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        '到店指南',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    address.isEmpty ? '請先聯絡店家確認到店地址。' : address,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '來訪前請先聯繫店家，確認接待時間與安排。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: theme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  tiles &&
                      constraints.maxWidth >= 540 &&
                      MediaQuery.textScalerOf(context).scale(1) <= 1.3
                  ? 2
                  : 1;
              final shown = layout == 'visit'
                  ? fields.where((data) => data.$2 != '店家地址').toList()
                  : fields;
              return Wrap(
                spacing: 12,
                runSpacing: tiles ? 12 : 16,
                children: [
                  for (final data in shown)
                    SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 12) / columns,
                      child: field(data, tile: tiles),
                    ),
                ],
              );
            },
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }

  Widget _heading(String text) => Row(
    children: [
      Icon(Icons.storefront_outlined, color: theme.primaryColor),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: theme.textColor,
          ),
        ),
      ),
    ],
  );
  Widget _frame(Widget child) => Padding(
    padding: frameless
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 22),
    child: Container(
      width: double.infinity,
      padding: frameless ? EdgeInsets.zero : const EdgeInsets.all(22),
      decoration: frameless
          ? null
          : BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: theme.cardBorderColor),
            ),
      child: child,
    ),
  );
}

/// Existing records may already include the city or district in address.
String aboutShopAddress(Map<String, dynamic> shop) {
  String value(String key) => '${shop[key] ?? ''}'.trim();
  final city = value('city'),
      district = value('district'),
      detail = value('address');
  if (city.isNotEmpty && detail.startsWith(city)) return detail;
  if (district.isNotEmpty && detail.startsWith(district)) return '$city$detail';
  return '$city$district$detail';
}
