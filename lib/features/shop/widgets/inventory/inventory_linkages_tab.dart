// 檔案名稱：lib/features/shop/widgets/inventory/inventory_linkages_tab.dart
// 功能說明：唯讀顯示這個庫存品項目前被哪些服務或商品消耗。
// 📦 不修改來源設定、不自動停用

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/inventory_linkage_service.dart';

class InventoryLinkagesTab extends StatelessWidget {
  const InventoryLinkagesTab({
    super.key,
    required this.item,
    required this.snapshot,
  });

  final InventoryItemModel item;
  final InventoryLinkageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (!snapshot.ready) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<InventoryLinkage> links = snapshot.of(item.id);
    final int enabledCount = links
        .where((InventoryLinkage link) => link.isEnabled)
        .length;
    final bool risky =
        !snapshot.hasError &&
        enabledCount > 0 &&
        (item.stockStatus == InventoryStockStatus.low ||
            item.stockStatus == InventoryStockStatus.outOfStock);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        if (snapshot.hasError)
          const _Notice(
            icon: Icons.cloud_off_outlined,
            tone: _NoticeTone.muted,
            text: '暫時無法讀取連動資訊。已讀到的來源仍會列出；進貨、出庫與盤點不受影響。',
          ),
        if (risky)
          _Notice(
            icon: item.stockStatus == InventoryStockStatus.outOfStock
                ? Icons.error_outline
                : Icons.warning_amber_rounded,
            tone: item.stockStatus == InventoryStockStatus.outOfStock
                ? _NoticeTone.danger
                : _NoticeTone.warn,
            text: item.stockStatus == InventoryStockStatus.outOfStock
                ? '目前已缺貨，$enabledCount 項啟用中的服務或商品可能無法正常提供。'
                : '目前庫存低於安全庫存，可能影響 $enabledCount 項啟用中的服務或商品。',
          ),
        if (!snapshot.hasError || links.isNotEmpty) ...<Widget>[
          _SummaryRow(
            total: links.length,
            enabledCount: enabledCount,
            disabledCount: links.length - enabledCount,
          ),
          const SizedBox(height: 12),
        ],
        if (links.isEmpty && !snapshot.hasError)
          const _EmptyLinkages()
        else
          for (final _LinkageGroup group in _groups(links))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GroupCard(group: group, unit: item.unit),
            ),
      ],
    );
  }

  List<_LinkageGroup> _groups(List<InventoryLinkage> links) {
    const List<(InventoryLinkageGroup, String)> order =
        <(InventoryLinkageGroup, String)>[
          (InventoryLinkageGroup.addon, '加購服務'),
          (InventoryLinkageGroup.pointReward, '點數實體商品'),
          (InventoryLinkageGroup.storeProduct, '商城商品'),
          (InventoryLinkageGroup.bookingSupply, '住宿／安親耗材'),
        ];
    return <_LinkageGroup>[
      for (final (InventoryLinkageGroup group, String title) in order)
        if (links.any((InventoryLinkage link) => link.group == group))
          _LinkageGroup(
            title: title,
            links: links
                .where((InventoryLinkage link) => link.group == group)
                .toList(),
          ),
    ];
  }
}

enum _NoticeTone { muted, warn, danger }

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.tone, required this.text});

  final IconData icon;
  final _NoticeTone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (tone) {
      _NoticeTone.danger => Colors.red.shade700,
      _NoticeTone.warn => Colors.orange.shade900,
      _NoticeTone.muted => const Color(0xFF667085),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, height: 1.35, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.total,
    required this.enabledCount,
    required this.disabledCount,
  });

  final int total;
  final int enabledCount;
  final int disabledCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        _CountPill(label: '已連動 $total 項'),
        _CountPill(label: '啟用中 $enabledCount 項'),
        _CountPill(label: '已停用 $disabledCount 項'),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyLinkages extends StatelessWidget {
  const _EmptyLinkages();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        children: <Widget>[
          Icon(Icons.link_off, size: 36, color: Colors.grey.shade500),
          const SizedBox(height: 10),
          const Text(
            '此品項尚未連動任何服務或商品',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '可在加購服務、點數實體商品、住宿／安親耗材設定或商城商品中，選擇此中央庫存品項。未連動的品項仍可手動進貨、出庫與盤點。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkageGroup {
  const _LinkageGroup({required this.title, required this.links});

  final String title;
  final List<InventoryLinkage> links;
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.unit});

  final _LinkageGroup group;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              group.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
          for (int index = 0; index < group.links.length; index++) ...<Widget>[
            if (index > 0) const Divider(height: 1),
            _LinkRow(link: group.links[index], unit: unit),
          ],
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link, required this.unit});

  final InventoryLinkage link;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool dim = !link.isEnabled;
    return Opacity(
      opacity: dim ? 0.72 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(_icon, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    link.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${link.typeLabel}・${link.quantityPhrase(unit)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  if (link.extra.trim().isNotEmpty)
                    Text(
                      link.extra,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: link.isEnabled
                    ? colors.primary.withValues(alpha: 0.1)
                    : const Color(0xFFF1F3F6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                link.statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: link.isEnabled
                      ? colors.primary
                      : const Color(0xFF667085),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    switch (link.kind) {
      case InventoryLinkageKind.addonTime:
        return Icons.schedule_outlined;
      case InventoryLinkageKind.addonValue:
        return Icons.auto_awesome_outlined;
      case InventoryLinkageKind.addonCustom:
        return Icons.tune_outlined;
      case InventoryLinkageKind.addonDaily:
        return Icons.today_outlined;
      case InventoryLinkageKind.pointReward:
        return Icons.card_giftcard_outlined;
      case InventoryLinkageKind.storeProduct:
        return Icons.storefront_outlined;
      case InventoryLinkageKind.bookingSupply:
        return Icons.cleaning_services_outlined;
      case InventoryLinkageKind.daycareSupply:
        return Icons.pets_outlined;
    }
  }
}
