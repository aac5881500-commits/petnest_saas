import 'package:flutter/material.dart';

class AnnouncementManagementCard extends StatelessWidget {
  const AnnouncementManagementCard({
    super.key,
    required this.title,
    required this.body,
    required this.typeLabel,
    required this.published,
    required this.pinned,
    required this.disabled,
    required this.onPublish,
    required this.onPin,
    required this.onEdit,
    required this.onDelete,
    required this.notificationActions,
  });
  final String title, body, typeLabel;
  final bool published, pinned, disabled;
  final ValueChanged<bool> onPublish;
  final VoidCallback onPin, onEdit, onDelete;
  final Widget notificationActions;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip(
                label: Text(typeLabel),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text(published ? '已發布' : '未上架'),
                visualDensity: VisualDensity.compact,
              ),
              if (pinned)
                const Chip(
                  avatar: Icon(Icons.push_pin, size: 16),
                  label: Text('置頂'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            body.isEmpty ? '尚未填寫內容' : body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 28),
          notificationActions,
          const SizedBox(height: 8),
          Row(
            children: [
              Switch.adaptive(
                value: published,
                onChanged: disabled ? null : onPublish,
              ),
              const SizedBox(width: 4),
              const Text('前台顯示'),
              const Spacer(),
              PopupMenuButton<String>(
                enabled: !disabled,
                tooltip: '公告更多操作',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'pin':
                      onPin();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('編輯內容')),
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(pinned ? '取消置頂' : '置頂公告'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('刪除公告')),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
