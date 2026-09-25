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

class DiscountCampaignTypePickerPage extends StatefulWidget {
  const DiscountCampaignTypePickerPage({super.key, this.onPicked});

  final ValueChanged<DiscountCampaignType>? onPicked;

  @override
  State<DiscountCampaignTypePickerPage> createState() =>
      _DiscountCampaignTypePickerPageState();
}

class _DiscountCampaignTypePickerPageState
    extends State<DiscountCampaignTypePickerPage> {
  DiscountCampaignType? _selected;

  @override
  Widget build(BuildContext context) {
    final DiscountCampaignTypeMeta? selectedMeta = _selected == null
        ? null
        : DiscountCampaignTypeMeta.of(_selected!);
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('建立優惠活動'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns = constraints.maxWidth >= 720 ? 3 : 2;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '選擇優惠類型',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '選擇後只會顯示此類型需要設定的欄位。',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _TypeGrid(
                    columns: columns,
                    selected: _selected,
                    onSelect: (DiscountCampaignType type) {
                      setState(() {
                        _selected = type;
                      });
                    },
                  ),
                ),
                if (selectedMeta != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    '已選：${selectedMeta.title}｜${selectedMeta.serviceSummary}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: selectedMeta == null
                        ? null
                        : () {
                            final DiscountCampaignType type = selectedMeta.type;
                            if (widget.onPicked != null) {
                              widget.onPicked!(type);
                            } else {
                              Navigator.pop(context, type);
                            }
                          },
                    child: const Text('下一步設定'),
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
    required this.selected,
    required this.onSelect,
  });

  final int columns;
  final DiscountCampaignType? selected;
  final ValueChanged<DiscountCampaignType> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<DiscountCampaignTypeMeta> items =
        DiscountCampaignTypeMeta.selectable;
    final int rows = (items.length / columns).ceil();
    return Column(
      children: <Widget>[
        for (int row = 0; row < rows; row++) ...<Widget>[
          if (row > 0) const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: <Widget>[
                for (int col = 0; col < columns; col++) ...<Widget>[
                  if (col > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _typeCard(
                      items[row * columns + col],
                      selected: selected == items[row * columns + col].type,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _typeCard(DiscountCampaignTypeMeta meta, {required bool selected}) {
    return Material(
      color: selected ? meta.tint : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onSelect(meta.type),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? meta.accent : const Color(0xFFE0E0E0),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(meta.icon, color: meta.accent),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.check_circle, color: meta.accent, size: 20)
                  else
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                meta.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  meta.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: <Widget>[
                  _badge(meta.badge, meta.accent, meta.tint),
                  if (meta.footnote.isNotEmpty)
                    Text(
                      meta.footnote,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ],
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}
