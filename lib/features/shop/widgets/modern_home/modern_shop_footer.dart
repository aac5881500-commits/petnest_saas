// 檔案名稱：lib/features/shop/widgets/modern_home/modern_shop_footer.dart
// 功能說明：顯示店名、營業時間、電話、地址、社群連結與關於我們入口
// 🏪 新版首頁店家資訊 Footer

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shop_modern_logo.dart';

class ModernShopFooter extends StatelessWidget {
  const ModernShopFooter({
    super.key,
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
    final String licenseNumber = (shop['licenseNumber'] ?? '')
        .toString()
        .trim();
    final String taxId = (shop['taxId'] ?? '').toString().trim();
    final bool showTaxId = shop['showTaxId'] == true;
    final String instagramUrl = (shop['igUrl'] ?? '').toString().trim();
    final String facebookUrl = (shop['fbUrl'] ?? '').toString().trim();
    final String lineUrl = (shop['lineUrl'] ?? '').toString().trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            ShopModernLogo(
              imageUrl: logoUrl,
              size: 48,
              borderRadius: 14,
              primaryColor: primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                shopName,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: darkTextColor,
                ),
              ),
            ),
            if (onClose != null)
              IconButton(
                tooltip: '關閉店家資訊',
                onPressed: onClose,
                icon: Icon(Icons.close_rounded, color: secondaryTextColor),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (businessHours.isNotEmpty) ...[
          _infoDetail(Icons.schedule_rounded, '營業時間', businessHours),
          const SizedBox(height: 12),
        ],
        if (address.isNotEmpty) ...[
          _infoDetail(Icons.location_on_outlined, '店家地址', address),
          const SizedBox(height: 12),
        ],
        if (phone.isNotEmpty) ...[
          _infoDetail(Icons.phone_outlined, '聯絡電話', phone),
          const SizedBox(height: 12),
        ],
        if (phone.isNotEmpty ||
            address.isNotEmpty ||
            lineUrl.isNotEmpty ||
            instagramUrl.isNotEmpty ||
            facebookUrl.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (phone.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _callPhone(phone),
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: const Text('撥打電話'),
                ),
              if (address.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _openMap(address),
                  icon: const Icon(Icons.near_me_outlined, size: 18),
                  label: const Text('開啟地圖'),
                ),
              if (lineUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _openUrl(lineUrl),
                  icon: const FaIcon(FontAwesomeIcons.line, size: 18),
                  label: const Text('LINE'),
                ),
              if (instagramUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _openUrl(instagramUrl),
                  icon: const FaIcon(FontAwesomeIcons.instagram, size: 18),
                  label: const Text('Instagram'),
                ),
              if (facebookUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _openUrl(facebookUrl),
                  icon: const FaIcon(FontAwesomeIcons.facebookF, size: 18),
                  label: const Text('Facebook'),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (licenseNumber.isNotEmpty || (showTaxId && taxId.isNotEmpty)) ...[
          Divider(color: borderColor, height: 20),
          if (licenseNumber.isNotEmpty)
            Text(
              '特寵字號：$licenseNumber',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: secondaryTextColor,
              ),
            ),
          if (showTaxId && taxId.isNotEmpty)
            Text(
              '統一編號：$taxId',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: secondaryTextColor,
              ),
            ),
        ],
      ],
    );
  }

  Widget _infoDetail(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: primaryColor),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
            const SizedBox(height: 2),
            SelectableText(
              value,
              style: TextStyle(fontSize: 14, height: 1.5, color: darkTextColor),
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> showShopInfoSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 16),
                buildInfoBody(
                  sheetContext,
                  onClose: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部導覽樣式時放在首頁捲動區最下方的店家資訊。
/// 收合時顯示資訊摘要，展開與彈出面板共用聯絡內容。
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Material(
        color: footer.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: footer.borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              expanded: _expanded,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: footer.primaryColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.storefront_outlined,
                          color: footer.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '店家資訊',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: footer.darkTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '營業時間・地址・聯絡方式',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: footer.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: footer.secondaryTextColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_expanded) ...[
              Divider(height: 1, color: footer.borderColor),
              Padding(
                padding: const EdgeInsets.all(18),
                child: footer.buildInfoBody(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
