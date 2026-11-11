import 'package:flutter/material.dart';

enum BookingCareLayout {
  grid('時間表＋明細', '桌機按時間與寵物對照，手機改用時間清單', Icons.calendar_view_day_outlined),
  list('時間清單', '依時間由早到晚，適合逐筆處理', Icons.view_agenda_outlined),
  pets('依寵物分組', '同一隻寵物的用藥與服務放在一起', Icons.pets_outlined);

  const BookingCareLayout(this.label, this.description, this.icon);
  final String label, description;
  final IconData icon;
}

class BookingCareDisplay {
  const BookingCareDisplay({
    this.layout = BookingCareLayout.grid,
    this.showPhotos = true,
  });

  final BookingCareLayout layout;
  final bool showPhotos;

  factory BookingCareDisplay.fromStorage(String? stored) {
    final parts = stored?.split('|') ?? const <String>[];
    return BookingCareDisplay(
      layout: BookingCareLayout.values.firstWhere(
        (layout) => layout.name == parts.firstOrNull,
        orElse: () => BookingCareLayout.grid,
      ),
      showPhotos: parts.lastOrNull != 'hide',
    );
  }

  String get storageValue => '${layout.name}|${showPhotos ? 'show' : 'hide'}';
}
