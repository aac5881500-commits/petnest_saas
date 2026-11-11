import 'package:flutter/material.dart';

/// Uses the booking's room snapshot; never substitutes another shop's current room.
String memberOrderRoomImageUrl(Map<String, dynamic> data) {
  final images = data['roomImages'];
  final candidates = [
    if (images is List) ...images,
    data['roomImageUrl'],
    data['roomPhotoUrl'],
  ];
  for (final value in candidates) {
    if (value is! String) continue;
    final uri = Uri.tryParse(value.trim());
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty)
      return value.trim();
  }
  return '';
}

class MemberOrderRoomImage extends StatelessWidget {
  const MemberOrderRoomImage({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final url = memberOrderRoomImageUrl(data);
    Widget fallback() => const ColoredBox(
      color: Color(0xFFFFF3E5),
      child: Center(
        child: Icon(Icons.bed_outlined, color: Color(0xFFA96A37), size: 30),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 76,
        height: 92,
        child: url.isEmpty
            ? fallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback(),
                errorBuilder: (_, error, stack) => fallback(),
              ),
      ),
    );
  }
}
