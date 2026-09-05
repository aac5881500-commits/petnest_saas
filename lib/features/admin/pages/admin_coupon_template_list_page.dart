// 檔案名稱：lib/features/admin/pages/admin_coupon_template_list_page.dart
// 功能說明：顯示店家建立的優惠券模板，並支援開啟、停用與刪除。
// 🎟️ 後台優惠券模板列表頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/coupon_template_model.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/services/coupon_template_service.dart';
import 'package:petnest_saas/features/admin/pages/admin_coupon_template_form_page.dart';

class AdminCouponTemplateListPage extends StatelessWidget {
  const AdminCouponTemplateListPage({super.key, required this.shopId});

  final String shopId;

  Future<void> _openCreatePage(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) {
          return AdminCouponTemplateFormPage(shopId: shopId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text('優惠券製作')),
      body: StreamBuilder<List<CouponTemplateModel>>(
        stream: CouponTemplateService.instance.streamTemplates(shopId: shopId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<CouponTemplateModel>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _buildErrorState(context, snapshot.error);
              }

              final List<CouponTemplateModel> templates =
                  snapshot.data ?? const <CouponTemplateModel>[];

              if (templates.isEmpty) {
                return _buildEmptyState(context);
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: templates.length,
                separatorBuilder: (BuildContext context, int index) {
                  return const SizedBox(height: 12);
                },
                itemBuilder: (BuildContext context, int index) {
                  final CouponTemplateModel template = templates[index];

                  return _CouponTemplateCard(
                    shopId: shopId,
                    template: template,
                  );
                },
              );
            },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openCreatePage(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('製作優惠券'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
              '尚未製作優惠券',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '先製作優惠券模板，之後才能用於手動發送、點數兌換或新會員贈券。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                _openCreatePage(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('製作第一張優惠券'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              '優惠券模板讀取失敗',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? '發生未知錯誤',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponTemplateCard extends StatefulWidget {
  const _CouponTemplateCard({required this.shopId, required this.template});

  final String shopId;
  final CouponTemplateModel template;

  @override
  State<_CouponTemplateCard> createState() {
    return _CouponTemplateCardState();
  }
}

class _CouponTemplateCardState extends State<_CouponTemplateCard> {
  bool _isUpdating = false;
  Future<void> _openEditPage() async {
    if (_isUpdating) {
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) {
          return AdminCouponTemplateFormPage(
            shopId: widget.shopId,
            template: widget.template,
          );
        },
      ),
    );
  }

  Future<void> _updateEnabled(bool enabled) async {
    if (_isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await CouponTemplateService.instance.updateEnabled(
        shopId: widget.shopId,
        templateId: widget.template.id,
        enabled: enabled,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    if (_isUpdating) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('刪除優惠券模板'),
          content: Text(
            '確定要刪除「${widget.template.name}」嗎？\n\n'
            '已經發給會員的優惠券不會被刪除。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await CouponTemplateService.instance.deleteTemplate(
        shopId: widget.shopId,
        templateId: widget.template.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('優惠券模板已刪除'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }

  @override
  Widget build(BuildContext context) {
    final CouponTemplateModel template = widget.template;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: template.enabled ? 1 : 0.65,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: template.enabled
                ? Colors.grey.shade200
                : Colors.grey.shade300,
          ),
        ),
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
                    color: _typeColor(template.type).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _typeIcon(template.type),
                    color: _typeColor(template.type),
                  ),
                ),
                const SizedBox(width: 12),
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
                          _buildStatusBadge(template.enabled),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _couponValueText(template),
                        style: TextStyle(
                          color: _typeColor(template.type),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (template.description.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                template.description.trim(),
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildInfoChip(
                  Icons.layers_outlined,
                  _applyTargetText(template.applyTarget),
                ),
                if (template.type == MemberCouponType.freeService &&
                    template.serviceName.trim().isNotEmpty)
                  _buildInfoChip(
                    Icons.room_service_outlined,
                    template.serviceName.trim(),
                  ),
                if (template.type == MemberCouponType.percent &&
                    template.maximumDiscountAmount > 0)
                  _buildInfoChip(
                    Icons.price_check_outlined,
                    '最高折 \$${template.maximumDiscountAmount}',
                  ),
                _buildInfoChip(
                  Icons.calendar_today_outlined,
                  template.validDays > 0
                      ? '領取後 ${template.validDays} 天有效'
                      : '永久有效',
                ),
                if (template.minimumAmount > 0)
                  _buildInfoChip(
                    Icons.payments_outlined,
                    '最低消費 \$${template.minimumAmount}',
                  ),
                if (template.roomTypeIds.isNotEmpty)
                  _buildInfoChip(
                    Icons.meeting_room_outlined,
                    '限 ${template.roomTypeIds.length} 種房型',
                  )
                else if (template.type != MemberCouponType.freeService)
                  _buildInfoChip(Icons.meeting_room_outlined, '不限房型'),
                _buildInfoChip(
                  Icons.replay_outlined,
                  '每張可用 ${template.usageLimit} 次',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            Row(
              children: <Widget>[
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      template.enabled ? '已開放' : '已停用',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: template.enabled,
                    onChanged: _isUpdating ? null : _updateEnabled,
                  ),
                ),
                IconButton(
                  tooltip: '編輯',
                  onPressed: _isUpdating ? null : _openEditPage,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '刪除',
                  onPressed: _isUpdating ? null : _confirmDelete,
                  color: Colors.redAccent,
                  icon: _isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: enabled ? Colors.green.shade50 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        enabled ? '使用中' : '已停用',
        style: TextStyle(
          color: enabled ? Colors.green.shade700 : Colors.grey.shade700,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _couponValueText(CouponTemplateModel template) {
    switch (template.type) {
      case MemberCouponType.fixedAmount:
        return '折抵 \$${_formatNumber(template.discountValue)}';

      case MemberCouponType.percent:
        final num payPercent = 100 - template.discountValue;

        if (payPercent > 0 && payPercent < 100) {
          return '${_formatNumber(payPercent)} 折';
        }

        return '折抵 ${_formatNumber(template.discountValue)}%';

      case MemberCouponType.freeStay:
        return '免費住宿 ${template.freeStayNights} 晚';

      case MemberCouponType.freeService:
        return template.serviceName.trim().isEmpty
            ? '免費指定服務'
            : '免費 ${template.serviceName.trim()}';
    }
  }

  String _formatNumber(num number) {
    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toString();
  }

  String _applyTargetText(MemberCouponApplyTarget target) {
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
        return Icons.attach_money;

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
        return Colors.blue;

      case MemberCouponType.percent:
        return Colors.deepOrange;

      case MemberCouponType.freeStay:
        return Colors.purple;

      case MemberCouponType.freeService:
        return Colors.teal;
    }
  }
}
