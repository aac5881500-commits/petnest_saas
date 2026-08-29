// lib/features/shop/widgets/booking/booking_room_type_section.dart
// 🔥 前台預約房型選擇區：顯示可預約房型、剩餘房數、價格與選取狀態

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/room_type_detail_page.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class BookingRoomTypeSection extends StatefulWidget {
  const BookingRoomTypeSection({
    super.key,
    required this.shopId,
    required this.startDate,
    required this.endDate,
    required this.selectedPetIds,
    required this.selectedRoomType,
    required this.onSelectRoomType,
    required this.theme,
  });

  final String shopId;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> selectedPetIds;
  final Map<String, dynamic>? selectedRoomType;
  final ValueChanged<Map<String, dynamic>> onSelectRoomType;
  final HomeThemeModel theme;

  @override
  State<BookingRoomTypeSection> createState() => _BookingRoomTypeSectionState();
}

class _BookingRoomTypeSectionState extends State<BookingRoomTypeSection> {
  Future<List<Map<String, dynamic>>>? _roomsFuture;

  @override
  void initState() {
    super.initState();
    _roomsFuture = _createRoomsFuture();
  }

  @override
  void didUpdateWidget(BookingRoomTypeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool datesChanged =
        oldWidget.shopId != widget.shopId ||
        oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate;
    if (datesChanged) {
      _roomsFuture = _createRoomsFuture();
    }
  }

  Future<List<Map<String, dynamic>>>? _createRoomsFuture() {
    if (widget.startDate == null || widget.endDate == null) {
      return null;
    }

    return ShopService.instance.getAvailableRoomTypes(
      shopId: widget.shopId,
      startDate: widget.startDate!,
      endDate: widget.endDate!,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.startDate == null || widget.endDate == null) {
      return const SizedBox();
    }

    if (widget.selectedPetIds.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('請先選擇入住寵物', style: TextStyle(color: Colors.red)),
      );
    }

    final Future<List<Map<String, dynamic>>>? roomsFuture = _roomsFuture;
    if (roomsFuture == null) {
      return const SizedBox();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: roomsFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final List<Map<String, dynamic>> roomTypes =
            (snapshot.data ?? <Map<String, dynamic>>[]).where((
              Map<String, dynamic> type,
            ) {
          final int capacity = (type['capacity'] ?? 1) as int;
          return capacity >= widget.selectedPetIds.length;
        }).toList();

        if (roomTypes.isEmpty) {
          return const Text('此區間沒有可用房型');
        }

        final bool hasAvailableRoomType = roomTypes.any((
          Map<String, dynamic> type,
        ) {
          final int availableRooms = (type['availableRooms'] ?? 0) as int;
          return availableRooms > 0;
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '第三步：選擇房型',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (!hasAvailableRoomType) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: const Text(
                  '此日期區間所有可入住的房型都已滿，請重新選擇日期。',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            ...roomTypes.map((Map<String, dynamic> type) {
              final int availableRooms = (type['availableRooms'] ?? 0) as int;
              final bool isFull = availableRooms <= 0;
              final bool isSelected =
                  !isFull &&
                  widget.selectedRoomType?['roomTypeId'] == type['roomTypeId'];

              return GestureDetector(
                onTap: isFull
                    ? null
                    : () {
                        widget.onSelectRoomType(type);
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => RoomTypeDetailPage(
                              shopId: widget.shopId,
                              roomType: type,
                              startDate: widget.startDate!,
                              endDate: widget.endDate!,
                              theme: widget.theme,
                            ),
                          ),
                        );
                      },
                child: Card(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isFull ? Colors.grey.shade100 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type['name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('容量：${type['capacity']}'),
                              const SizedBox(height: 6),
                              Builder(
                                builder: (_) {
                                  final rooms = type['availableRooms'] ?? 0;
                                  if (rooms <= 0) {
                                    return const Text(
                                      '已滿',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  }
                                  if (rooms <= 1) {
                                    return const Text(
                                      '⚠ 即將滿房',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  }
                                  return Text('剩 $rooms 間');
                                },
                              ),
                            ],
                          ),
                        ),
                        Builder(
                          builder: (_) {
                            final basePrice = type['price'] ?? 0;
                            final extraPrice = type['extraPrice'] ?? 0;
                            final int petCount = widget.selectedPetIds.length;
                            final int extraCount = petCount > 1 ? petCount - 1 : 0;
                            final totalPrice =
                                basePrice + (extraCount * extraPrice);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'NT\$ $basePrice',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (extraCount > 0 && extraPrice > 0)
                                  Text(
                                    '+$extraCount隻 +$extraPrice',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                                Text(
                                  '共 NT\$ $totalPrice',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
