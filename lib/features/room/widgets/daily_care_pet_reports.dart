import 'package:flutter/material.dart';

/// Editing and publication are scoped to the selected pet and current session.
class DailyCarePetReports extends StatefulWidget {
  const DailyCarePetReports({super.key, required this.request, this.readOnly = false});

  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) request;
  final bool readOnly;

  static const fields = {
    'appetite': '飲食',
    'stool': '排便',
    'urine': '排尿',
    'mood': '精神',
    'note': '給飼主的備註',
  };

  @override
  State<DailyCarePetReports> createState() => _DailyCarePetReportsState();
}

class _DailyCarePetReportsState extends State<DailyCarePetReports> {
  late Future<Map<String, dynamic>> _load = widget.request({'mode': 'read'});
  final _edits = <String, Map<String, String>>{};
  final _revisions = <String, int>{};
  final _publishedHere = <String>{};
  String? _selected;
  bool _busy = false;

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  Future<void> _save(String id, String name, String mode) async {
    if (mode == 'publish') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('發送 $name 的照護回報？'),
          content: const Text('這份回報會顯示在飼主訂單。其他貓咪的草稿仍留在店內。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('返回')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('確認發送')),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    setState(() => _busy = true);
    try {
      final response = await widget.request({
        'mode': mode,
        'petId': id,
        'revision': _revisions[id] ?? 0,
        'values': _edits[id] ?? <String, String>{},
      });
      if (!mounted) return;
      setState(() {
        if (mode == 'publish') {
          _publishedHere.add(id);
        } else {
          _revisions[id] = response['revision'] as int;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mode == 'publish' ? '已發送 $name 的回報' : '已儲存 $name 的草稿')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('暫時無法載入逐貓回報'),
            TextButton(
              onPressed: () => setState(() => _load = widget.request({'mode': 'read'})),
              child: const Text('重新載入'),
            ),
          ],
        );
      }
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final data = snapshot.data!;
      final pets = (data['pets'] as List).map(_map).toList();
      final drafts = _map(data['drafts']);
      final published = _map(data['published']);
      if (pets.isEmpty) return const Text('這筆訂單沒有貓咪資料。');
      final pet = pets.firstWhere((item) => item['id'] == _selected, orElse: () => pets.first);
      final id = pet['id'] as String;
      final name = (pet['name'] as String?)?.trim();
      final label = name == null || name.isEmpty ? '貓咪' : name;
      final draft = _map(drafts[id]);
      final sent = published.containsKey(id) || _publishedHere.contains(id);
      _revisions.putIfAbsent(id, () => (draft['revision'] as num?)?.toInt() ?? 0);
      final values = _edits.putIfAbsent(id, () => _map(
        sent ? _map(published[id])['values'] : draft['values'],
      ).map((key, value) => MapEntry(key, value.toString())));
      final writable = !widget.readOnly && data['writable'] == true && !sent;

      Widget field(MapEntry<String, String> entry) => TextFormField(
        key: ValueKey((id, entry.key)),
        initialValue: values[entry.key],
        readOnly: !writable || _busy,
        maxLength: entry.key == 'note' ? 1000 : 80,
        maxLines: entry.key == 'note' ? 3 : 1,
        decoration: InputDecoration(labelText: entry.value, counterText: ''),
        onChanged: (value) => setState(() => values[entry.key] = value),
      );

      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final item in pets)
                    ChoiceChip(
                      label: Text(
                        '${(item['name'] as String?)?.trim().isNotEmpty == true ? item['name'] : '貓咪'} · '
                        '${published.containsKey(item['id']) || _publishedHere.contains(item['id']) ? '已發送' : (_revisions[item['id']] ?? _map(drafts[item['id']])['revision'] ?? 0) != 0 ? '草稿' : '待填'}',
                      ),
                      selected: item['id'] == id,
                      onSelected: _busy ? null : (_) => setState(() => _selected = item['id'] as String),
                    ),
                ],
              ),
              if (data['sharedCompleted'] == true)
                const Text('這一場已有整房回報。')
              else ...[
                if (constraints.maxWidth >= 520)
                  Wrap(
                    spacing: 12,
                    runSpacing: 14,
                    children: [
                      for (final entry in DailyCarePetReports.fields.entries.take(4))
                        SizedBox(width: (constraints.maxWidth - 44) / 2, child: field(entry)),
                    ],
                  )
                else
                  for (final entry in DailyCarePetReports.fields.entries.take(4)) field(entry),
                field(DailyCarePetReports.fields.entries.last),
                if (writable)
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _busy ? null : () => _save(id, label, 'draft'),
                        child: const Text('儲存草稿'),
                      ),
                      FilledButton(
                        onPressed: _busy || !values.values.any((value) => value.trim().isNotEmpty)
                            ? null
                            : () => _save(id, label, 'publish'),
                        child: Text(_busy ? '處理中…' : '發送這隻貓的回報'),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
