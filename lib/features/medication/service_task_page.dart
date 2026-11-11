import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../core/models/booking_service_task.dart';
import 'care_actual_time_field.dart';
import '../../core/models/booking_medication_task.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/shop_task_center_service.dart';

class ServiceTaskPage extends StatefulWidget {
  const ServiceTaskPage({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.taskId,
    required this.scheduledAt,
  });
  final String shopId, bookingId, taskId, scheduledAt;
  @override
  State<ServiceTaskPage> createState() => _ServiceTaskPageState();
}

class _ServiceTaskPageState extends State<ServiceTaskPage> {
  late final _access = ShopTaskCenterService.instance.loadAccess(widget.shopId);
  late final _booking = BookingService.instance.streamBooking(widget.bookingId);
  final _note = TextEditingController();
  String? _result;
  late final DateTime _scheduled = DateTime.parse(widget.scheduledAt);
  late DateTime _actual = initialCareActualTime(_scheduled, DateTime.now());
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_result == null || (_result != 'done' && _note.text.trim().isEmpty)) {
      setState(() => _error = '請選擇結果；未完整執行時，請說明原因與後續安排。');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirebaseFunctions.instanceFor(
        region: 'asia-east1',
      ).httpsCallable('recordBookingServiceTask').call({
        'bookingId': widget.bookingId,
        'taskId': widget.taskId,
        'scheduledAt': widget.scheduledAt,
        'result': _result,
        'note': _note.text.trim(),
        'actualAt': _actual.toUtc().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('結果已儲存，客戶訂單已同步更新')));
      setState(() => _saving = false);
      Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _error = serviceResultErrorMessage(e));
      }
    } catch (_) {
      if (mounted) setState(() => _error = '無法儲存，請檢查連線後再試');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('填寫服務結果')),
      body: FutureBuilder<ShopTaskAccess>(
        future: _access,
        builder: (context, access) {
          if (access.hasError) return const Center(child: Text('無法驗證權限，請返回重試'));
          if (!access.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!access.data!.canViewBookings) {
            return const Center(child: Text('你沒有照護執行權限'));
          }
          return StreamBuilder<Map<String, dynamic>?>(
            stream: _booking,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('無法讀取訂單，請返回重試'));
              }
              if (!snapshot.hasData) {
                return const Center(child: Text('正在讀取或訂單已不存在'));
              }
              final b = snapshot.data!;
              if (b['shopId'] != widget.shopId) {
                return const Center(child: Text('找不到這筆服務'));
              }
              final task = BookingServiceTask.fromBooking(b)
                  .where(
                    (t) =>
                        t.id == widget.taskId &&
                        t.scheduledAt.isAtSameMomentAs(
                          DateTime.tryParse(widget.scheduledAt) ??
                              DateTime.utc(1970),
                        ),
                  )
                  .firstOrNull;
              if (task == null) {
                return const Center(child: Text('時程已變更，請回待辦重新開啟'));
              }
              final writable =
                  BookingServiceTask.canRecord(b) &&
                  task.pending &&
                  task.petId.isNotEmpty;
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 640,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        task.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('${task.pet} · ${b['roomName'] ?? '尚未分房'}'),
                      Text(
                        '${task.day}　${task.slot}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 20),
                      if (!writable) ...[
                        Text(
                          task.petId.isEmpty
                              ? '寵物資料待核對，請先與家長確認'
                              : task.pending
                              ? '訂單目前不可填寫'
                              : task.resultLabel,
                        ),
                        if (task.actualAt case final time?)
                          Text(
                            '實際 ${task.day} ${BookingMedicationTask.timeLabel(time)}',
                          ),
                        Text('${task.record['note'] ?? ''}'),
                      ] else ...[
                        const Text(
                          '本次執行結果',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in const {
                              'done': '已完成',
                              'partial': '部分完成',
                              'skipped': '未執行',
                            }.entries)
                              ChoiceChip(
                                label: Text(entry.value),
                                selected: _result == entry.key,
                                onSelected: _saving
                                    ? null
                                    : (_) =>
                                          setState(() => _result = entry.key),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CareActualTimeField(
                          scheduledAt: _scheduled,
                          value: _actual,
                          enabled: !_saving,
                          onChanged: (value) => setState(() => _actual = value),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _note,
                          enabled: !_saving,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 1000,
                          decoration: InputDecoration(
                            labelText: _result == 'done'
                                ? '給家長的說明（選填）'
                                : '原因與後續安排（必填）',
                            hintText: '例如：陪玩 15 分鐘後休息，已與家長說明。',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '儲存後會同步顯示在客戶訂單並發送通知；有包含照護回報時，也會自動帶入同日回報。結果送出後不可覆寫，請核對寵物與時段。',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '部分完成或未執行不會自動改價或退款，請另外確認費用與後續安排。',
                          style: TextStyle(color: Color(0xFF8A4C16)),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.check),
                          label: Text(_saving ? '正在儲存…' : '確認結果並同步給客戶'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}

String serviceResultErrorMessage(FirebaseFunctionsException error) {
  if (const {
    'internal',
    'unavailable',
    'deadline-exceeded',
  }.contains(error.code)) {
    return '暫時無法確認儲存結果。請返回訂單查看是否已有紀錄，再重試；若持續發生，請聯繫管理員。';
  }
  if (error.code == 'unauthenticated') return '登入已逾時，請重新登入後再填寫。';
  return error.message ?? '無法儲存結果，請返回訂單重新開啟。';
}
