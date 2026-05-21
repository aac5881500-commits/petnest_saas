// lib/features/auth/widgets/platform_home_hero_card.dart
// 🏠 平台首頁主視覺卡片
// 功能：顯示 PetNest 歡迎區、找寵物旅館、建立店家入口

import 'package:flutter/material.dart';

class PlatformHomeHeroCard extends StatelessWidget {
  const PlatformHomeHeroCard({
    super.key,
    required this.onFindShopTap,
    required this.onCreateShopTap,
  });

  final VoidCallback onFindShopTap;
  final VoidCallback onCreateShopTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '歡迎使用 PetNest',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3A2A1A),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '幫你找到適合毛孩的住宿，也讓店家更輕鬆管理預約。',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _HeroActionButton(
                  icon: Icons.search,
                  title: '找寵物旅館',
                  subtitle: '查看公開店家',
                  onTap: onFindShopTap,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _HeroActionButton(
                  icon: Icons.storefront,
                  title: '我要開店',
                  subtitle: '建立店家後台',
                  onTap: onCreateShopTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.orange.shade100,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Colors.orange.shade600,
              size: 26,
            ),

            const SizedBox(height: 10),

            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF3A2A1A),
              ),
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}