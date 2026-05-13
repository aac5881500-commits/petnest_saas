// lib/features/shop/widgets/booking/booking_room_type_section.dart
// 🔥 前台預約房型選擇區：顯示可預約房型、剩餘房數、價格與選取狀態// lib/features/shop/widgets/booking/booking_room_type_section.dart
// 🔥 前台預約房型選擇區：顯示可預約房型、剩餘房數、價格與選取狀態

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/room_type_detail_page.dart';

class BookingRoomTypeSection extends StatelessWidget {
  const BookingRoomTypeSection({
    super.key,
    required this.shopId,
    required this.startDate,
    required this.endDate,
    required this.selectedPetIds,
    required this.selectedRoomType,
    required this.onSelectRoomType,
  });

  final String shopId;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> selectedPetIds;
  final Map<String, dynamic>? selectedRoomType;
  final ValueChanged<Map<String, dynamic>> onSelectRoomType;

  @override
  Widget build(BuildContext context) {
    if (startDate == null || endDate == null) {
      return const SizedBox();
    }

    if (selectedPetIds.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '請先選擇入住寵物',
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ShopService.instance.getAvailableRoomTypes(
        shopId: shopId,
        startDate: startDate!,
        endDate: endDate!,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final roomTypes = (snapshot.data ?? []).where((type) {
          final capacity = (type['capacity'] ?? 1) as int;
          final availableRooms = (type['availableRooms'] ?? 0) as int;

          if (capacity < selectedPetIds.length) return false;
          if (availableRooms <= 0) return false;

          return true;
        }).toList();

        if (roomTypes.isEmpty) {
          return const Text('此區間沒有可用房型');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '第三步：選擇房型',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            ...roomTypes.map((type) {
              final isSelected =
                  selectedRoomType?['roomTypeId'] == type['roomTypeId'];

              return GestureDetector(
                onTap: () {
                  onSelectRoomType(type);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoomTypeDetailPage(
                        roomType: type,
                        startDate: startDate!,
                        endDate: endDate!,
                      ),
                    ),
                  );
                },
                child: Card(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.green
                            : Colors.grey.shade300,
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

                                  if (rooms <= 1) {
                                    return const Text(
                                      '🔥 剩 1 間',
                                      style: TextStyle(color: Colors.red),
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

                            final petCount = selectedPetIds.length;
                            final extraCount =
                                petCount > 1 ? petCount - 1 : 0;

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