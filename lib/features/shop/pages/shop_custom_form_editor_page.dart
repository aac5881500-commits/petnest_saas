// 檔案名稱：lib/features/shop/pages/shop_custom_form_editor_page.dart
// 功能說明：店家自訂表單編輯頁：寵物表單與訂單表單共用。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/services/custom_form_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/widgets/custom_form/custom_form_question_editor.dart';

class ShopCustomFormEditorPage extends StatefulWidget {
  const ShopCustomFormEditorPage({
    super.key,
    required this.shopId,
    required this.formType,
  });

  final String shopId;
  final CustomFormType formType;

  @override
  State<ShopCustomFormEditorPage> createState() =>
      _ShopCustomFormEditorPageState();
}

class _ShopCustomFormEditorPageState extends State<ShopCustomFormEditorPage> {
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  late CustomFormModel _form;
  late CustomFormModel _savedForm;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _form = CustomFormModel.empty(
      shopId: widget.shopId,
      formType: widget.formType,
    );
    _savedForm = _form;
    _titleCtrl = TextEditingController(text: _form.title);
    _descCtrl = TextEditingController(text: _form.description);
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final CustomFormModel form = await CustomFormService.instance.getForm(
        shopId: widget.shopId,
        formType: widget.formType,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _form = form;
        _savedForm = form;
        _titleCtrl.text = form.title;
        _descCtrl.text = form.description;
        _loading = false;
        _dirty = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '讀取表單失敗：$error';
      });
    }
  }

  void _markDirty(CustomFormModel form) {
    setState(() {
      _form = form;
      _dirty = true;
    });
  }

  CustomFormModel _withFields(CustomFormModel form) {
    return form.copyWith(title: _titleCtrl.text, description: _descCtrl.text);
  }

  List<CustomFormSection> _reindexSections(List<CustomFormSection> sections) {
    return <CustomFormSection>[
      for (int i = 0; i < sections.length; i++)
        sections[i].copyWith(sortOrder: i),
    ];
  }

  List<CustomFormQuestion> _reindexQuestions(
    List<CustomFormQuestion> questions,
  ) {
    return <CustomFormQuestion>[
      for (int i = 0; i < questions.length; i++)
        questions[i].copyWith(sortOrder: i),
    ];
  }

  void _moveSection(int index, int offset) {
    final int target = index + offset;
    if (target < 0 || target >= _form.sections.length) {
      return;
    }
    final List<CustomFormSection> sections = List<CustomFormSection>.from(
      _form.sections,
    );
    final CustomFormSection item = sections.removeAt(index);
    sections.insert(target, item);
    _markDirty(_form.copyWith(sections: _reindexSections(sections)));
  }

  void _moveQuestion(int sectionIndex, int questionIndex, int offset) {
    final CustomFormSection section = _form.sections[sectionIndex];
    final int target = questionIndex + offset;
    if (target < 0 || target >= section.questions.length) {
      return;
    }
    final List<CustomFormQuestion> questions = List<CustomFormQuestion>.from(
      section.questions,
    );
    final CustomFormQuestion item = questions.removeAt(questionIndex);
    questions.insert(target, item);
    _replaceSection(
      sectionIndex,
      section.copyWith(questions: _reindexQuestions(questions)),
    );
  }

  void _replaceSection(int index, CustomFormSection section) {
    final List<CustomFormSection> sections = List<CustomFormSection>.from(
      _form.sections,
    );
    sections[index] = section;
    _markDirty(_form.copyWith(sections: sections));
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
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
    return confirmed == true;
  }

  Future<void> _deleteSection(int index) async {
    final bool ok = await _confirmDelete(
      title: '刪除分類',
      message: '確定刪除此分類及其所有問題？刪除後需儲存才會寫入。',
    );
    if (!ok || !mounted) {
      return;
    }
    final List<CustomFormSection> sections = List<CustomFormSection>.from(
      _form.sections,
    )..removeAt(index);
    _markDirty(_form.copyWith(sections: _reindexSections(sections)));
  }

  Future<void> _deleteQuestion(int sectionIndex, int questionIndex) async {
    final bool ok = await _confirmDelete(
      title: '刪除問題',
      message: '確定刪除此問題？刪除後需儲存才會寫入。',
    );
    if (!ok || !mounted) {
      return;
    }
    final CustomFormSection section = _form.sections[sectionIndex];
    final List<CustomFormQuestion> questions = List<CustomFormQuestion>.from(
      section.questions,
    )..removeAt(questionIndex);
    _replaceSection(
      sectionIndex,
      section.copyWith(questions: _reindexQuestions(questions)),
    );
  }

  Future<void> _editQuestion(int sectionIndex, int? questionIndex) async {
    final CustomFormSection section = _form.sections[sectionIndex];
    final CustomFormQuestion draft = questionIndex == null
        ? CustomFormQuestion(
            id: CustomFormModel.createStableId('q'),
            label: '',
            sortOrder: section.questions.length,
          )
        : section.questions[questionIndex];

    final CustomFormQuestion? result = await showCustomFormQuestionEditor(
      context: context,
      question: draft,
    );
    if (result == null || !mounted) {
      return;
    }
    final List<CustomFormQuestion> questions = List<CustomFormQuestion>.from(
      section.questions,
    );
    if (questionIndex == null) {
      questions.add(result);
    } else {
      questions[questionIndex] = result;
    }
    _replaceSection(
      sectionIndex,
      section.copyWith(questions: _reindexQuestions(questions)),
    );
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) {
      return true;
    }
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('放棄變更？'),
          content: const Text('目前有尚未儲存的修改，離開後將不會保存。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('繼續編輯'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放棄變更'),
            ),
          ],
        );
      },
    );
    return leave == true;
  }

  Future<void> _save() async {
    final CustomFormModel form = _withFields(_form);
    if (form.title.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請填寫表單標題')));
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await CustomFormService.instance.saveForm(form: form);
      final CustomFormModel saved = await CustomFormService.instance.getForm(
        shopId: widget.shopId,
        formType: widget.formType,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _form = saved;
        _savedForm = saved;
        _titleCtrl.text = saved.title;
        _descCtrl.text = saved.description;
        _saving = false;
        _dirty = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已儲存表單設定')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        final NavigatorState navigator = Navigator.of(context);
        final bool leave = await _confirmLeave();
        if (leave && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.formType.defaultTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
            : Column(
                children: <Widget>[
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: <Widget>[
                        _buildFormMetaCard(colors),
                        const SizedBox(height: 12),
                        ..._form.sections.asMap().entries.map((
                          MapEntry<int, CustomFormSection> entry,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildSectionCard(entry.key, entry.value),
                          );
                        }),
                        OutlinedButton.icon(
                          onPressed: () {
                            final List<CustomFormSection> sections =
                                List<CustomFormSection>.from(_form.sections)
                                  ..add(
                                    CustomFormSection(
                                      id: CustomFormModel.createStableId('sec'),
                                      title: '新分類',
                                      sortOrder: _form.sections.length,
                                    ),
                                  );
                            _markDirty(
                              _form.copyWith(
                                sections: _reindexSections(sections),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('新增分類'),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    elevation: 8,
                    color: colors.surface,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(_saving ? '儲存中...' : '儲存設定'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFormMetaCard(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '表單設定',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.formType.defaultDescription,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('啟用此表單', style: TextStyle(fontSize: 14)),
            value: _form.enabled,
            onChanged: (bool value) {
              _markDirty(_form.copyWith(enabled: value));
            },
          ),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(fontSize: 14),
            onChanged: (_) => setState(() => _dirty = true),
            decoration: const InputDecoration(
              labelText: '表單標題',
              labelStyle: TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtrl,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(fontSize: 14),
            onChanged: (_) => setState(() => _dirty = true),
            decoration: const InputDecoration(
              labelText: '表單說明',
              labelStyle: TextStyle(fontSize: 14),
            ),
          ),
          if (_savedForm.version > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '目前版本 ${_savedForm.version}',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(int sectionIndex, CustomFormSection section) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  section.title.isEmpty ? '未命名分類' : section.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(
                value: section.enabled,
                onChanged: (bool value) {
                  _replaceSection(
                    sectionIndex,
                    section.copyWith(enabled: value),
                  );
                },
              ),
            ],
          ),
          _SectionHeaderFields(
            key: ValueKey<String>('section_fields_${section.id}'),
            section: section,
            onChanged: (CustomFormSection updated) {
              _replaceSection(sectionIndex, updated);
            },
          ),
          Wrap(
            spacing: 4,
            children: <Widget>[
              TextButton(
                onPressed: sectionIndex == 0
                    ? null
                    : () => _moveSection(sectionIndex, -1),
                child: const Text('上移'),
              ),
              TextButton(
                onPressed: sectionIndex >= _form.sections.length - 1
                    ? null
                    : () => _moveSection(sectionIndex, 1),
                child: const Text('下移'),
              ),
              TextButton(
                onPressed: () => _deleteSection(sectionIndex),
                child: const Text('刪除分類'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '問題',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (section.questions.isEmpty)
            Text(
              '尚未新增問題',
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ...section.questions.asMap().entries.map((
            MapEntry<int, CustomFormQuestion> entry,
          ) {
            final int questionIndex = entry.key;
            final CustomFormQuestion question = entry.value;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    question.label.isEmpty ? '未命名問題' : question.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${question.type.label}　${question.required ? '必填' : '選填'}　${question.enabled ? '啟用' : '停用'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  Wrap(
                    spacing: 4,
                    children: <Widget>[
                      TextButton(
                        onPressed: questionIndex == 0
                            ? null
                            : () => _moveQuestion(
                                sectionIndex,
                                questionIndex,
                                -1,
                              ),
                        child: const Text('上移'),
                      ),
                      TextButton(
                        onPressed: questionIndex >= section.questions.length - 1
                            ? null
                            : () =>
                                  _moveQuestion(sectionIndex, questionIndex, 1),
                        child: const Text('下移'),
                      ),
                      TextButton(
                        onPressed: () =>
                            _editQuestion(sectionIndex, questionIndex),
                        child: const Text('編輯'),
                      ),
                      TextButton(
                        onPressed: () =>
                            _deleteQuestion(sectionIndex, questionIndex),
                        child: const Text('刪除'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _editQuestion(sectionIndex, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增問題'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeaderFields extends StatefulWidget {
  const _SectionHeaderFields({
    super.key,
    required this.section,
    required this.onChanged,
  });

  final CustomFormSection section;
  final ValueChanged<CustomFormSection> onChanged;

  @override
  State<_SectionHeaderFields> createState() => _SectionHeaderFieldsState();
}

class _SectionHeaderFieldsState extends State<_SectionHeaderFields> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.section.title);
    _descCtrl = TextEditingController(text: widget.section.description);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextField(
          controller: _titleCtrl,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            labelText: '分類名稱',
            labelStyle: TextStyle(fontSize: 14),
            isDense: true,
          ),
          onChanged: (_) {
            widget.onChanged(
              widget.section.copyWith(
                title: _titleCtrl.text,
                description: _descCtrl.text,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descCtrl,
          minLines: 1,
          maxLines: 3,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            labelText: '分類說明',
            labelStyle: TextStyle(fontSize: 14),
            isDense: true,
          ),
          onChanged: (_) {
            widget.onChanged(
              widget.section.copyWith(
                title: _titleCtrl.text,
                description: _descCtrl.text,
              ),
            );
          },
        ),
      ],
    );
  }
}
