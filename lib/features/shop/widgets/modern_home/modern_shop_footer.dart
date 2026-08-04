// lib/features/shop/widgets/modern_home/modern_shop_footer.dart
// 🏪 新版首頁店家資訊 Footer
// 功能：顯示店名、營業時間、電話、地址、社群連結與關於我們入口

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final String shopName;

  final Color primaryColor;
  final Color darkTextColor;
  final Color secondaryTextColor;
  final Color cardColor;
  final Color borderColor;

  Future<void> _openUrl(String rawUrl) async {
    final url = rawUrl.trim();

    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);

    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callPhone(String rawPhone) async {
    final phone = rawPhone.trim();

    if (phone.isEmpty) return;

    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _openMap(String rawAddress) async {
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
                  color: primaryColor.withOpacity(0.12),
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

  Future<void> showShopInfoSheet(BuildContext context) async {
    final logoUrl = (shop['logoUrl'] ?? '').toString().trim();
    final phone = (shop['phone'] ?? '').toString().trim();

    final address = [
      (shop['city'] ?? '').toString().trim(),
      (shop['district'] ?? '').toString().trim(),
      (shop['address'] ?? '').toString().trim(),
    ].where((value) => value.isNotEmpty).join();

    final savedBusinessHours = (shop['businessHours'] ?? '').toString().trim();

    final openTime = (shop['openTime'] ?? '').toString().trim();
    final closeTime = (shop['closeTime'] ?? '').toString().trim();

    final businessHours = savedBusinessHours.isNotEmpty
        ? savedBusinessHours
        : openTime.isNotEmpty && closeTime.isNotEmpty
        ? '$openTime - $closeTime'
        : '';

    final licenseNumber = (shop['licenseNumber'] ?? '').toString().trim();

    final taxId = (shop['taxId'] ?? '').toString().trim();

    final showTaxId = shop['showTaxId'] == true;

    final instagramUrl = (shop['igUrl'] ?? '').toString().trim();

    final facebookUrl = (shop['fbUrl'] ?? '').toString().trim();

    final lineUrl = (shop['lineUrl'] ?? '').toString().trim();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
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
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShopLogo(logoUrl),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              color: darkTextColor,
                            ),
                          ),

                          const SizedBox(height: 7),

                          if (businessHours.isNotEmpty)
                            _buildCompactInfoRow(
                              icon: Icons.schedule_rounded,
                              text: businessHours,
                            ),

                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildCompactInfoRow(
                              icon: Icons.phone_outlined,
                              text: phone,
                              onTap: () => _callPhone(phone),
                            ),
                          ],

                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildCompactInfoRow(
                              icon: Icons.location_on_outlined,
                              text: address,
                              onTap: () => _openMap(address),
                            ),
                          ],

                          if (licenseNumber.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildCompactInfoRow(
                              icon: Icons.verified_outlined,
                              text: '特寵字號：$licenseNumber',
                            ),
                          ],

                          if (showTaxId && taxId.isNotEmpty) ...[
                            const SizedBox(height: 8),
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
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.pop(sheetContext);
                              },
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

                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
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
                                onTap: lineUrl.isNotEmpty
                                    ? () => _openUrl(lineUrl)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShopLogo(String logoUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 80,
        height: 80,
        color: primaryColor.withOpacity(0.12),
        child: logoUrl.isEmpty
            ? Center(
                child: Icon(Icons.pets_rounded, size: 28, color: primaryColor),
              )
            : Image.network(
                logoUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  return Center(
                    child: Icon(
                      Icons.pets_rounded,
                      size: 28,
                      color: primaryColor,
                    ),
                  );
                },
              ),
      ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: primaryColor),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                height: 1.35,
                color: darkTextColor,
              ),
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
        : secondaryTextColor.withOpacity(0.35);

    final backgroundColor = isEnabled
        ? primaryColor.withOpacity(0.10)
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
              color: isEnabled ? borderColor : Colors.black.withOpacity(0.06),
            ),
          ),
          child: FaIcon(icon, size: 14, color: iconColor),
        ),
      ),
    );
  }
}
