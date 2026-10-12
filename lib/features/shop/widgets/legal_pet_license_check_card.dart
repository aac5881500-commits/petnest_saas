// 檔案名稱：lib/features/shop/widgets/legal_pet_license_check_card.dart
// 功能說明：顯示政府字號比對結果與地址套用，不顯示成平台已認證。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/legal_pet_service.dart';

class LegalPetLicenseCheckCard extends StatelessWidget {
  const LegalPetLicenseCheckCard({
    super.key,
    required this.result,
    required this.stale,
    required this.addressLocked,
    required this.currentAddress,
    required this.onApply,
    required this.onKeep,
    required this.onRequestChange,
  });

  final LegalPetLookupResult result;
  final bool stale;
  final bool addressLocked;
  final String currentAddress;
  final void Function(LegalPetMatch match) onApply;
  final VoidCallback onKeep;
  final void Function(LegalPetMatch match) onRequestChange;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF7F4EF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE4D8C8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '政府資料比對結果',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              stale ? '字號或地址已變更，這次查核結果已失效，請重新查核。' : result.message,
              style: const TextStyle(height: 1.4, fontSize: 13),
            ),
            if (!stale && result.matches.isEmpty) const SizedBox(height: 4),
            if (!stale)
              ...result.matches.map(
                (match) => _MatchBlock(
                  match: match,
                  addressLocked: addressLocked,
                  currentAddress: currentAddress,
                  onApply: () => onApply(match),
                  onKeep: onKeep,
                  onRequestChange: () => onRequestChange(match),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MatchBlock extends StatelessWidget {
  const _MatchBlock({
    required this.match,
    required this.addressLocked,
    required this.currentAddress,
    required this.onApply,
    required this.onKeep,
    required this.onRequestChange,
  });

  final LegalPetMatch match;
  final bool addressLocked;
  final String currentAddress;
  final VoidCallback onApply;
  final VoidCallback onKeep;
  final VoidCallback onRequestChange;

  @override
  Widget build(BuildContext context) {
    final comparison = _comparisonLabel(match.addressComparison);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('政府登記名稱：${match.legalname}'),
          Text('許可證字號：${match.validnum}'),
          Text('有效日期：${match.validDate.isEmpty ? '待確認' : match.validDate}'),
          Text('營業項目：${match.busitemLabel}'),
          Text('寵物種類：${match.animalLabel}'),
          Text('營業狀態：${match.stateLabel}'),
          Text('資料同步時間：${match.syncedAt.isEmpty ? '尚無成功同步' : match.syncedAt}'),
          Text('地址比對：$comparison'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text('目前營業地址\n$currentAddress')),
              const SizedBox(width: 8),
              Expanded(child: Text('政府登記地址\n${match.legaladdress}')),
            ],
          ),
          if (match.addressComparison == 'mismatch') ...[
            const SizedBox(height: 8),
            const Text(
              '營業地址與政府登記地址有明顯差異。申請認證時，需提供地址差異說明及相關證明；若無法確認證照對應此營業場所，將無法通過認證。',
              style: TextStyle(height: 1.4, fontSize: 13),
            ),
          ],
          if (!match.parsedAddress.reliable) ...[
            const SizedBox(height: 8),
            Text('政府原始地址：${match.legaladdress}。縣市或區域無法可靠辨識，請自行確認。'),
          ],
          const SizedBox(height: 8),
          if (!addressLocked) ...[
            if (match.parsedAddress.reliable)
              OutlinedButton(
                onPressed: onApply,
                child: const Text('套用登記地址'),
              ),
            TextButton(onPressed: onKeep, child: const Text('保留目前地址')),
          ] else
            OutlinedButton(
              onPressed: onRequestChange,
              child: const Text('申請修改為登記地址'),
            ),
        ],
      ),
    );
  }

  String _comparisonLabel(String value) {
    switch (value) {
      case 'match':
        return '相符';
      case 'mismatch':
        return '明顯差異';
      case 'manual':
        return '需人工確認';
      default:
        return '無法比對';
    }
  }
}
