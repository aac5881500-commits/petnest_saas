import 'package:flutter/material.dart';
import '../shop_dashboard_navigation.dart';

class ShopContentType {
  const ShopContentType(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
}

const shopAnnouncementTypes = [
  ShopContentType('normal', '一般公告', Icons.campaign_outlined),
  ShopContentType('important', '重要公告', Icons.priority_high),
  ShopContentType('business_hours', '營業異動', Icons.schedule),
  ShopContentType('promotion', '優惠活動', Icons.card_giftcard),
  ShopContentType('checkin_notice', '入住提醒', Icons.pets_outlined),
];

ShopContentType shopAnnouncementType(Object? raw) =>
    shopAnnouncementTypes.firstWhere(
      (type) => type.value == raw,
      orElse: () => shopAnnouncementTypes.first,
    );

class ShopContentDraft {
  const ShopContentDraft({
    required this.title,
    required this.body,
    required this.isPublished,
    this.type = 'normal',
  });
  final String title;
  final String body;
  final bool isPublished;
  final String type;
}

/// The state owns its controllers and remains mounted after a failed save so
/// the operator can retry without losing the draft.
class ShopContentEditorDialog extends StatefulWidget {
  const ShopContentEditorDialog({
    super.key,
    required this.isFaq,
    required this.isNew,
    required this.initial,
    required this.onSave,
  });
  final bool isFaq;
  final bool isNew;
  final ShopContentDraft initial;
  final Future<void> Function(ShopContentDraft draft) onSave;

  @override
  State<ShopContentEditorDialog> createState() =>
      _ShopContentEditorDialogState();
}

class _ShopContentEditorDialogState extends State<ShopContentEditorDialog>
    with ShopDashboardLeaveAware<ShopContentEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  late String _type;
  late bool _published;
  bool _saving = false;
  bool _confirming = false;
  String? _error;

  @override
  bool get dashboardIsBusy => _saving;
  @override
  bool get dashboardHasUnsavedChanges =>
      _title.text != widget.initial.title ||
      _body.text != widget.initial.body ||
      _published != widget.initial.isPublished ||
      _type != shopAnnouncementType(widget.initial.type).value;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial.title);
    _body = TextEditingController(text: widget.initial.body);
    _type = shopAnnouncementType(widget.initial.type).value;
    _published = widget.initial.isPublished;
    _title.addListener(_changed);
    _body.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _title.removeListener(_changed);
    _body.removeListener(_changed);
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || _confirming) return;
    _confirming = true;
    try {
      if (await dashboardConfirmLeave() && mounted) {
        Navigator.of(context).pop(false);
      }
    } finally {
      _confirming = false;
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = ShopContentDraft(
      title: _title.text.trim(),
      body: _body.text.trim(),
      isPublished: _published,
      type: _type,
    );
    try {
      await widget.onSave(draft);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '儲存失敗，內容已保留。請確認網路與權限後重試。');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noun = widget.isFaq ? '常見問題' : '公告';
    return PopScope(
      canPop: !_saving && !dashboardHasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        scrollable: true,
        title: Text('${widget.isNew ? '新增' : '編輯'}$noun'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.isFaq) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '公告類型',
                      border: OutlineInputBorder(),
                    ),
                    items: shopAnnouncementTypes
                        .map(
                          (type) => DropdownMenuItem(
                            value: type.value,
                            child: Row(
                              children: [
                                Icon(type.icon, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(type.label)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) setState(() => _type = value);
                          },
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _title,
                  enabled: !_saving,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: widget.isFaq ? '問題' : '公告標題',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? '請填寫${widget.isFaq ? '問題' : '公告標題'}'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _body,
                  enabled: !_saving,
                  minLines: 4,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: widget.isFaq ? '回答' : '公告內容',
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('上架顯示'),
                  subtitle: Text(_published ? '儲存後，顧客可在前台查看。' : '儲存為未上架內容。'),
                  value: _published,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _published = value),
                ),
                if (_error != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _close,
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_saving ? '儲存中…' : '儲存'),
          ),
        ],
      ),
    );
  }
}
