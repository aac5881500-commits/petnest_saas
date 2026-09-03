// lib/features/shop/widgets/custom_form/custom_form_question_editor.dart
// 📝 自訂表單問題編輯底部彈窗

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';

Future<CustomFormQuestion?> showCustomFormQuestionEditor({
  required BuildContext context,
  required CustomFormQuestion question,
}) {
  return showModalBottomSheet<CustomFormQuestion>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: CustomFormQuestionEditor(question: question),
      );
    },
  );
}

class CustomFormQuestionEditor extends StatefulWidget {
  const CustomFormQuestionEditor({super.key, required this.question});

  final CustomFormQuestion question;

  @override
  State<CustomFormQuestionEditor> createState() =>
      _CustomFormQuestionEditorState();
}

class _CustomFormQuestionEditorState extends State<CustomFormQuestionEditor> {
  late CustomFormQuestion _question;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _placeholderCtrl;

  @override
  void initState() {
    super.initState();
    _question = widget.question;
    _labelCtrl = TextEditingController(text: _question.label);
    _descCtrl = TextEditingController(text: _question.description);
    _placeholderCtrl = TextEditingController(text: _question.placeholder);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _descCtrl.dispose();
    _placeholderCtrl.dispose();
    super.dispose();
  }

  void _applyFields() {
    _question = _question.copyWith(
      label: _labelCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      placeholder: _placeholderCtrl.text.trim(),
    );
  }

  Future<void> _confirmDeleteOption(int index) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('刪除選項'),
          content: const Text('確定刪除此選項？此動作需再次確認後才會從編輯內容移除。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      final List<CustomFormOption> options = List<CustomFormOption>.from(
        _question.options,
      )..removeAt(index);
      _question = _question.copyWith(options: _reindexOptions(options));
    });
  }

  List<CustomFormOption> _reindexOptions(List<CustomFormOption> options) {
    return <CustomFormOption>[
      for (int i = 0; i < options.length; i++)
        options[i].copyWith(sortOrder: i),
    ];
  }

  void _moveOption(int index, int offset) {
    final int target = index + offset;
    if (target < 0 || target >= _question.options.length) {
      return;
    }
    setState(() {
      final List<CustomFormOption> options = List<CustomFormOption>.from(
        _question.options,
      );
      final CustomFormOption item = options.removeAt(index);
      options.insert(target, item);
      _question = _question.copyWith(options: _reindexOptions(options));
    });
  }

  Future<void> _editOptionLabel(int index) async {
    final TextEditingController controller = TextEditingController(
      text: _question.options[index].label,
    );
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('編輯選項'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '選項文字'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      final List<CustomFormOption> options = List<CustomFormOption>.from(
        _question.options,
      );
      options[index] = options[index].copyWith(label: result);
      _question = _question.copyWith(options: options);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SizedBox(
      height: maxHeight,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    '編輯問題',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _applyFields();
                    if (_question.label.trim().isEmpty) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('請先填寫問題名稱')));
                      return;
                    }
                    Navigator.pop(context, _question);
                  },
                  child: const Text('完成'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: <Widget>[
                TextField(
                  controller: _labelCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: '問題名稱',
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descCtrl,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: '問題說明',
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<CustomFormQuestionType>(
                  key: ValueKey<CustomFormQuestionType>(_question.type),
                  initialValue: _question.type,
                  decoration: const InputDecoration(
                    labelText: '題型',
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                  items: CustomFormQuestionType.values
                      .map(
                        (CustomFormQuestionType type) =>
                            DropdownMenuItem<CustomFormQuestionType>(
                              value: type,
                              child: Text(
                                type.label,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                      )
                      .toList(),
                  onChanged: (CustomFormQuestionType? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _question = _question.copyWith(type: value);
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('必填', style: TextStyle(fontSize: 14)),
                  value: _question.required,
                  onChanged: (bool value) {
                    setState(() {
                      _question = _question.copyWith(required: value);
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('啟用此問題', style: TextStyle(fontSize: 14)),
                  value: _question.enabled,
                  onChanged: (bool value) {
                    setState(() {
                      _question = _question.copyWith(enabled: value);
                    });
                  },
                ),
                TextField(
                  controller: _placeholderCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: '提示文字 placeholder',
                    labelStyle: TextStyle(fontSize: 14),
                  ),
                ),
                if (_question.type.hasOptions) ...<Widget>[
                  const SizedBox(height: 16),
                  const Text(
                    '選項',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '單選、複選與下拉題需要至少一個選項。',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._question.options.asMap().entries.map((
                    MapEntry<int, CustomFormOption> entry,
                  ) {
                    final int index = entry.key;
                    final CustomFormOption option = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.outlineVariant),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            option.label.isEmpty ? '未命名選項' : option.label,
                            style: const TextStyle(fontSize: 14),
                          ),
                          Wrap(
                            spacing: 4,
                            children: <Widget>[
                              TextButton(
                                onPressed: index == 0
                                    ? null
                                    : () => _moveOption(index, -1),
                                child: const Text('上移'),
                              ),
                              TextButton(
                                onPressed: index >= _question.options.length - 1
                                    ? null
                                    : () => _moveOption(index, 1),
                                child: const Text('下移'),
                              ),
                              TextButton(
                                onPressed: () => _editOptionLabel(index),
                                child: const Text('修改'),
                              ),
                              TextButton(
                                onPressed: () => _confirmDeleteOption(index),
                                child: const Text('刪除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        final List<CustomFormOption> options =
                            List<CustomFormOption>.from(_question.options)..add(
                              CustomFormOption(
                                id: CustomFormModel.createStableId('opt'),
                                label: '新選項',
                                sortOrder: _question.options.length,
                              ),
                            );
                        _question = _question.copyWith(
                          options: _reindexOptions(options),
                        );
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('新增選項'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
