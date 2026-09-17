// 檔案名稱：lib/features/custom_form/widgets/custom_form_response_fields.dart
// 功能說明：店家自訂表單前台填寫元件，依表單分類與題型產生輸入欄位、保存答案並驗證必填題目。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/pet/widgets/pet_profile_form.dart';

class CustomFormResponseFields extends StatelessWidget {
  const CustomFormResponseFields({
    super.key,
    required this.form,
    required this.answers,
    required this.onChanged,
    required this.theme,
    this.fieldKeys,
  });

  final CustomFormModel form;
  final Map<String, dynamic> answers;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final HomeThemeModel theme;
  final Map<String, GlobalKey>? fieldKeys;

  @override
  Widget build(BuildContext context) {
    if (!form.shouldCollectAnswers) {
      return const SizedBox.shrink();
    }
    final List<Widget> children = <Widget>[];
    for (final CustomFormSection section in form.sections) {
      if (!section.enabled) {
        continue;
      }
      final List<CustomFormQuestion> questions = section.questions
          .where(
            (CustomFormQuestion question) =>
                question.enabled && question.id.trim().isNotEmpty,
          )
          .toList();
      if (questions.isEmpty) {
        continue;
      }
      children.add(
        PetFormSectionCard(
          theme: theme,
          icon: Icons.assignment_outlined,
          title: section.title.trim().isEmpty ? form.title : section.title,
          children: <Widget>[
            if (section.description.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  section.description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
            for (int i = 0; i < questions.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 12),
              _QuestionField(
                key: fieldKeys?[questions[i].id],
                theme: theme,
                question: questions[i],
                value: answers[questions[i].id],
                onChanged: (dynamic value) {
                  final Map<String, dynamic> next = Map<String, dynamic>.from(
                    answers,
                  );
                  next[questions[i].id] = value;
                  onChanged(next);
                },
              ),
            ],
          ],
        ),
      );
      children.add(const SizedBox(height: 12));
    }
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _QuestionField extends StatelessWidget {
  const _QuestionField({
    super.key,
    required this.theme,
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final HomeThemeModel theme;
  final CustomFormQuestion question;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  String get _label {
    return question.collectsRequired ? '${question.label} *' : question.label;
  }

  InputDecoration _inputDecoration({String? hint}) {
    final String description = question.description.trim();
    return petProfileInputDecoration(
      theme: theme,
      label: _label,
      hint: hint ?? question.placeholder,
    ).copyWith(
      helperText: description.isEmpty ? null : description,
      helperMaxLines: 5,
    );
  }

  Widget _helpText() {
    final String description = question.description.trim();
    if (description.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        description,
        style: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: theme.textColor.withValues(alpha: 0.68),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case CustomFormQuestionType.longText:
        return TextFormField(
          initialValue: (value ?? '').toString(),
          minLines: 3,
          maxLines: 6,
          style: TextStyle(fontSize: 14, color: theme.textColor),
          decoration: _inputDecoration(),
          validator: (_) => CustomFormAnswerSnapshot.requiredError(
            question: question,
            raw: value,
          ),
          onChanged: onChanged,
        );
      case CustomFormQuestionType.number:
        return TextFormField(
          initialValue: value == null ? '' : value.toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
          style: TextStyle(fontSize: 14, color: theme.textColor),
          decoration: _inputDecoration(),
          validator: (_) => CustomFormAnswerSnapshot.requiredError(
            question: question,
            raw: value,
          ),
          onChanged: (String text) {
            if (text.trim().isEmpty) {
              onChanged(null);
              return;
            }
            final num? parsed = num.tryParse(text.trim());
            onChanged(parsed ?? text);
          },
        );
      case CustomFormQuestionType.yesNo:
        return FormField<bool>(
          initialValue: value is bool ? value as bool : null,
          validator: (_) => CustomFormAnswerSnapshot.requiredError(
            question: question,
            raw: value,
          ),
          builder: (FormFieldState<bool> state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.textColor,
                  ),
                ),
                _helpText(),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _choice(
                        label: '是',
                        selected: value == true,
                        onTap: () {
                          onChanged(true);
                          state.didChange(true);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _choice(
                        label: '否',
                        selected: value == false,
                        onTap: () {
                          onChanged(false);
                          state.didChange(false);
                        },
                      ),
                    ),
                  ],
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      state.errorText!,
                      style: TextStyle(fontSize: 12, color: theme.primaryColor),
                    ),
                  ),
              ],
            );
          },
        );
      case CustomFormQuestionType.singleChoice:
      case CustomFormQuestionType.dropdown:
        final List<CustomFormOption> options =
            List<CustomFormOption>.from(question.options)..sort(
              (CustomFormOption a, CustomFormOption b) =>
                  a.sortOrder.compareTo(b.sortOrder),
            );
        return DropdownButtonFormField<String>(
          initialValue:
              options.any(
                (CustomFormOption option) =>
                    option.id == (value ?? '').toString(),
              )
              ? (value ?? '').toString()
              : null,
          isExpanded: true,
          decoration: _inputDecoration(),
          items: options
              .map(
                (CustomFormOption option) => DropdownMenuItem<String>(
                  value: option.id,
                  child: Text(
                    option.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.textColor),
                  ),
                ),
              )
              .toList(),
          validator: (_) => CustomFormAnswerSnapshot.requiredError(
            question: question,
            raw: value,
          ),
          onChanged: onChanged,
        );
      case CustomFormQuestionType.multipleChoice:
        return FormField<List<String>>(
          initialValue:
              CustomFormAnswerItem.decodeStoredValue(
                    type: CustomFormQuestionType.multipleChoice,
                    raw: value,
                  )
                  as List<String>,
          validator: (_) => CustomFormAnswerSnapshot.requiredError(
            question: question,
            raw: value,
          ),
          builder: (FormFieldState<List<String>> state) {
            final List<String> selected =
                CustomFormAnswerItem.decodeStoredValue(
                      type: CustomFormQuestionType.multipleChoice,
                      raw: value,
                    )
                    as List<String>;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.textColor,
                  ),
                ),
                _helpText(),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: question.options.map((CustomFormOption option) {
                    final bool checked = selected.contains(option.id);
                    return FilterChip(
                      label: Text(option.label),
                      selected: checked,
                      selectedColor: theme.primaryColor.withValues(alpha: 0.18),
                      checkmarkColor: theme.primaryColor,
                      onSelected: (bool next) {
                        final List<String> updated = List<String>.from(
                          selected,
                        );
                        if (next) {
                          updated.add(option.id);
                        } else {
                          updated.remove(option.id);
                        }
                        onChanged(updated);
                        state.didChange(updated);
                      },
                    );
                  }).toList(),
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      state.errorText!,
                      style: TextStyle(fontSize: 12, color: theme.primaryColor),
                    ),
                  ),
              ],
            );
          },
        );
      case CustomFormQuestionType.date:
      case CustomFormQuestionType.yearMonth:
        return FormField<String>(
          initialValue: (value ?? '').toString(),
          validator: (_) => CustomFormAnswerSnapshot.requiredError(
            question: question,
            raw: value,
          ),
          builder: (FormFieldState<String> state) {
            return InkWell(
              onTap: () async {
                final DateTime now = DateTime.now();
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: DateTime(1990),
                  lastDate: DateTime(now.year + 8, 12, 31),
                  helpText: question.type == CustomFormQuestionType.yearMonth
                      ? '選擇年月'
                      : '選擇日期',
                );
                if (picked == null) {
                  return;
                }
                final String stored =
                    question.type == CustomFormQuestionType.yearMonth
                    ? '${picked.year.toString().padLeft(4, '0')}-'
                          '${picked.month.toString().padLeft(2, '0')}'
                    : '${picked.year.toString().padLeft(4, '0')}-'
                          '${picked.month.toString().padLeft(2, '0')}-'
                          '${picked.day.toString().padLeft(2, '0')}';
                onChanged(stored);
                state.didChange(stored);
              },
              child: InputDecorator(
                decoration: _inputDecoration(
                  hint: question.placeholder.isEmpty
                      ? '點擊選擇'
                      : question.placeholder,
                ).copyWith(errorText: state.errorText),
                child: Text(
                  CustomFormAnswerSnapshot.displayValueFor(
                        question: question,
                        raw: value,
                      ).isEmpty
                      ? '點擊選擇'
                      : CustomFormAnswerSnapshot.displayValueFor(
                          question: question,
                          raw: value,
                        ),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textColor.withValues(
                      alpha: (value == null || value.toString().isEmpty)
                          ? 0.45
                          : 1,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      case CustomFormQuestionType.shortText:
        return TextFormField(
          initialValue: (value ?? '').toString(),
          style: TextStyle(fontSize: 14, color: theme.textColor),
          decoration: _inputDecoration(),
          validator: (_) => CustomFormAnswerSnapshot.requiredError(
            question: question,
            raw: value,
          ),
          onChanged: onChanged,
        );
    }
  }

  Widget _choice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? theme.primaryColor.withValues(alpha: 0.16)
          : theme.backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? theme.primaryColor : theme.cardBorderColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
        ),
      ),
    );
  }
}
