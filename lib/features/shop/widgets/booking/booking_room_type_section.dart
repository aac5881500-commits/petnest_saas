import 'booking_room_type_options.dart';
// 檔案名稱：lib/features/shop/widgets/booking/booking_room_type_section.dart
// 功能說明：前台預約房型選擇區：顯示可預約房型、剩餘房數、價格與選取狀態

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
    this.onAdjustSelection,
  });

  final String shopId;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> selectedPetIds;
  final Map<String, dynamic>? selectedRoomType;
  final ValueChanged<Map<String, dynamic>> onSelectRoomType;
  final HomeThemeModel theme;
  final VoidCallback? onAdjustSelection;

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
        oldWidget.endDate != widget.endDate ||
        oldWidget.selectedPetIds.length != widget.selectedPetIds.length;
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
      petCount: widget.selectedPetIds.length,
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

            if (snapshot.hasError) {
              return const Text(
                '暫時無法取得房間剩餘狀態',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              );
            }

            return BookingRoomTypeOptions(
              roomTypes: snapshot.data ?? const [],
              petCount: widget.selectedPetIds.length,
              selectedRoomTypeId: widget.selectedRoomType?['roomTypeId']
                  ?.toString(),
              theme: theme,
              onAdjustSelection: widget.onAdjustSelection,
              onSelect: (type) {
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
            );
          },
    );
  }
}
