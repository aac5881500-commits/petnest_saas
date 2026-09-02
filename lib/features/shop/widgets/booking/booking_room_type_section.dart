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
    final HomeThemeModel theme = widget.theme;

    if (widget.startDate == null || widget.endDate == null) {
      return const SizedBox();
    }

    if (widget.selectedPetIds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '請先選擇入住寵物',
          style: TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final Future<List<Map<String, dynamic>>>? roomsFuture = _roomsFuture;
    if (roomsFuture == null) {
      return const SizedBox();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: roomsFuture,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
          ) {
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
              return Text(
                '此區間沒有可用房型',
                style: TextStyle(fontSize: 14, color: theme.textColor),
              );
            }

            final bool hasAvailableRoomType = roomTypes.any((
              Map<String, dynamic> type,
            ) {
              final int availableRooms = (type['availableRooms'] ?? 0) as int;
              return availableRooms > 0;
            });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '選擇房型',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '僅顯示符合寵物數量與所選日期的可用房型。',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                if (!hasAvailableRoomType) ...<Widget>[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: const Text(
                      '此日期區間所有可入住的房型都已滿，請重新選擇日期。',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                ...roomTypes.map((Map<String, dynamic> type) {
                  final int availableRooms =
                      (type['availableRooms'] ?? 0) as int;
                  final bool isFull = availableRooms <= 0;
                  final bool isSelected =
                      !isFull &&
                      widget.selectedRoomType?['roomTypeId'] ==
                          type['roomTypeId'];

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
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isFull ? theme.backgroundColor : theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2E8B47)
                              : theme.cardBorderColor,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  type['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: theme.textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '容量：${type['capacity']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textColor.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Builder(
                                  builder: (_) {
                                    final rooms = type['availableRooms'] ?? 0;
                                    if (rooms <= 0) {
                                      return const Text(
                                        '已滿',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      );
                                    }
                                    if (rooms <= 1) {
                                      return Text(
                                        '即將滿房',
                                        style: TextStyle(
                                          color: theme.primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      );
                                    }
                                    return Text(
                                      '剩 $rooms 間',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.textColor.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    );
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
                              final int extraCount = petCount > 1
                                  ? petCount - 1
                                  : 0;
                              final totalPrice =
                                  basePrice + (extraCount * extraPrice);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Text(
                                    'NT\$ $basePrice',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: theme.textColor,
                                    ),
                                  ),
                                  if (extraCount > 0 && extraPrice > 0)
                                    Text(
                                      '+$extraCount隻 +$extraPrice',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.textColor.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    '每晚 NT\$ $totalPrice',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.textColor.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
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
