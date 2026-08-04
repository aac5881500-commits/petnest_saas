// lib/features/shop/pages/shop_discount_campaign_page.dart
// 🏷️ 店家優惠活動管理頁
// 功能：顯示自動優惠活動、切換啟用狀態、刪除活動，
//      並在新增優惠前先選擇優惠類型

import 'package:flutter/material.dart';

import '../../../core/models/discount_campaign_model.dart';
import '../../../core/services/discount_campaign_service.dart';
import '../../../core/services/shop_room_service.dart';
import '../../../shared/widgets/page_help_button.dart';
import 'shop_discount_campaign_form_page.dart';

class ShopDiscountCampaignPage extends StatefulWidget {
  const ShopDiscountCampaignPage({
    super.key,
    required this.shopId,
    this.embedded = false,
  });

  final String shopId;

  /// true：嵌入收款與優惠設定的 Tab，不顯示自己的 AppBar
  /// false：維持原本獨立頁面
  final bool embedded;

  @override
  State<ShopDiscountCampaignPage> createState() =>
      _ShopDiscountCampaignPageState();
}

class _ShopDiscountCampaignPageState extends State<ShopDiscountCampaignPage> {
  final DiscountCampaignService _service = DiscountCampaignService.instance;
  final ShopRoomService _roomService = ShopRoomService.instance;
  String? _processingCampaignId;

  Widget _buildHelpButton() {
    return const PageHelpButton(
      title: '優惠活動使用說明',
      purpose:
          '管理店家的自動優惠活動。建立並啟用活動後，'
          '會員或店家建立訂單時，系統會檢查符合條件的優惠，'
          '並自動選擇折抵金額最高的一個活動。',
      steps: <String>[
        '點擊「新增優惠」，選擇要建立的優惠類型。',
        '填寫優惠名稱、折扣內容與適用條件。',
        '確認設定後儲存，活動會出現在此頁列表。',
        '使用活動右側開關，控制活動是否立即生效。',
        '建立測試訂單，確認優惠名稱、折抵金額與折後總價。',
      ],
      examples: <PageHelpExample>[
        PageHelpExample(
          title: '長住優惠',
          description: '設定入住滿 5 晚享 9 折。',
          lines: <String>['客人住宿 4 晚：不符合優惠。', '客人住宿 5 晚：房價自動套用 9 折。'],
        ),
        PageHelpExample(
          title: '特定住宿日期',
          description: '設定 7/20～7/25 住宿享 85 折。',
          lines: <String>['住宿日期符合活動範圍：自動套用優惠。', '只有下單日在範圍內，但住宿日期不符合：不套用。'],
        ),
        PageHelpExample(
          title: '多個優惠同時符合',
          description: '同一張訂單同時符合長住與滿額優惠。',
          lines: <String>['系統會分別計算每個優惠的折抵金額。', '最後自動套用折抵金額最高的一個優惠。'],
        ),
      ],
      notes: <String>[
        '停用活動後，新建立的訂單不會再套用該活動。',
        '停用或刪除活動，不會重新改變已成立訂單的金額。',
        '同一張訂單目前只會自動套用一個最佳優惠。',
        '住宿日期優惠判斷入住與住宿日期，不是建立訂單日期。',
        '限時下單優惠判斷建立訂單日期，不是住宿日期。',
      ],
    );
  }

