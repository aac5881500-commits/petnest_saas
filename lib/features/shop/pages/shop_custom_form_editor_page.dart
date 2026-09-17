// 檔案名稱：lib/features/shop/pages/shop_custom_form_editor_page.dart
// 功能說明：店家自訂表單編輯頁：送出訂單與手動訂單表單共用。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/custom_form_default_templates.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/services/custom_form_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/custom_form/widgets/custom_form_fill_preview.dart';
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
    if (widget.formType == CustomFormType.petProfile) {
      _loading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).maybePop();
        }
      });
      return;
    }
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
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error =
            '讀取表單失敗：[${error.plugin}/${error.code}] ${error.message ?? ''}\n'
            '路徑：shops/${widget.shopId}/custom_forms/${widget.formType.storageId}';
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

  Future<void> _editQuestion(
    int sectionIndex,
    int? questionIndex, {
    CustomFormAnswerScope createScope = CustomFormAnswerScope.order,
  }) async {
    final CustomFormSection section = _form.sections[sectionIndex];
    final CustomFormQuestion draft = questionIndex == null
        ? CustomFormQuestion(
            id: CustomFormModel.createStableId('q'),
            label: '',
            sortOrder: section.questions.length,
            answerScope: createScope,
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

  Future<void> _previewForm() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: ListView(
                    children: <Widget>[
                      CustomFormFillPreview(
                        form: _form,
                        formType: widget.formType,
                        interactive: true,
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('關閉預覽'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _applyRecommended() async {
    if (_form.hasCustomQuestions) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('套用建議初版？'),
            content: const Text(
              '套用後會取代目前這張表單的分類與題目，既有訂單答案不受影響。',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('確認取代'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) {
        return;
      }
    }
    final CustomFormModel next =
        CustomFormDefaultTemplates.replaceWithRecommended(_form);
    _markDirty(next);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _form.enabled
              ? '已套用推薦初版，確認內容後請按儲存設定'
              : '已套用推薦初版。儲存後才會生效；目前尚未啟用，客戶／店員尚不會看到此表單。',
        ),
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.enabled
                ? '已儲存表單設定'
                : '已儲存。目前尚未啟用，客戶／店員尚不會看到此表單。',
          ),
        ),
      );
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
            : LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool wide = constraints.maxWidth >= 1024;
                  final Widget settings = ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: _buildSettingsChildren(colors, showPreviewButton: !wide),
                  );
                  if (!wide) {
                    return Column(
                      children: <Widget>[
                        Expanded(child: settings),
                        _buildSaveBar(colors),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        flex: 42,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLowest,
                            border: Border(
                              right: BorderSide(color: colors.outlineVariant),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                                child: Text(
                                  '填寫預覽',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  children: <Widget>[
                                    CustomFormDesktopFillPreview(
                                      form: _form,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 58,
                        child: Column(
                          children: <Widget>[
                            Expanded(child: settings),
                            _buildSaveBar(colors),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  List<Widget> _buildSettingsChildren(
    ColorScheme colors, {
    required bool showPreviewButton,
  }) {
    return <Widget>[
      _buildScopeHintCard(colors),
      const SizedBox(height: 12),
      _buildFormMetaCard(colors),
      const SizedBox(height: 12),
      _buildQuickApplyCard(colors, showPreviewButton: showPreviewButton),
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
              List<CustomFormSection>.from(_form.sections)..add(
                CustomFormSection(
                  id: CustomFormModel.createStableId('sec'),
                  title: '新分類',
                  sortOrder: _form.sections.length,
                ),
              );
          _markDirty(
            _form.copyWith(sections: _reindexSections(sections)),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('新增分類'),
      ),
    ];
  }

  Widget _buildSaveBar(ColorScheme colors) {
    return Material(
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '儲存中...' : '儲存設定'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScopeHintCard(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '訂單資訊：每筆訂單填一次。',
            style: TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            '寵物資訊：依本次選取的每隻寵物分開填寫。',
            style: TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w600),
          ),
        ],
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
            subtitle: _form.enabled
                ? null
                : const Text('尚未啟用時，客戶／店員尚不會看到此表單'),
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

  Widget _buildQuickApplyCard(
    ColorScheme colors, {
    required bool showPreviewButton,
  }) {
    final CustomFormModel recommended = CustomFormDefaultTemplates.create(
      shopId: widget.shopId,
      formType: widget.formType,
    );
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
            '快速套用內容',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '這是建議初版，不會自動覆蓋已儲存的表單。套用後請再按儲存設定才會正式生效。',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '建議初版包含 ${recommended.orderQuestionCount} 題訂單資訊、${recommended.petQuestionCount} 題寵物資訊。',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _saving ? null : _applyRecommended,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('套用建議初版'),
              ),
              if (showPreviewButton)
                OutlinedButton.icon(
                  onPressed: _saving ? null : _previewForm,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('填寫預覽'),
                ),
            ],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      section.title.isEmpty ? '未命名分類' : section.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '題目 ${section.questionCount}　必填 ${section.requiredCount}　${section.enabled ? '已啟用' : '未啟用'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
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
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      _scopeTag(
                        question.answerScope.shortLabel,
                        pet: question.answerScope == CustomFormAnswerScope.pet,
                      ),
                      if (question.conditionCardLabel.isNotEmpty)
                        _scopeTag(question.conditionCardLabel, condition: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${question.type.labelWithHint}　${question.collectsRequired ? '必填' : '選填'}　${question.enabled ? '啟用' : '停用'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('啟用', style: TextStyle(fontSize: 13)),
                    value: question.enabled,
                    onChanged: (bool value) {
                      final List<CustomFormQuestion> questions =
                          List<CustomFormQuestion>.from(section.questions);
                      questions[questionIndex] = question.copyWith(
                        enabled: value,
                      );
                      _replaceSection(
                        sectionIndex,
                        section.copyWith(questions: questions),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('必填', style: TextStyle(fontSize: 13)),
                    value: question.required,
                    onChanged: (bool value) {
                      final List<CustomFormQuestion> questions =
                          List<CustomFormQuestion>.from(section.questions);
                      questions[questionIndex] = question.copyWith(
                        required: value,
                      );
                      _replaceSection(
                        sectionIndex,
                        section.copyWith(questions: questions),
                      );
                    },
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
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              TextButton.icon(
                onPressed: () => _editQuestion(
                  sectionIndex,
                  null,
                  createScope: CustomFormAnswerScope.order,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('＋ 新增訂單資訊題目'),
              ),
              TextButton.icon(
                onPressed: () => _editQuestion(
                  sectionIndex,
                  null,
                  createScope: CustomFormAnswerScope.pet,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('＋ 新增寵物資訊題目'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scopeTag(
    String label, {
    bool pet = false,
    bool condition = false,
  }) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color bg;
    final Color fg;
    if (condition) {
      bg = colors.tertiaryContainer;
      fg = colors.onTertiaryContainer;
    } else if (pet) {
      bg = const Color(0xFFD7EDE3);
      fg = const Color(0xFF1F5C45);
    } else {
      bg = colors.primaryContainer;
      fg = colors.onPrimaryContainer;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
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
