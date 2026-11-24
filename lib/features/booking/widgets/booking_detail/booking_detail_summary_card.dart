import 'package:petnest_saas/core/models/booking_medication_task.dart';
import 'package:petnest_saas/core/models/booking_service_task.dart';
// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_summary_card.dart
// 功能說明：訂單狀態摘要：目前狀態、下一步、日期、寵物、房間；可展開完整進度。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_current_room.dart';
import 'package:petnest_saas/features/booking/widgets/booking_current_room_panel.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_progress_timeline.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

class BookingDetailSummaryCard extends StatefulWidget {
  const BookingDetailSummaryCard({
    super.key,
    required this.view,
    required this.onCancel,
    required this.onContactShop,
    this.onRequestRefund,
    this.onOpenCare,
  });

  final BookingDetailViewData view;
  final VoidCallback onCancel;
  final VoidCallback onContactShop;
  final VoidCallback? onRequestRefund;
  final VoidCallback? onOpenCare;

  @override
  State<BookingDetailSummaryCard> createState() =>
      _BookingDetailSummaryCardState();
}

class _BookingDetailSummaryCardState extends State<BookingDetailSummaryCard> {
  bool _expanded = false;
  bool _manualExpanded = false;

  @override
  Widget build(BuildContext context) {
    final BookingDetailViewData view = widget.view;
    final today = BookingMedicationTask.dateKey(
      BookingMedicationTask.taipei(DateTime.now()),
    );
    final medication = BookingMedicationTask.fromBooking(
      view.raw,
    ).where((task) => task.day == today).toList();
    final services = BookingServiceTask.fromBooking(
      view.raw,
    ).where((task) => task.day == today).toList();
    final total = medication.length + services.length;
    final recorded =
        medication.where((task) => !task.pending).length +
        services.where((task) => !task.pending).length;
    return BookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BookingDetailSectionTitle(view.isDaycare ? '安親摘要' : '住宿摘要'),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.durationLabel,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        fontVariations: const [FontVariation('wght', 800)],
                        color: BookingDetailUi.of(context).text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (view.petNames.isNotEmpty)
                      Text(
                        view.petNames,
                        style: TextStyle(
                          color: BookingDetailUi.of(context).muted,
                        ),
                      ),
                  ],
                ),
              ),
              for (final pet in view.petInfos.take(2))
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: BookingDetailSoftNetworkImage(
                    url: pet.photoUrl,
                    width: 64,
                    height: 64,
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          BookingCurrentRoomPanel(
            data: view.raw,
            audience: BookingCurrentRoomAudience.customer,
          ),
          if (view.status == 'cancelled' &&
              view.cancelReason.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '取消原因：${view.cancelReason}',
              style: TextStyle(
                fontSize: BookingDetailUi.captionSize,
                color: BookingDetailUi.of(context).muted,
              ),
            ),
          ],
          if (view.status == 'cancelled' &&
              view.paidCancelNeedsRefundHint) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '付款退款狀態請聯絡店家。',
              style: TextStyle(
                fontSize: BookingDetailUi.captionSize,
                color: BookingDetailUi.of(context).warning,
              ),
            ),
          ],
          if (view.status == 'cancelled' &&
              view.couponReturnedKnown) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              view.couponReturned ? '優惠券已退回' : '優惠券未退回',
              style: TextStyle(
                fontSize: BookingDetailUi.captionSize,
                color: BookingDetailUi.of(context).muted,
              ),
            ),
          ],
          if (view.status == 'cancelled' &&
              view.pointsReturnedKnown) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              view.pointsReturned ? '點數已退回' : '點數未退回',
              style: TextStyle(
                fontSize: BookingDetailUi.captionSize,
                color: BookingDetailUi.of(context).muted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _meta(view.isDaycare ? '安親日期' : '住宿日期', view.dateRangeLabel),
          if (view.isDaycare && view.daycareBillingRuleText.isNotEmpty)
            _meta('計費規則', view.daycareBillingRuleText),
          if (view.isDaycare) ...<Widget>[
            _meta('預約送達', view.formatDaycareDateTime(view.scheduledStartAt)),
            _meta('預約接回', view.formatDaycareDateTime(view.scheduledEndAt)),
            _meta('實際送達／實際開始', view.formatDaycareDateTime(view.actualStartAt)),
            _meta('實際接回／結算完成', view.formatDaycareDateTime(view.actualEndAt)),
          ],
          if (view.isManualOrder) ...<Widget>[
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                setState(() {
                  _manualExpanded = !_manualExpanded;
                });
              },
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: BookingDetailUi.of(context).warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '此訂單由店家代為建立',
                      style: TextStyle(
                        fontSize: BookingDetailUi.captionSize,
                        color: BookingDetailUi.of(context).muted,
                      ),
                    ),
                  ),
                  Icon(
                    _manualExpanded ? Icons.expand_less : Icons.expand_more,
                    color: BookingDetailUi.of(context).muted,
                  ),
                ],
              ),
            ),
            if (_manualExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '可能是電話、現場或合併歷史訂單後同步到您的會員中心。',
                  style: TextStyle(
                    fontSize: BookingDetailUi.captionSize,
                    color: BookingDetailUi.of(context).muted,
                    height: 1.35,
                  ),
                ),
              ),
          ],
          if (view.status == 'checked_in' && total > 0) ...[
            const Divider(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '今日照護進度',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '$recorded / $total 項已記錄',
                  style: TextStyle(
                    color: BookingDetailUi.of(context).muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: recorded / total,
                minHeight: 7,
                color: BookingDetailUi.of(context).primary,
                backgroundColor: BookingDetailUi.of(context).iconSoft,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              leading: Icon(
                Icons.medication_outlined,
                color: BookingDetailUi.of(context).primary,
              ),
              title: const Text('用藥與專屬服務'),
              subtitle: Text(
                '用藥 ${medication.length} 項 · 專屬服務 ${services.length} 項',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onOpenCare,
            ),
          ],
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: <Widget>[
                  Text(
                    _expanded ? '收起訂單進度' : '查看完整進度',
                    style: TextStyle(
                      fontSize: BookingDetailUi.bodySize,
                      color: BookingDetailUi.of(context).primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: BookingDetailUi.of(context).primary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...<Widget>[
            const SizedBox(height: 10),
            BookingDetailProgressTimeline(view: view),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BookingDetailUi.of(
                context,
              ).iconSoft.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '住宿提醒',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BookingDetailUi.of(context).text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  view.nextStepHint,
                  style: TextStyle(
                    fontSize: BookingDetailUi.bodySize,
                    color: BookingDetailUi.of(context).text,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (view.canCancel) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: view.contactShopInsteadOfCancel
                    ? widget.onContactShop
                    : widget.onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: view.contactShopInsteadOfCancel
                      ? BookingDetailUi.of(context).primary
                      : BookingDetailUi.of(context).muted,
                  side: BorderSide(color: BookingDetailUi.of(context).border),
                ),
                child: Text(view.contactShopInsteadOfCancel ? '聯絡店家' : '取消訂單'),
              ),
            ),
          ] else if (view.canRequestRefund) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: widget.onRequestRefund,
                style: OutlinedButton.styleFrom(
                  foregroundColor: BookingDetailUi.of(context).primary,
                  side: BorderSide(color: BookingDetailUi.of(context).border),
                ),
                child: const Text('申請退款'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(String label, String value) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                fontSize: BookingDetailUi.captionSize,
                color: BookingDetailUi.of(context).muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: BookingDetailUi.bodySize,
                color: BookingDetailUi.of(context).text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
