import 'package:flutter/material.dart';

import '../../core/models/booking_medication_task.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/shop_task_center_service.dart';
import 'medication_widgets.dart';
import '../../core/services/booking_settlement_math.dart';
import '../admin/widgets/admin_internal_handover_card.dart';

class MedicationTaskPage extends StatefulWidget {
  const MedicationTaskPage({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.taskId,
    this.scheduledAt = '',
  });

  const MedicationTaskPage.arrangement({
    super.key,
    required this.shopId,
    required this.bookingId,
  }) : taskId = null,
       scheduledAt = '';

  final String shopId, bookingId, scheduledAt;
  final String? taskId;

  @override
  State<MedicationTaskPage> createState() => _MedicationTaskPageState();
}

class _MedicationTaskPageState extends State<MedicationTaskPage> {
  late final _access = ShopTaskCenterService.instance.loadAccess(widget.shopId);
  late final _booking = BookingService.instance.streamBooking(widget.bookingId);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.taskId == null ? '用藥交接與安排' : '填寫用藥結果')),
    body: FutureBuilder<ShopTaskAccess>(
      future: _access,
      builder: (context, access) {
        if (access.hasError) return const Center(child: Text('無法驗證店家權限'));
        if (!access.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!access.data!.canViewBookings) {
          return const Center(child: Text('你沒有操作這筆用藥的權限'));
        }
        return StreamBuilder<Map<String, dynamic>?>(
          stream: _booking,
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('無法讀取這筆用藥'));
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final booking = snapshot.data;
            if (booking == null || booking['shopId'] != widget.shopId) {
              return const Center(child: Text('找不到這筆用藥'));
            }
            if (widget.scheduledAt.isNotEmpty &&
                !BookingMedicationTask.fromBooking(booking).any(
                  (task) =>
                      task.id == widget.taskId &&
                      task.scheduledAt.isAtSameMomentAs(
                        DateTime.tryParse(widget.scheduledAt) ??
                            DateTime.utc(1970),
                      ),
                )) {
              return const Center(child: Text('這個用藥時段已變更，請回今日待辦查看'));
            }
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      if (widget.taskId == null)
                        AdminInternalHandoverCard(
                          shopId: widget.shopId,
                          bookingId: widget.bookingId,
                          compact: true,
                          readOnly: BookingSettlementMath.isSettlementLocked(
                            booking,
                          ),
                        ),
                      if (widget.taskId == null)
                        Card.outlined(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            leading: const Icon(Icons.calendar_month_outlined),
                            title: const Text(
                              '時程與費用',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: const Text('查看各貓咪的預約時段與用藥費'),
                            children: [
                              BookingMedicationPanel(
                                bookingId: widget.bookingId,
                                booking: booking,
                                staff: true,
                                arrangementLayout: true,
                              ),
                            ],
                          ),
                        )
                      else ...[
                        BookingMedicationPanel(
                          bookingId: widget.bookingId,
                          booking: booking,
                          staff: true,
                          taskId: widget.taskId,
                        ),
                        Card(
                          child: ExpansionTile(
                            title: const Text('查看用藥交接備註'),
                            children: [
                              AdminInternalHandoverCard(
                                shopId: widget.shopId,
                                bookingId: widget.bookingId,
                                compact: true,
                                readOnly: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
