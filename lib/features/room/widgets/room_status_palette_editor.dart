import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/room_status_palette.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_color_field.dart';
import 'room_status_legend.dart';

class RoomStatusPaletteEditor extends StatelessWidget {
  const RoomStatusPaletteEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final RoomStatusPalette value;
  final ValueChanged<RoomStatusPalette> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '房況圓點與圖例顏色',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '依照店裡習慣，調整各房況的代表色。儲存後，電腦、手機、工作台與單房月曆都會使用同一套顏色。',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: enabled
                  ? () => onChanged(RoomStatusPalette.defaults)
                  : null,
              icon: const Icon(Icons.restore),
              label: const Text('全部恢復預設'),
            ),
          ),
          for (final entry in RoomStatusPalette.labels.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: enabled
                        ? () async {
                            final picked = await showHomeColorPicker(
                              context,
                              initial: value.color(entry.key),
                            );
                            if (context.mounted && picked != null) {
                              onChanged(
                                value.withColor(entry.key, Color(picked)),
                              );
                            }
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: value.color(entry.key),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Text(value.hex(entry.key)),
                          const SizedBox(width: 6),
                          const Icon(Icons.palette_outlined, size: 16),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '恢復${entry.value}預設色',
                    onPressed: enabled
                        ? () => onChanged(value.reset(entry.key))
                        : null,
                    icon: const Icon(Icons.undo, size: 19),
                  ),
                ],
              ),
            ),
          const Divider(height: 32),
          const Text('圖例預覽', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          RoomStatusLegend(palette: value),
          const SizedBox(height: 12),
          const Text(
            '調整後請按下「儲存設定」；恢復預設也會在儲存後套用。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}
