// 功能：故事、理念、團隊與經歷的草稿編輯，提供按鈕排序與穩定輸入狀態。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'about_media.dart';

class AboutItemsEditor extends StatelessWidget {
  const AboutItemsEditor({
    super.key,
    required this.section,
    required this.items,
    required this.shop,
    required this.onChanged,
    required this.onUpload,
  });
  final String section;
  final List<AboutContentItem> items;
  final Map<String, dynamic> shop;
  final ValueChanged<List<AboutContentItem>> onChanged;
  final Future<AboutMedia?> Function() onUpload;
  void _move(int from, int to) {
    final next = [...items];
    next.insert(to, next.removeAt(from));
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        AboutPageSetting.sectionNames[section]!,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('尚未新增內容；未填寫的區塊不會顯示於顧客端。'),
        ),
      for (var i = 0; i < items.length; i++)
        _ItemEditor(
          key: ValueKey(items[i].id),
          item: items[i],
          section: section,
          shop: shop,
          onUpload: onUpload,
          onChanged: (value) {
            final next = [...items];
            next[i] = value;
            onChanged(next);
          },
          onUp: i > 0 ? () => _move(i, i - 1) : null,
          onDown: i + 1 < items.length ? () => _move(i, i + 1) : null,
          onDelete: () => onChanged([...items]..removeAt(i)),
        ),
      OutlinedButton.icon(
        icon: const Icon(Icons.add),
        label: Text('新增${AboutPageSetting.sectionNames[section]}'),
        onPressed: () => onChanged([
          ...items,
          AboutContentItem(
            id: '$section-${DateTime.now().microsecondsSinceEpoch}',
          ),
        ]),
      ),
    ],
  );
}

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({
    super.key,
    required this.item,
    required this.section,
    required this.shop,
    required this.onChanged,
    required this.onUpload,
    required this.onDelete,
    this.onUp,
    this.onDown,
  });
  final AboutContentItem item;
  final String section;
  final Map<String, dynamic> shop;
  final ValueChanged<AboutContentItem> onChanged;
  final Future<AboutMedia?> Function() onUpload;
  final VoidCallback? onUp, onDown;
  final VoidCallback onDelete;
  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final _title = TextEditingController(text: widget.item.title),
      _text = TextEditingController(text: widget.item.text),
      _role = TextEditingController(text: widget.item.role);
  @override
  void didUpdateWidget(covariant _ItemEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final pair in [
      (_title, widget.item.title),
      (_text, widget.item.text),
      (_role, widget.item.role),
    ]) {
      if (pair.$1.text != pair.$2) pair.$1.text = pair.$2;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    _role.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: PageStorageKey<String>(
        'about-item-${widget.section}-${widget.item.id}',
      ),
      initiallyExpanded: widget.item.title.isEmpty && widget.item.text.isEmpty,
      title: Text(
        widget.item.title.isEmpty ? '尚未命名' : widget.item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('顯示'),
                value: widget.item.visible,
                onChanged: (v) =>
                    widget.onChanged(widget.item.copyWith(visible: v)),
              ),
            ),
            IconButton(
              tooltip: '上移',
              onPressed: widget.onUp,
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: '下移',
              onPressed: widget.onDown,
              icon: const Icon(Icons.arrow_downward),
            ),
            IconButton(
              tooltip: '刪除此項',
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        TextField(
          controller: _title,
          decoration: InputDecoration(
            labelText: widget.section == 'team' ? '姓名或稱呼（選填）' : '標題（選填）',
          ),
          onChanged: (v) => widget.onChanged(widget.item.copyWith(title: v)),
        ),
        if (widget.section == 'team')
          TextField(
            controller: _role,
            decoration: const InputDecoration(labelText: '職稱（選填）'),
            onChanged: (v) => widget.onChanged(widget.item.copyWith(role: v)),
          ),
        TextField(
          controller: _text,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: widget.section == 'stories' ? '故事內容' : '簡短說明',
            hintText: widget.section == 'stories'
                ? '可介紹創店故事、照護方式與經營理念；只填寫店家的真實內容。'
                : null,
          ),
          onChanged: (v) => widget.onChanged(widget.item.copyWith(text: v)),
        ),
        if (['principles', 'highlights'].contains(widget.section))
          DropdownButtonFormField<String>(
            initialValue:
                const [
                  'pets',
                  'heart',
                  'home',
                  'care',
                  'clean',
                ].contains(widget.item.icon)
                ? widget.item.icon
                : 'pets',
            decoration: const InputDecoration(labelText: '圖示'),
            items: [
              for (final e in const {
                'pets': '貓咪',
                'heart': '愛心',
                'home': '居家',
                'care': '照護',
                'clean': '清潔',
              }.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => widget.onChanged(widget.item.copyWith(icon: v)),
          ),
        const SizedBox(height: 12),
        if (widget.section != 'highlights')
          AboutMediaField(
            value: widget.item.image,
            shop: widget.shop,
            onChanged: (image) =>
                widget.onChanged(widget.item.copyWith(image: image)),
            allowLibrary:
                widget.section == 'stories' || widget.section == 'principles',
            allowFirst:
                widget.section == 'stories' || widget.section == 'principles',
            onUpload: widget.onUpload,
          ),
        if (widget.section == 'credentials')
          const Text('此處為店家自行提供的經歷或證明，不代表平台認證。'),
      ],
    ),
  );
}
