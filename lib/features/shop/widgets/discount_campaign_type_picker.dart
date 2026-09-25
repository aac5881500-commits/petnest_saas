// 檔案名稱：lib/features/shop/widgets/discount_campaign_type_picker.dart
// 功能說明：建立優惠活動時以卡片網格選擇類型，不使用清單式 bottom sheet。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/discount_campaign_model.dart';

class DiscountCampaignTypeMeta {
  const DiscountCampaignTypeMeta({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.tint,
    required this.accent,
    required this.serviceSummary,
    this.footnote = '',
    this.allowsDaycare = true,
  });

  final DiscountCampaignType type;
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color tint;
  final Color accent;
  final String serviceSummary;
  final String footnote;
  final bool allowsDaycare;

  static const List<DiscountCampaignTypeMeta> selectable =
      <DiscountCampaignTypeMeta>[
        DiscountCampaignTypeMeta(
          type: DiscountCampaignType.newMember,
          title: '新會員優惠',
          subtitle: '提供新加入會員的首筆優惠',
          badge: '住宿、安親可用',
          icon: Icons.person_add_alt_1_outlined,
          tint: Color(0xFFE3F2FD),
          accent: Color(0xFF1565C0),
          serviceSummary: '住宿與安親皆可設定',
        ),
        DiscountCampaignTypeMeta(
          type: DiscountCampaignType.longStay,
          title: '長住優惠',
          subtitle: '入住達指定晚數後自動折抵',
          badge: '僅住宿',
          icon: Icons.hotel_outlined,
          tint: Color(0xFFE8EAF6),
          accent: Color(0xFF3949AB),
          serviceSummary: '僅住宿，安親不適用',
          footnote: '安親不適用',
          allowsDaycare: false,
        ),
        DiscountCampaignTypeMeta(
          type: DiscountCampaignType.stayDate,
          title: '指定服務日期優惠',
          subtitle: '指定住宿或安親服務日期享優惠',
          badge: '住宿、安親可用',
          icon: Icons.calendar_month_outlined,
          tint: Color(0xFFFFF3E0),
          accent: Color(0xFFEF6C00),
          serviceSummary: '住宿與安親皆可設定',
        ),
        DiscountCampaignTypeMeta(
          type: DiscountCampaignType.roomType,
          title: '指定房型／安親方案優惠',
          subtitle: '指定住宿房型或安親方案才可套用',
          badge: '依服務選擇',
          icon: Icons.meeting_room_outlined,
          tint: Color(0xFFF3E5F5),
          accent: Color(0xFF7B1FA2),
          serviceSummary: '依服務選擇住宿房型或安親方案',
        ),
        DiscountCampaignTypeMeta(
          type: DiscountCampaignType.minimumAmount,
          title: '滿額優惠',
          subtitle: '訂單達指定金額後自動折抵',
          badge: '住宿、安親可用',
          icon: Icons.account_balance_wallet_outlined,
          tint: Color(0xFFE8F5E9),
          accent: Color(0xFF2E7D32),
          serviceSummary: '住宿與安親皆可設定',
        ),
        DiscountCampaignTypeMeta(
          type: DiscountCampaignType.limitedTime,
          title: '限時下單優惠',
          subtitle: '在指定下單期間建立訂單即可使用',
          badge: '住宿、安親可用',
          icon: Icons.schedule_outlined,
          tint: Color(0xFFFFF8E1),
          accent: Color(0xFFF9A825),
          serviceSummary: '住宿與安親皆可設定',
        ),
      ];

  static DiscountCampaignTypeMeta of(DiscountCampaignType type) {
    for (final DiscountCampaignTypeMeta item in selectable) {
      if (item.type == type) {
        return item;
      }
    }
    return DiscountCampaignTypeMeta(
      type: type,
      title: 'Google 評論優惠',
      subtitle: '完成評論驗證後可套用',
      badge: '既有活動',
      icon: Icons.reviews_outlined,
      tint: Color(0xFFF5F5F5),
      accent: Color(0xFF616161),
      serviceSummary: '依原活動設定',
    );
  }
}

class DiscountCampaignTypePickerPage extends StatelessWidget {
  const DiscountCampaignTypePickerPage({
    super.key,
    this.onPicked,
    this.onDismiss,
  });

  final ValueChanged<DiscountCampaignType>? onPicked;
  final VoidCallback? onDismiss;

  void _pick(BuildContext context, DiscountCampaignType type) {
    if (onPicked != null) {
      onPicked!(type);
      return;
    }
    Navigator.pop(context, type);
  }

  void _close(BuildContext context) {
    if (onDismiss != null) {
      onDismiss!();
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          '建立優惠活動',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '關閉',
          onPressed: () => _close(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool desktop = constraints.maxWidth >= 720;
          final int columns = desktop ? 3 : 2;
          final double cardHeight = desktop ? 158 : 150;
          final double contentWidth = (constraints.maxWidth - 32)
              .clamp(0, double.infinity)
              .toDouble();
          final double gridWidth = desktop && contentWidth > 960
              ? 960
              : contentWidth;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '選擇優惠類型',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '選擇後只會顯示此類型需要設定的欄位。',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: gridWidth,
                  child: _TypeGrid(
                    columns: columns,
                    cardHeight: cardHeight,
                    onSelect: (DiscountCampaignType type) =>
                        _pick(context, type),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TypeGrid extends StatelessWidget {
  const _TypeGrid({
    required this.columns,
    required this.cardHeight,
    required this.onSelect,
  });

  final int columns;
  final double cardHeight;
  final ValueChanged<DiscountCampaignType> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<DiscountCampaignTypeMeta> items =
        DiscountCampaignTypeMeta.selectable;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: cardHeight,
      ),
      itemBuilder: (BuildContext context, int index) {
        return _TypeCard(meta: items[index], onSelect: onSelect);
      },
    );
  }
}

class _TypeCard extends StatefulWidget {
  const _TypeCard({required this.meta, required this.onSelect});

  final DiscountCampaignTypeMeta meta;
  final ValueChanged<DiscountCampaignType> onSelect;

  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final DiscountCampaignTypeMeta meta = widget.meta;
    final bool active = _hover || _pressed;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: active ? meta.tint : Colors.white,
        elevation: _hover ? 1 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onHighlightChanged: (bool value) => setState(() => _pressed = value),
          onTap: () => widget.onSelect(meta.type),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? meta.accent : const Color(0xFFE0E0E0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(meta.icon, color: meta.accent, size: 22),
                const SizedBox(height: 8),
                Text(
                  meta.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    Flexible(child: _badge(meta.badge, meta.accent, meta.tint)),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color accent, Color tint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}
