// lib/features/admin/pages/admin_coupon_template_picker_page.dart
// 🎟️ 優惠券模板選擇頁
// 功能：顯示店家目前已啟用的優惠券模板，
// 供點數兌換商品建立或編輯時選擇並回傳完整模板資料。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/coupon_template_model.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/services/coupon_template_service.dart';

class AdminCouponTemplatePickerPage extends StatelessWidget {
  const AdminCouponTemplatePickerPage({
    super.key,
    required this.shopId,
    this.selectedTemplateId = '',
  });

  final String shopId;

  /// 編輯點數商品時，目前已選擇的模板 ID。
  final String selectedTemplateId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text('選擇優惠券模板')),
      body: StreamBuilder<List<CouponTemplateModel>>(
        stream: CouponTemplateService.instance.streamTemplates(
          shopId: shopId,
          enabledOnly: true,
        ),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<CouponTemplateModel>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error);
              }

              final List<CouponTemplateModel> templates =
                  snapshot.data ?? const <CouponTemplateModel>[];

              if (templates.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: templates.length,
                separatorBuilder: (BuildContext context, int index) {
                  return const SizedBox(height: 12);
                },
                itemBuilder: (BuildContext context, int index) {
                  final CouponTemplateModel template = templates[index];

                  return _CouponTemplatePickerCard(
                    template: template,
                    selected: template.id == selectedTemplateId,
                    onTap: () {
                      Navigator.of(context).pop<CouponTemplateModel>(template);
                    },
                  );
                },
              );
            },
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              '讀取優惠券模板失敗',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? '發生未知錯誤',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.confirmation_number_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              '沒有可選擇的優惠券模板',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '請先到「優惠券製作」建立並啟用優惠券模板。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponTemplatePickerCard extends StatelessWidget {
  const _CouponTemplatePickerCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final CouponTemplateModel template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade300;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                backgroundColor: _typeColor(
                  template.type,
                ).withValues(alpha: 0.12),
                child: Icon(
                  _typeIcon(template.type),
                  color: _typeColor(template.type),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            template.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _typeLabel(template.type),
                      style: TextStyle(
                        color: _typeColor(template.type),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _buildRewardDescription(template),
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                    if (template.description.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        template.description.trim(),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _InfoChip(
                          label: template.validDays <= 0
                              ? '永久有效'
                              : '有效 ${template.validDays} 天',
                        ),
                        _InfoChip(label: '可使用 ${template.usageLimit} 次'),
                        _InfoChip(
                          label: _applyTargetLabel(template.applyTarget),
                        ),
                        if (template.roomTypeIds.isNotEmpty)
                          _InfoChip(label: '限指定房型'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _buildRewardDescription(CouponTemplateModel template) {
    switch (template.type) {
      case MemberCouponType.fixedAmount:
        return '折抵 NT\$${_formatNumber(template.discountValue)}';

      case MemberCouponType.percent:
        final num payPercent = 100 - template.discountValue;

        return '折扣 ${_formatNumber(template.discountValue)}%，'
            '會員支付 ${_formatNumber(payPercent)}%';

      case MemberCouponType.freeStay:
        return '免費住宿 ${template.freeStayNights} 晚';

      case MemberCouponType.freeService:
        final String serviceName = template.serviceName.trim();

        if (serviceName.isEmpty) {
          return '免費指定服務';
        }

        return '免費服務：$serviceName';
    }
  }

  String _typeLabel(MemberCouponType type) {
    switch (type) {
      case MemberCouponType.fixedAmount:
        return '固定金額折價券';

      case MemberCouponType.percent:
        return '百分比折扣券';

      case MemberCouponType.freeStay:
        return '免費住宿券';

      case MemberCouponType.freeService:
        return '免費服務券';
    }
  }

  String _applyTargetLabel(MemberCouponApplyTarget target) {
    switch (target) {
      case MemberCouponApplyTarget.room:
        return '僅限房價';

      case MemberCouponApplyTarget.roomAndPet:
        return '房價與寵物費';

      case MemberCouponApplyTarget.total:
        return '整張訂單';

      case MemberCouponApplyTarget.service:
        return '指定服務';
    }
  }

  IconData _typeIcon(MemberCouponType type) {
    switch (type) {
      case MemberCouponType.fixedAmount:
        return Icons.payments_outlined;

      case MemberCouponType.percent:
        return Icons.percent;

      case MemberCouponType.freeStay:
        return Icons.hotel_outlined;

      case MemberCouponType.freeService:
        return Icons.room_service_outlined;
    }
  }

  Color _typeColor(MemberCouponType type) {
    switch (type) {
      case MemberCouponType.fixedAmount:
        return Colors.orange.shade700;

      case MemberCouponType.percent:
        return Colors.deepPurple.shade600;

      case MemberCouponType.freeStay:
        return Colors.blue.shade700;

      case MemberCouponType.freeService:
        return Colors.teal.shade700;
    }
  }

  String _formatNumber(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value.toString();
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
