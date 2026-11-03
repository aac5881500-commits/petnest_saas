import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';

class BookingLookEditor extends StatelessWidget {
  const BookingLookEditor({
    super.key,
    required this.look,
    required this.onChanged,
    required this.onReset,
    this.enabled = true,
  });
  final BookingPageLook look;
  final ValueChanged<BookingPageLook> onChanged;
  final VoidCallback onReset;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    Widget colors(
      String label,
      Map<int, String> options,
      int? selected,
      ValueChanged<int?> change,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<int>(
        key: ValueKey('$label-$selected'),
        initialValue: selected ?? 0,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: 0, child: Text('版型預設')),
          ...options.entries.map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Row(
                children: [
                  if (e.key == -1)
                    const Icon(Icons.sync, size: 18)
                  else
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Color(e.key),
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Text(e.value),
                ],
              ),
            ),
          ),
        ],
        onChanged: enabled
            ? (value) => change(value == 0 ? null : value)
            : null,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('本版型配色與字型', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          '各版型分開保存。錯誤提示、停用狀態、插畫與操作順序保持固定。',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 14),
        colors(
          '頁面底色',
          const {-1: '與前台相同', ...BookingPageLook.backgrounds},
          look.followFrontend ? -1 : look.background,
          (v) => onChanged(
            BookingPageLook(
              followFrontend: v == -1,
              background: v == -1 ? look.background : v,
              text: look.text,
              primary: look.primary,
              font: look.font,
            ),
          ),
        ),
        if (look.followFrontend)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              '跟隨前台目前底色；使用圖庫時，沿用同一張圖、位置、縮放與遮罩。',
              style: TextStyle(fontSize: 12),
            ),
          ),
        colors(
          '文字顏色',
          BookingPageLook.texts,
          look.text,
          (v) => onChanged(
            BookingPageLook(
              followFrontend: look.followFrontend,
              background: look.background,
              text: v,
              primary: look.primary,
              font: look.font,
            ),
          ),
        ),
        colors(
          '按鈕與重點色',
          BookingPageLook.primaries,
          look.primary,
          (v) => onChanged(
            BookingPageLook(
              followFrontend: look.followFrontend,
              background: look.background,
              text: look.text,
              primary: v,
              font: look.font,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('booking-font-${look.font}'),
          initialValue: look.font,
          decoration: const InputDecoration(
            labelText: '字型',
            border: OutlineInputBorder(),
          ),
          items: BookingPageLook.fonts.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    e.value,
                    style: TextStyle(fontFamily: e.key.isEmpty ? null : e.key),
                  ),
                ),
              )
              .toList(),
          onChanged: enabled
              ? (v) => onChanged(
                  BookingPageLook(
                    followFrontend: look.followFrontend,
                    background: look.background,
                    text: look.text,
                    primary: look.primary,
                    font: v ?? '',
                  ),
                )
              : null,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: enabled ? onReset : null,
            child: const Text('還原本版型配色與字型'),
          ),
        ),
      ],
    );
  }
}
