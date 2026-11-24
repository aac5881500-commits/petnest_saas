import 'package:flutter/material.dart';
import '../../../core/models/internal_handover_entry.dart';
import '../../../core/services/internal_handover_note_service.dart';

class InternalHandoverComposer extends StatefulWidget {
  const InternalHandoverComposer({super.key, required this.onSave});
  final Future<void> Function(String category, String content) onSave;
  @override
  State<InternalHandoverComposer> createState() =>
      _InternalHandoverComposerState();
}

class _InternalHandoverComposerState extends State<InternalHandoverComposer> {
  final _content = TextEditingController();
  String? _category, _error;
  bool _saving = false;
  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final category = _category;
    if (_saving || category == null || _content.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(category, _content.text.trim());
      if (!mounted) return;
      _content.clear();
      setState(() => _category = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已新增交接，可繼續新增下一筆')));
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is InternalHandoverLockedException
              ? '訂單已鎖定，無法新增交接。'
              : '交接未儲存，內容已保留，請確認網路與權限後重試。',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '新增交接事項',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      const Text(
        '先選分類，再填內容；每筆獨立保留，不會改掉上一班的交接。',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final category in internalHandoverCategories)
            ChoiceChip(
              label: Text(category),
              selected: _category == category,
              onSelected: _saving
                  ? null
                  : (_) => setState(() => _category = category),
            ),
        ],
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _content,
        readOnly: _saving,
        minLines: 3,
        maxLines: 6,
        maxLength: 3000,
        decoration: InputDecoration(
          labelText: '交接內容',
          hintText: _category == '餵藥交代'
              ? '例如：喵喵晚餐後餵藥，留意是否吐藥。'
              : '請記下下一班需要注意的重點',
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed:
              _saving || _category == null || _content.text.trim().isEmpty
              ? null
              : _save,
          icon: Icon(_saving ? Icons.hourglass_top : Icons.add),
          label: Text(_saving ? '儲存中…' : '新增交接'),
        ),
      ),
    ],
  );
}