  Future<void> _chooseCampaignType() async {
    final DiscountCampaignType?
    selectedType = await showModalBottomSheet<DiscountCampaignType>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '選擇優惠類型',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '選擇後，系統會依照優惠類型顯示需要設定的條件。',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                _CampaignTypeTile(
                  icon: Icons.person_add_alt_1_outlined,
                  title: '新會員優惠',
                  subtitle: '提供新會員指定晚數的房價優惠額度',
                  onTap: () {
                    Navigator.pop(context, DiscountCampaignType.newMember);
                  },
                ),
                _CampaignTypeTile(
                  icon: Icons.hotel_outlined,
                  title: '長住優惠',
                  subtitle: '住宿達到指定晚數後，自動套用優惠',
                  onTap: () {
                    Navigator.pop(context, DiscountCampaignType.longStay);
                  },
                ),
                _CampaignTypeTile(
                  icon: Icons.date_range_outlined,
                  title: '特定住宿日期',
                  subtitle: '指定日期入住或住宿，可享活動優惠',
                  onTap: () {
                    Navigator.pop(context, DiscountCampaignType.stayDate);
                  },
                ),
                _CampaignTypeTile(
                  icon: Icons.meeting_room_outlined,
                  title: '指定房型',
                  subtitle: '只有選擇指定房型時才套用優惠',
                  onTap: () {
                    Navigator.pop(context, DiscountCampaignType.roomType);
                  },
                ),
                _CampaignTypeTile(
                  icon: Icons.payments_outlined,
                  title: '滿額優惠',
                  subtitle: '訂單金額達到指定門檻後自動折扣',
                  onTap: () {
                    Navigator.pop(context, DiscountCampaignType.minimumAmount);
                  },
                ),
                _CampaignTypeTile(
                  icon: Icons.schedule_outlined,
                  title: '限時下單優惠',
                  subtitle: '會員在指定下單期間建立訂單，即可享有優惠',
                  onTap: () {
                    Navigator.pop(context, DiscountCampaignType.limitedTime);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || selectedType == null) {
      return;
    }

    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) {
          return ShopDiscountCampaignFormPage(
            shopId: widget.shopId,
            campaignType: selectedType,
          );
        },
      ),
    );

    if (!mounted || created != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「${_campaignTypeLabel(selectedType)}」已建立完成')),
    );
  }

  Future<void> _setCampaignEnabled({
    required DiscountCampaignModel campaign,
    required bool enabled,
  }) async {
    if (_processingCampaignId != null) {
      return;
    }

    setState(() {
      _processingCampaignId = campaign.id;
    });

    try {
      await _service.setCampaignEnabled(
        shopId: widget.shopId,
        campaignId: campaign.id,
        enabled: enabled,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(enabled ? '已啟用優惠活動' : '已停用優惠活動')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _processingCampaignId = null;
        });
      }
    }
  }

  Future<void> _confirmDeleteCampaign(DiscountCampaignModel campaign) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('刪除優惠活動'),
          content: Text(
            '確定要刪除「${campaign.name}」嗎？\n\n'
            '刪除後無法復原。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('確認刪除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _deleteCampaign(campaign);
  }

  Future<void> _deleteCampaign(DiscountCampaignModel campaign) async {
    if (_processingCampaignId != null) {
      return;
    }

    setState(() {
      _processingCampaignId = campaign.id;
    });

    try {
      await _service.deleteCampaign(
        shopId: widget.shopId,
        campaignId: campaign.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('優惠活動已刪除')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _processingCampaignId = null;
        });
      }
    }
  }

  String _campaignTypeLabel(DiscountCampaignType type) {
    switch (type) {
      case DiscountCampaignType.longStay:
        return '長住優惠';

      case DiscountCampaignType.newMember:
        return '新會員優惠';

      case DiscountCampaignType.googleReview:
        return 'Google 評論優惠';

      case DiscountCampaignType.stayDate:
        return '特定住宿日期';

      case DiscountCampaignType.roomType:
        return '指定房型';

      case DiscountCampaignType.minimumAmount:
        return '滿額優惠';

      case DiscountCampaignType.limitedTime:
        return '限時下單優惠';
    }
  }

  String _valueLabel(DiscountCampaignModel campaign) {
    switch (campaign.valueType) {
      case DiscountValueType.percent:
        final num finalPercent = 100 - campaign.discountValue;
        return finalPercent % 10 == 0
            ? '${(finalPercent / 10).toStringAsFixed(0)} 折'
            : '${(finalPercent / 10).toStringAsFixed(1)} 折';

      case DiscountValueType.fixedAmount:
        return '折抵 \$${campaign.discountValue.toInt()}';
    }
  }

  String _applyTargetLabel(DiscountApplyTarget target) {
    switch (target) {
      case DiscountApplyTarget.room:
        return '只折房價';
      case DiscountApplyTarget.roomAndPet:
        return '房價＋寵物加價';
      case DiscountApplyTarget.total:
        return '整張訂單';
    }
  }

  String _dateText(DateTime? date) {
    if (date == null) {
      return '未限制';
    }

    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '${date.year}/$month/$day';
  }

  @override
  Widget build(BuildContext context) {
    final Widget campaignList = StreamBuilder<List<DiscountCampaignModel>>(
      stream: _service.streamCampaigns(widget.shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<DiscountCampaignModel>> snapshot,
          ) {
            if (snapshot.hasError) {
              return _ErrorState(message: snapshot.error.toString());
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<DiscountCampaignModel> campaigns =
                snapshot.data ?? const <DiscountCampaignModel>[];

            if (campaigns.isEmpty) {
              return _EmptyState(onCreatePressed: _chooseCampaignType);
            }

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _roomService.streamRoomTypes(widget.shopId),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<Map<String, dynamic>>> roomSnapshot,
                  ) {
                    final List<Map<String, dynamic>> roomTypes =
                        roomSnapshot.data ?? const <Map<String, dynamic>>[];

                    final Map<String, String> roomTypeNameMap =
                        <String, String>{
                          for (final Map<String, dynamic> roomType in roomTypes)
                            (roomType['id'] ?? '').toString():
                                (roomType['name'] ?? '未命名房型').toString(),
                        };

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: campaigns.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return const SizedBox(height: 12);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final DiscountCampaignModel campaign = campaigns[index];

                        final List<String> roomTypeNames = campaign.roomTypeIds
                            .map(
                              (String roomTypeId) =>
                                  roomTypeNameMap[roomTypeId],
                            )
                            .whereType<String>()
                            .toList();

                        return _CampaignCard(
                          campaign: campaign,
                          roomTypeNames: roomTypeNames,
                          typeLabel: _campaignTypeLabel(campaign.type),
                          valueLabel: _valueLabel(campaign),
                          applyTargetLabel: _applyTargetLabel(
                            campaign.applyTarget,
                          ),
                          dateRangeLabel:
                              '${_dateText(campaign.startAt)} ～ '
                              '${_dateText(campaign.endAt)}',
                          processing: _processingCampaignId == campaign.id,
                          onEnabledChanged: (bool value) {
                            _setCampaignEnabled(
                              campaign: campaign,
                              enabled: value,
                            );
                          },
                          onDelete: () {
                            _confirmDeleteCampaign(campaign);
                          },
                        );
                      },
                    );
                  },
            );
          },
    );

    final Widget addButton = FloatingActionButton.extended(
      onPressed: _chooseCampaignType,
      icon: const Icon(Icons.add),
      label: const Text('新增優惠'),
    );

    if (widget.embedded) {
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
                  child: Row(
                    children: <Widget>[
                      Text(
                        '管理自動套用的優惠活動',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Spacer(),
                      _buildHelpButton(),
                    ],
                  ),
                ),
                Expanded(child: campaignList),
              ],
            ),
          ),
          Positioned(right: 16, bottom: 16, child: addButton),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('優惠活動管理'),
        actions: <Widget>[_buildHelpButton(), const SizedBox(width: 4)],
      ),
      floatingActionButton: addButton,
      body: campaignList,
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({
    required this.campaign,
    required this.roomTypeNames,
    required this.typeLabel,
    required this.valueLabel,
    required this.applyTargetLabel,
    required this.dateRangeLabel,
    required this.processing,
    required this.onEnabledChanged,
    required this.onDelete,
  });

  final DiscountCampaignModel campaign;
  final List<String> roomTypeNames;
  final String typeLabel;
  final String valueLabel;
  final String applyTargetLabel;
  final String dateRangeLabel;
  final bool processing;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onDelete;
  String? _conditionLabel() {
    switch (campaign.type) {
      case DiscountCampaignType.longStay:
        if (campaign.minimumNights <= 0) {
          return null;
        }

        return '入住滿 ${campaign.minimumNights} 晚';

      case DiscountCampaignType.newMember:
        if (campaign.newMemberDiscountNights <= 0) {
          return '限新會員';
        }

        return '共 ${campaign.newMemberDiscountNights} 晚優惠額度';

      case DiscountCampaignType.googleReview:
        return '完成指定評論條件';

      case DiscountCampaignType.stayDate:
        return '限制住宿日期';

      case DiscountCampaignType.roomType:
        if (roomTypeNames.isNotEmpty) {
          return '指定房型：${roomTypeNames.join('、')}';
        }

        if (campaign.roomTypeIds.isEmpty) {
          return null;
        }

        return '指定 ${campaign.roomTypeIds.length} 種房型';

      case DiscountCampaignType.minimumAmount:
        if (campaign.minimumAmount <= 0) {
          return null;
        }

        return '訂單滿 \$${campaign.minimumAmount}';

      case DiscountCampaignType.limitedTime:
        return '限期內完成下單';
    }
  }

  String _memberUsageLabel() {
    if (campaign.memberUsageLimit <= 0) {
      return '會員不限次數';
    }

    return '每位會員 ${campaign.memberUsageLimit} 次';
  }

  String _totalUsageLabel() {
    if (campaign.totalUsageLimit <= 0) {
      return '活動不限總次數';
    }

    return '活動共 ${campaign.totalUsageLimit} 次';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: campaign.enabled
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_offer_outlined,
                    color: campaign.enabled
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        campaign.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        typeLabel,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                if (processing)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Switch(value: campaign.enabled, onChanged: onEnabledChanged),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoChip(icon: Icons.discount_outlined, label: valueLabel),
                _InfoChip(
                  icon: Icons.account_balance_wallet_outlined,
                  label: applyTargetLabel,
                ),
                if (campaign.valueType == DiscountValueType.percent &&
                    campaign.maximumDiscountAmount > 0)
                  _InfoChip(
                    icon: Icons.price_check_outlined,
                    label: '最高折 \$${campaign.maximumDiscountAmount}',
                  ),
                if (_conditionLabel() != null)
                  _InfoChip(
                    icon: Icons.rule_outlined,
                    label: _conditionLabel()!,
                  ),
                if (campaign.startAt != null || campaign.endAt != null)
                  _InfoChip(
                    icon: campaign.type == DiscountCampaignType.limitedTime
                        ? Icons.schedule_outlined
                        : Icons.calendar_month_outlined,
                    label: dateRangeLabel,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoChip(
                  icon: Icons.person_outline,
                  label: _memberUsageLabel(),
                ),
                _InfoChip(
                  icon: Icons.confirmation_number_outlined,
                  label: _totalUsageLabel(),
                ),
                if (campaign.allowCouponTogether)
                  const _InfoChip(
                    icon: Icons.loyalty_outlined,
                    label: '可搭配折價券',
                  ),
              ],
            ),
            if (campaign.description.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                campaign.description,
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            Row(
              children: <Widget>[
                Text(
                  campaign.enabled ? '目前啟用中' : '目前已停用',
                  style: TextStyle(
                    color: campaign.enabled
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: processing ? null : onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('刪除'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}

class _CampaignTypeTile extends StatelessWidget {
  const _CampaignTypeTile({
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreatePressed});

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.local_offer_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 18),
            const Text(
              '尚未建立優惠活動',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '建立長住、新會員、特定日期或滿額優惠，'
              '符合條件時系統會自動套用。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add),
              label: const Text('建立第一個優惠'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 52, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              '優惠活動讀取失敗',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
