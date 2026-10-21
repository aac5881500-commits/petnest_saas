// 檔案：lib/features/shop/widgets/environment/environment_services_editor.dart
// 功能：設備分類搜尋與自訂服務草稿編輯，不自行寫入資料。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_presentation.dart';
import 'package:petnest_saas/features/shop/data/environment_facility_options.dart';
import 'environment_icon_picker_dialog.dart';

class EnvironmentServicesEditor extends StatefulWidget {
  const EnvironmentServicesEditor({
    super.key,
    required this.selectedKeys,
    required this.presentation,
    required this.onSelected,
    required this.onChanged,
    required this.onUpload,
    required this.onRemoveImage,
    required this.onDelete,
    required this.iconOf,
    required this.busy,
  });
  final List<String> selectedKeys;
  final EnvironmentPresentation presentation;
  final ValueChanged<List<String>> onSelected;
  final ValueChanged<EnvironmentPresentation> onChanged;
  final ValueChanged<String> onUpload, onRemoveImage, onDelete;
  final IconData Function(String) iconOf;
  final bool busy;
  @override
  State<EnvironmentServicesEditor> createState() =>
      _EnvironmentServicesEditorState();
}

class _EnvironmentServicesEditorState extends State<EnvironmentServicesEditor> {
  String _search = '', _category = '';
  void _change(Map<String, dynamic> changes) =>
      widget.onChanged(widget.presentation.copyWith(changes));
  void _services(List<EnvironmentServiceCard> services) =>
      _change({'customServices': services.map((s) => s.toMap()).toList()});
  void _move(
    List<String> ids,
    int index,
    int direction,
    ValueChanged<List<String>> change,
  ) {
    final target = index + direction;
    if (target < 0 || target >= ids.length) return;
    final copy = List<String>.of(ids);
    final id = copy.removeAt(index);
    copy.insert(target, id);
    change(copy);
  }

