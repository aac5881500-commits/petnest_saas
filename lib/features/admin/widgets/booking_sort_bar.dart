// 檔案名稱：lib/features/admin/widgets/booking_sort_bar.dart
// 功能說明：後台訂單排序列
// 功能：
// - 顯示目前訂單筆數
// - 顯示排序方式
// - 保留列表 / 格子切換按鈕位置

import 'package:flutter/material.dart';

class BookingSortBar extends StatelessWidget {
  const BookingSortBar({
    super.key,
    required this.totalCount,
    required this.sortType,
    required this.onSortChanged,
    required this.isGridMode,
    required this.onToggleViewMode,
  });

  final int totalCount;
  final String sortType;
  final ValueChanged<String> onSortChanged;
  final bool isGridMode;
  final VoidCallback onToggleViewMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          Text(
            '目前載入 $totalCount 筆',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),

          const Spacer(),

          PopupMenuButton<String>(
            onSelected: onSortChanged,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            itemBuilder: (context) {
              return const [
                PopupMenuItem(value: 'startDesc', child: Text('入住日新到舊')),
                PopupMenuItem(value: 'startAsc', child: Text('入住日舊到新')),
                PopupMenuItem(value: 'createdDesc', child: Text('下訂新到舊')),
                PopupMenuItem(value: 'createdAsc', child: Text('下訂舊到新')),
              ];
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort, size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '排序：${_sortText(sortType)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: Colors.grey.shade700,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggleViewMode,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Icon(
                isGridMode ? Icons.view_list : Icons.grid_view,
                size: 20,
                color: Colors.blueGrey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sortText(String value) {
    switch (value) {
      case 'startAsc':
        return '入住日舊到新';
      case 'createdDesc':
        return '下訂新到舊';
      case 'createdAsc':
        return '下訂舊到新';
      case 'startDesc':
      default:
        return '入住日新到舊';
    }
  }
}
