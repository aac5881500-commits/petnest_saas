// 檔案名稱：lib/features/shop/widgets/modern_home/modern_shop_footer.dart
// 功能說明：顯示店名、營業時間、電話、地址、社群連結與關於我們入口
// 🏪 新版首頁店家資訊 Footer

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shop_modern_logo.dart';

class ModernShopFooter extends StatelessWidget {
  const ModernShopFooter({
    required this.shopId,
    required this.shop,
    required this.shopName,
    required this.primaryColor,
    required this.darkTextColor,
    required this.secondaryTextColor,
    required this.cardColor,
    required this.borderColor,
    this.isPreview = false,
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final String shopName;

  final Color primaryColor;
  final Color darkTextColor;
  final Color secondaryTextColor;
  final Color cardColor;
  final Color borderColor;
  final bool isPreview;

  Future<void> _openUrl(String rawUrl) async {
    if (isPreview) {
      return;
    }
    final url = rawUrl.trim();

    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);

    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callPhone(String rawPhone) async {
    if (isPreview) {
      return;
    }
    final phone = rawPhone.trim();

    if (phone.isEmpty) return;

    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _openMap(String rawAddress) async {
    if (isPreview) {
      return;
    }
    final address = rawAddress.trim();

    if (address.isEmpty) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${Uri.encodeComponent(address)}',
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = (shop['logoUrl'] ?? '').toString().trim();
    final phone = (shop['phone'] ?? '').toString().trim();

    final address = [
      (shop['city'] ?? '').toString().trim(),
      (shop['district'] ?? '').toString().trim(),
      (shop['address'] ?? '').toString().trim(),
    ].where((value) => value.isNotEmpty).join();

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          showShopInfoSheet(context);
        },
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                padding: const EdgeInsets.all(3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: logoUrl.isNotEmpty
                      ? Image.network(
                          logoUrl,
                          width: 26,
                          height: 26,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.pets_rounded,
                              size: 17,
                              color: primaryColor,
                            );
                          },
                        )
                      : Icon(Icons.pets_rounded, size: 17, color: primaryColor),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: darkTextColor,
                      ),
                    ),
                    if (phone.isNotEmpty || address.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        phone.isNotEmpty ? phone : address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 8.5,
                          height: 1,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (phone.isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    _callPhone(phone);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(
                      Icons.phone_outlined,
                      size: 17,
                      color: primaryColor,
                    ),
                  ),
                ),
              if (address.isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    _openMap(address);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: primaryColor,
                    ),
                  ),
                ),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 20,
                color: secondaryTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildInfoBody(BuildContext context, {VoidCallback? onClose}) {
    final String logoUrl = (shop['logoUrl'] ?? '').toString().trim();
    final String phone = (shop['phone'] ?? '').toString().trim();
    final String address = <String>[
      (shop['city'] ?? '').toString().trim(),
      (shop['district'] ?? '').toString().trim(),
      (shop['address'] ?? '').toString().trim(),
    ].where((String value) => value.isNotEmpty).join();
    final String savedBusinessHours = (shop['businessHours'] ?? '')
        .toString()
        .trim();
    final String openTime = (shop['openTime'] ?? '').toString().trim();
    final String closeTime = (shop['closeTime'] ?? '').toString().trim();
    final String businessHours = savedBusinessHours.isNotEmpty
        ? savedBusinessHours
        : openTime.isNotEmpty && closeTime.isNotEmpty
        ? '$openTime - $closeTime'
        : '';
    final String licenseNumber = (shop['licenseNumber'] ?? '').toString().trim();
    final String taxId = (shop['taxId'] ?? '').toString().trim();
    final bool showTaxId = shop['showTaxId'] == true;
    final String instagramUrl = (shop['igUrl'] ?? '').toString().trim();
    final String facebookUrl = (shop['fbUrl'] ?? '').toString().trim();
    final String lineUrl = (shop['lineUrl'] ?? '').toString().trim();
    final double sheetWidth = MediaQuery.sizeOf(context).width;
    final double logoSize = sheetWidth < 370
        ? 60
        : sheetWidth < 420
        ? 64
        : 66;
    final double logoTextGap = sheetWidth < 370 ? 12 : 14;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ShopModernLogo(
          imageUrl: logoUrl,
          size: logoSize,
          borderRadius: 11,
          primaryColor: primaryColor,
        ),
        SizedBox(width: logoTextGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                shopName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: darkTextColor,
                ),
              ),
              if (businessHours.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                _buildCompactInfoRow(
                  icon: Icons.schedule_rounded,
                  text: businessHours,
                ),
              ],
              if (phone.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                _buildCompactInfoRow(
                  icon: Icons.phone_outlined,
                  text: phone,
                  onTap: () => _callPhone(phone),
                ),
              ],
              if (address.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                _buildCompactInfoRow(
                  icon: Icons.location_on_outlined,
                  text: address,
                  onTap: () => _openMap(address),
                ),
              ],
              if (licenseNumber.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                _buildCompactInfoRow(
                  icon: Icons.verified_outlined,
                  text: '特寵字號：$licenseNumber',
                ),
              ],
              if (showTaxId && taxId.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                _buildCompactInfoRow(
                  icon: Icons.receipt_long_outlined,
                  text: '統一編號：$taxId',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 104,
          child: Column(
            children: <Widget>[
              if (onClose != null)
                Align(
                  alignment: Alignment.topRight,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onClose,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ),
              if (onClose != null) const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  _buildCompactSocialButton(
                    icon: FontAwesomeIcons.instagram,
                    tooltip: 'Instagram',
                    isEnabled: instagramUrl.isNotEmpty,
                    onTap: instagramUrl.isNotEmpty
                        ? () => _openUrl(instagramUrl)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  _buildCompactSocialButton(
                    icon: FontAwesomeIcons.facebookF,
                    tooltip: 'Facebook',
                    isEnabled: facebookUrl.isNotEmpty,
                    onTap: facebookUrl.isNotEmpty
                        ? () => _openUrl(facebookUrl)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  _buildCompactSocialButton(
                    icon: FontAwesomeIcons.line,
                    tooltip: 'LINE',
                    isEnabled: lineUrl.isNotEmpty,
                    onTap: lineUrl.isNotEmpty ? () => _openUrl(lineUrl) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> showShopInfoSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                buildInfoBody(
                  sheetContext,
                  onClose: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactInfoRow({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 15, color: primaryColor),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, height: 1.3, color: darkTextColor),
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: secondaryTextColor,
            ),
        ],
      ),
    );
  }

  Widget _buildCompactSocialButton({
    required FaIconData? icon,
    required String tooltip,
    required bool isEnabled,
    required VoidCallback? onTap,
  }) {
    final enabledColor = switch (tooltip) {
      'Instagram' => const Color(0xFFE1306C),
      'Facebook' => const Color(0xFF1877F2),
      'LINE' => const Color(0xFF06C755),
      _ => darkTextColor,
    };

    final iconColor = isEnabled
        ? enabledColor
        : secondaryTextColor.withValues(alpha: 0.35);

    final backgroundColor = isEnabled
        ? primaryColor.withValues(alpha: 0.10)
        : cardColor;

    return Tooltip(
      message: isEnabled ? tooltip : '$tooltip 尚未設定',
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isEnabled
                  ? borderColor
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: FaIcon(icon, size: 14, color: iconColor),
        ),
      ),
    );
  }
}

/// 底部導覽樣式時放在首頁捲動區最下方的店家資訊。
/// 標題與箭頭沿用原本固定列，展開內容沿用 [ModernShopFooter.buildInfoBody]。
class ModernShopInfoPanel extends StatefulWidget {
  const ModernShopInfoPanel({super.key, required this.footer});

  final ModernShopFooter footer;

  @override
  State<ModernShopInfoPanel> createState() => _ModernShopInfoPanelState();
}

class _ModernShopInfoPanelState extends State<ModernShopInfoPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ModernShopFooter footer = widget.footer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: footer.cardColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      size: 18,
                      color: footer.secondaryTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '店家資訊',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: footer.darkTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: footer.buildInfoBody(context),
              ),
          ],
        ),
      ),
    );
  }
}