  Future<void> _edit([EnvironmentServiceCard? service]) async {
    final result = await showDialog<EnvironmentServiceCard>(
      context: context,
      builder: (context) =>
          _ServiceDialog(service: service, iconOf: widget.iconOf),
    );
    if (result == null || !mounted) return;
    final values = widget.presentation.services;
    final index = values.indexWhere((s) => s.id == result.id);
    if (index < 0) {
      values.add(result);
    } else {
      values[index] = result;
    }
    _services(values);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.presentation;
    final selected = [
      ...p.facilityOrder.where(widget.selectedKeys.contains),
      ...widget.selectedKeys.where((id) => !p.facilityOrder.contains(id)),
    ];
    final options = environmentFacilityOptions
        .where(
          (m) =>
              (_category.isEmpty ||
                  environmentFacilityCategory(m) == _category) &&
              '${m['title']} ${m['description']}'.contains(_search),
        )
        .toList();
    return AbsorbPointer(
      absorbing: widget.busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('版型、文案、設備與服務需按儲存後生效；環境特色與相簿操作會立即儲存。'),
          const SizedBox(height: 12),
          EnvironmentLayoutPicker(
            title: '設備卡片版型',
            value: p.equipmentLayout,
            onChanged: (v) => _change({'equipmentLayout': v}),
          ),
          EnvironmentLayoutPicker(
            title: '服務卡片版型',
            value: p.serviceLayout,
            onChanged: (v) => _change({'serviceLayout': v}),
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: '搜尋設備與服務',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _search = v.trim()),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('全部'),
                selected: _category.isEmpty,
                onSelected: (_) => setState(() => _category = ''),
              ),
              for (final item in EnvironmentPresentation.categories.entries)
                ChoiceChip(
                  label: Text(item.value),
                  selected: _category == item.key,
                  onSelected: (_) => setState(() => _category = item.key),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('已選 ${selected.length} 項'),
          ),
          for (final item in options)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: Icon(item['icon'] as IconData),
              title: Text(item['title'] as String),
              subtitle: Text(item['description'] as String),
              value: widget.selectedKeys.contains(item['key']),
              onChanged: (v) {
                final copy = List<String>.of(widget.selectedKeys);
                if (v == true) {
                  copy.add(item['key'] as String);
                } else {
                  copy.remove(item['key']);
                }
                widget.onSelected(copy);
              },
            ),
          if (options.isEmpty) const Text('找不到符合的項目'),
          const Divider(),
          const Text(
            '已選項目排序與顯示',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          for (var i = 0; i < selected.length; i++)
            Builder(
              builder: (context) {
                final id = selected[i];
                final matches = environmentFacilityOptions.where(
                  (m) => m['key'] == id,
                );
                final title = matches.isEmpty
                    ? '既有項目：$id'
                    : matches.first['title'].toString();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          tooltip: p.hiddenFacilityKeys.contains(id)
                              ? '顯示'
                              : '隱藏',
                          icon: Icon(
                            p.hiddenFacilityKeys.contains(id)
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            final hidden = List<String>.of(
                              p.hiddenFacilityKeys,
                            );
                            hidden.contains(id)
                                ? hidden.remove(id)
                                : hidden.add(id);
                            _change({'hiddenFacilityKeys': hidden});
                          },
                        ),
                        IconButton(
                          tooltip: '上移',
                          icon: const Icon(Icons.arrow_upward),
                          onPressed: i == 0
                              ? null
                              : () => _move(
                                  selected,
                                  i,
                                  -1,
                                  (ids) => _change({'facilityOrder': ids}),
                                ),
                        ),
                        IconButton(
                          tooltip: '下移',
                          icon: const Icon(Icons.arrow_downward),
                          onPressed: i == selected.length - 1
                              ? null
                              : () => _move(
                                  selected,
                                  i,
                                  1,
                                  (ids) => _change({'facilityOrder': ids}),
                                ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          const Divider(),
          OutlinedButton.icon(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('新增自訂服務'),
          ),
          for (var i = 0; i < p.services.length; i++)
            Builder(
              builder: (context) {
                final service = p.services[i];
                return Card(
                  key: ValueKey(service.id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(widget.iconOf(service.icon)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(service.title)),
                            Switch(
                              value: service.visible,
                              onChanged: (v) {
                                final list = p.services;
                                list[i] = service.copyWith({'visible': v});
                                _services(list);
                              },
                            ),
                          ],
                        ),
                        Text(service.description),
                        if (service.imageUrl.isNotEmpty) const Text('已設定服務照片'),
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: () => _edit(service),
                              child: const Text('編輯'),
                            ),
                            TextButton(
                              onPressed: () => widget.onUpload(service.id),
                              child: Text(
                                service.imageUrl.isEmpty ? '上傳照片' : '更換照片',
                              ),
                            ),
                            if (service.imageUrl.isNotEmpty)
                              TextButton(
                                onPressed: () =>
                                    widget.onRemoveImage(service.id),
                                child: const Text('移除照片'),
                              ),
                            TextButton(
                              onPressed: () => widget.onDelete(service.id),
                              child: const Text('刪除'),
                            ),
                            IconButton(
                              tooltip: '上移',
                              onPressed: i == 0
                                  ? null
                                  : () => _move(
                                      p.services.map((s) => s.id).toList(),
                                      i,
                                      -1,
                                      (ids) => _services(
                                        ids
                                            .map(
                                              (id) => p.services.firstWhere(
                                                (s) => s.id == id,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: '下移',
                              onPressed: i == p.services.length - 1
                                  ? null
                                  : () => _move(
                                      p.services.map((s) => s.id).toList(),
                                      i,
                                      1,
                                      (ids) => _services(
                                        ids
                                            .map(
                                              (id) => p.services.firstWhere(
                                                (s) => s.id == id,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                              icon: const Icon(Icons.arrow_downward),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class EnvironmentLayoutPicker extends StatelessWidget {
  const EnvironmentLayoutPicker({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title, value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final layout in EnvironmentPresentation.layouts.entries)
            ChoiceChip(
              selected: value == layout.key,
              onSelected: (_) => onChanged(layout.key),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EnvironmentLayoutThumbnail(layout: layout.key),
                  Text(layout.value),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
    ],
  );
}

class EnvironmentLayoutThumbnail extends StatelessWidget {
  const EnvironmentLayoutThumbnail({super.key, required this.layout});
  final String layout;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: .25);
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return SizedBox(
      width: 76,
      height: 48,
      child: switch (layout) {
        'list' => Column(
          children: [
            for (var i = 0; i < 2; i++)
              Row(children: [bar(16, 16), bar(48, 8)]),
          ],
        ),
        'photo' => Column(children: [bar(68, 25), bar(48, 7)]),
        'icon' => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [for (var i = 0; i < 3; i++) bar(18, 22)],
        ),
        _ => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 2; i++)
              Column(children: [bar(28, 18), bar(28, 6), bar(24, 4)]),
          ],
        ),
      },
    );
  }
}

class EnvironmentTemplateThumbnail extends StatelessWidget {
  const EnvironmentTemplateThumbnail({super.key, required this.preset});
  final String preset;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    Widget tile({bool photo = false, bool reverse = false}) => Container(
      height: photo ? 28 : 17,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: .3)),
        borderRadius: BorderRadius.circular(preset == 'minimal' ? 2 : 6),
      ),
      child: Row(
        textDirection: reverse ? TextDirection.rtl : TextDirection.ltr,
        children: [
          Container(
            width: photo ? 55 : 22,
            color: color.withValues(alpha: .25),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Container(height: 4, color: color.withValues(alpha: .35)),
          ),
        ],
      ),
    );
    Widget grid() => Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Container(
              height: 19,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      ],
    );
    return SizedBox(
      height: 94,
      width: 124,
      child: Column(
        children: [
          Container(
            height: preset == 'photo' ? 30 : 18,
            color: color.withValues(alpha: .20),
          ),
          if (preset == 'care') grid(),
          if (preset == 'photo') grid(),
          tile(photo: preset == 'photo'),
          if (preset != 'photo') tile(reverse: preset == 'warm'),
          if (preset == 'warm') grid(),
          if (preset == 'minimal') tile(),
        ],
      ),
    );
  }
}

class _ServiceDialog extends StatefulWidget {
  const _ServiceDialog({this.service, required this.iconOf});
  final EnvironmentServiceCard? service;
  final IconData Function(String) iconOf;
  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _description;
  late String _icon, _category, _tag;
  late bool _visible;
  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _title = TextEditingController(text: s?.title ?? '');
    _description = TextEditingController(text: s?.description ?? '');
    _icon = s?.icon ?? 'pets';
    _category = s?.category ?? 'service';
    _tag = s?.tag ?? '';
    _visible = s?.visible ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.service == null ? '新增自訂服務' : '編輯自訂服務'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                maxLength: 60,
                decoration: const InputDecoration(labelText: '名稱'),
                validator: (v) => (v ?? '').trim().isEmpty ? '請填寫名稱' : null,
              ),
              TextFormField(
                controller: _description,
                maxLength: 240,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '簡短說明'),
              ),
              TextButton.icon(
                icon: Icon(widget.iconOf(_icon)),
                label: const Text('選擇圖示'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => EnvironmentIconPickerDialog(
                    onSelect: (key) => setState(() => _icon = key),
                  ),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: EnvironmentPresentation.categories.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
                decoration: const InputDecoration(labelText: '分類'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _tag,
                items:
                    const {
                          '': '不顯示',
                          'included': '包含服務',
                          'contact': '需另洽',
                          'paid': '另計費',
                        }.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _tag = v!),
                decoration: const InputDecoration(labelText: '服務標籤'),
              ),
              SwitchListTile(
                title: const Text('顯示服務'),
                value: _visible,
                onChanged: (v) => setState(() => _visible = v),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            (widget.service ??
                    EnvironmentServiceCard({
                      'id': 'service_${DateTime.now().microsecondsSinceEpoch}',
                    }))
                .copyWith({
                  'title': _title.text.trim(),
                  'description': _description.text.trim(),
                  'icon': _icon,
                  'category': _category,
                  'tag': _tag,
                  'visible': _visible,
                }),
          );
        },
        child: const Text('套用到草稿'),
      ),
    ],
  );
}
