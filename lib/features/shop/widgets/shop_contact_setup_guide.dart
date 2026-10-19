// 檔案名稱：lib/features/shop/widgets/shop_contact_setup_guide.dart
// 功能說明：新店家首次只完成電話與完整地址的引導區塊。

import 'package:flutter/material.dart';

const _ink = Color(0xFF74250F);
const _muted = Color(0xFF796A5D);
const _orange = Color(0xFFF45B14);
const _cream = Color(0xFFFFFAF2);
const _card = Color(0xFFFFFDF9);
const _line = Color(0xFFF3E7D8);

/// 空白、過短或含有非電話字元時回傳錯誤。保留市話、手機與 +886。
String? validateShopContactPhone(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return '請填寫店家聯絡電話';
  final compact = raw.replaceAll(RegExp(r'[\s\-().]'), '');
  final String local;
  if (compact.startsWith('+886')) {
    local = '0${compact.substring(4)}';
  } else if (compact.startsWith('886') && compact.length > 10) {
    local = '0${compact.substring(3)}';
  } else {
    local = compact;
  }
  if (!RegExp(r'^0\d{8,11}$').hasMatch(local)) {
    return '請輸入有效的電話，例如 0912345678 或 02-12345678';
  }
  return null;
}

/// 縣市、區域已存在仍不足以完成；詳細地址與電話都要有效。
bool shopContactStepReady({
  required String phone,
  required String city,
  required String district,
  required String address,
  required bool cityKnown,
  required bool districtKnown,
}) {
  return validateShopContactPhone(phone) == null &&
      city.trim().isNotEmpty &&
      district.trim().isNotEmpty &&
      cityKnown &&
      districtKnown &&
      address.trim().isNotEmpty;
}

class ShopContactSetupHeader extends StatelessWidget {
  const ShopContactSetupHeader({
    super.key,
    required this.shopName,
    required this.showActivationProgress,
  });

  final String shopName;
  final bool showActivationProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('shop-contact-setup-guide'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pets_rounded, size: 18, color: Color(0xFFB23A0B)),
              SizedBox(width: 8),
              Text(
                'PetNest',
                style: TextStyle(
                  color: _orange,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '先完成旅社的基本聯絡資訊',
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '只需要完成電話與地址，就能繼續設定你的 PetNest 旅社。',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
          ),
          if (shopName.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              shopName.trim(),
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
          if (showActivationProgress) ...[
            const SizedBox(height: 12),
            const Text(
              '步驟 1／3',
              style: TextStyle(
                color: _orange,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _ProgressChip(done: true, label: '啟用碼驗證'),
                _ProgressChip(current: true, label: '完善基本資料'),
                _ProgressChip(label: '開始設定旅社'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({
    required this.label,
    this.done = false,
    this.current = false,
  });

  final String label;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final Color color = done
        ? const Color(0xFF5E8A45)
        : current
        ? _orange
        : const Color(0xFFCDB9A6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: current ? const Color(0xFFFFF1E8) : _cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        '${done
            ? '✓ '
            : current
            ? '● '
            : '○ '}$label',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ShopContactSafetyNote extends StatelessWidget {
  const ShopContactSafetyNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('shop-contact-safety-note'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 20,
            color: Color(0xFFB23A0B),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '請確認資料正確',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '聯絡電話與店家地址首次儲存後，如需修改，必須提出變更申請並經平台審核，以保障店家與顧客權益。',
                  style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared readonly location for initial setup and subsequent visits.
class ShopLocationInfoCard extends StatelessWidget {
  const ShopLocationInfoCard({
    super.key,
    required this.city,
    required this.district,
    required this.complete,
    required this.onRequestChange,
  });
  final String city;
  final String district;
  final bool complete;
  final VoidCallback onRequestChange;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('shop-location-readonly'),
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _cream,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '店家所在地',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                [
                  city.trim(),
                  district.trim(),
                ].where((v) => v.isNotEmpty).join('・'),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.lock_outline, size: 16, color: _muted),
            const SizedBox(width: 4),
            Text(
              complete ? '已設定' : '待修正',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '所在地已於建立旅社時設定，如需變更請提出申請。',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
        ),
        if (!complete) ...[
          const SizedBox(height: 6),
          const Text(
            '目前店家所在地資料不完整，請透過既有資料修正流程處理。',
            style: TextStyle(color: _ink, fontSize: 12, height: 1.5),
          ),
        ],
        TextButton(onPressed: onRequestChange, child: const Text('申請變更所在地')),
      ],
    ),
  );
}
