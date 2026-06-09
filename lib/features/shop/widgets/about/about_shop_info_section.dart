// lib/features/shop/widgets/about/about_shop_info_section.dart
// 🐾 關於我們頁 店家資訊區塊
// 從 Firestore 讀取店家營業時間、電話、地址、字號與社群連結

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_section_title.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutShopInfoSection extends StatelessWidget {
  const AboutShopInfoSection({super.key, required this.shopId});

  final String shopId;

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;

    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMap(String address) async {
    final cleanAddress = address.trim();
    if (cleanAddress.isEmpty) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(cleanAddress)}',
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(shopId),
      builder: (context, snapshot) {
        final shop = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (shop == null) {
          return const SizedBox.shrink();
        }

        final externalLinksEnabled = shop['externalLinksEnabled'] != false;

        final businessHours = (shop['businessHours'] ?? '').toString();
        final phone = (shop['phone'] ?? '').toString();

        final city = (shop['city'] ?? '').toString();
        final district = (shop['district'] ?? '').toString();
        final addressDetail = (shop['address'] ?? '').toString();
        final fullAddress = '$city$district$addressDetail';

        final licenseNumber = (shop['licenseNumber'] ?? '').toString();

        final igUrl = (shop['igUrl'] ?? '').toString();
        final lineUrl = (shop['lineUrl'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AboutSectionTitle(icon: Icons.storefront, title: '店家資訊'),

                const SizedBox(height: 18),

                _InfoRow(
                  icon: Icons.access_time,
                  text:
                      '營業時間：${businessHours.isEmpty ? '尚未設定' : businessHours}',
                ),
                _InfoRow(
                  icon: Icons.phone,
                  text: '電話：${phone.isEmpty ? '尚未設定' : phone}',
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  text: '地址：${fullAddress.isEmpty ? '尚未設定' : fullAddress}',
                ),

                if (licenseNumber.isNotEmpty)
                  _InfoRow(
                    icon: Icons.verified_outlined,
                    text: '特寵業字號：$licenseNumber',
                  ),

                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (externalLinksEnabled)
                      _SocialButton(
                        icon: Icons.camera_alt_outlined,
                        label: 'Instagram',
                        isActive: igUrl.isNotEmpty,
                        onTap: igUrl.isNotEmpty ? () => _openUrl(igUrl) : null,
                      ),

                    if (externalLinksEnabled)
                      _SocialButton(
                        icon: Icons.chat_bubble_outline,
                        label: 'LINE',
                        isActive: lineUrl.isNotEmpty,
                        onTap: lineUrl.isNotEmpty
                            ? () => _openUrl(lineUrl)
                            : null,
                      ),

                    _SocialButton(
                      icon: Icons.map_outlined,
                      label: '地圖',
                      isActive: fullAddress.isNotEmpty,
                      onTap: fullAddress.isNotEmpty
                          ? () => _openMap(fullAddress)
                          : null,
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
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Color(0xFFC47A2C)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Color(0xFF4A3A2A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: isActive
                ? const Color(0xFFFFE7C8)
                : Colors.grey.shade200,
            child: Icon(
              icon,
              size: 24,
              color: isActive ? const Color(0xFFC47A2C) : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? const Color(0xFF5C4A3A) : Colors.grey,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
