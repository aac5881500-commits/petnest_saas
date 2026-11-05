import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';

class BookingLookEditor extends StatelessWidget {
  const BookingLookEditor({
    super.key,
    required this.look,
    required this.onChanged,
    required this.onReset,
    this.enabled = true,
    this.showColors = true,
  });
  final BookingPageLook look;
  final ValueChanged<BookingPageLook> onChanged;
  final VoidCallback onReset;
  final bool enabled, showColors;
  @override
  Widget build(BuildContext context) {
    Widget colors(
      String label,
      Map<int, String> options,
      int? selected,
      ValueChanged<int?> change,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            key: ValueKey('$label-$selected'),
            initialValue: selected ?? 0,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: 0, child: Text('版型預設')),
              if (selected != null &&
                  selected != 0 &&
                  !options.containsKey(selected))
                DropdownMenuItem(
                  value: selected,
                  child: Text(
                    '自訂 #${selected.toRadixString(16).substring(2).toUpperCase()}',
                  ),
                ),
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: enabled
                  ? () async {
                      final controller = TextEditingController(
                        text: selected != null && selected > 0
                            ? '#${selected.toRadixString(16).substring(2).toUpperCase()}'
                            : '#39775D',
                      );
                      String? error;
                      final value = await showDialog<int>(
                        context: context,
                        builder: (dialogContext) => StatefulBuilder(
                          builder: (context, update) => AlertDialog(
                            title: Text('自訂$label'),
                            content: TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: '#RRGGBB',
                                errorText: error,
                              ),
                              maxLength: 7,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  final text = controller.text
                                      .trim()
                                      .replaceFirst('#', '');
                                  if (!RegExp(
                                    r'^[0-9a-fA-F]{6}$',
                                  ).hasMatch(text)) {
                                    update(() => error = '請輸入 6 位十六進位色碼');
                                    return;
                                  }
                                  Navigator.pop(
                                    dialogContext,
                                    0xFF000000 | int.parse(text, radix: 16),
                                  );
                                },
                                child: const Text('套用'),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (value != null) change(value);
                    }
                  : null,
              child: const Text('自訂色碼'),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          showColors ? '自訂配色與字型' : '字型與字重',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          '同一套設定會套用到三頁。錯誤提示、停用狀態與操作順序保持固定。',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 14),
        if (showColors)
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
                fontWeight: look.fontWeight,
              ),
            ),
          ),
        if (showColors && look.followFrontend)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              '跟隨前台目前底色；使用圖庫時，沿用同一張圖、位置、縮放與遮罩。',
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (showColors)
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
                fontWeight: look.fontWeight,
              ),
            ),
          ),
        if (showColors)
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
                fontWeight: look.fontWeight,
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
                    fontWeight: look.fontWeight,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          key: ValueKey('suite-font-weight-${look.fontWeight}'),
          initialValue: look.fontWeight ?? 0,
          decoration: const InputDecoration(
            labelText: '字重',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final e in {
              0: '套裝預設',
              400: '標準',
              500: '中等',
              600: '略粗',
              700: '粗體',
              800: '特粗',
            }.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: enabled
              ? (v) => onChanged(
                  BookingPageLook(
                    followFrontend: look.followFrontend,
                    background: look.background,
                    text: look.text,
                    primary: look.primary,
                    font: look.font,
                    fontWeight: v == 0 ? null : v,
                  ),
                )
              : null,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: enabled ? onReset : null,
            child: const Text('還原本套裝配色與字型'),
          ),
        ),
      ],
    );
  }
}
