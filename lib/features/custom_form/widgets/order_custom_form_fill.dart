// 檔案名稱：lib/features/custom_form/widgets/order_custom_form_fill.dart
// 功能說明：訂單資訊一次填寫；寵物資訊一次只顯示選取的那一隻。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_order_form_answers.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/custom_form_pet_condition.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/custom_form/widgets/custom_form_response_fields.dart';

class OrderCustomFormFill extends StatefulWidget {
  const OrderCustomFormFill({
    super.key,
    required this.form,
    required this.orderAnswers,
    required this.petAnswersByPetId,
    required this.pets,
    required this.onOrderChanged,
    required this.onPetChanged,
    required this.theme,
    this.title = '送出訂單表單',
    this.subtitle = '',
    this.sectionKey,
    this.fieldKeys,
  });

  final CustomFormModel form;
  final Map<String, dynamic> orderAnswers;
  final Map<String, Map<String, dynamic>> petAnswersByPetId;
  final List<Map<String, dynamic>> pets;
  final ValueChanged<Map<String, dynamic>> onOrderChanged;
  final void Function(String petId, Map<String, dynamic> answers) onPetChanged;
  final HomeThemeModel theme;
  final String title;
  final String subtitle;
  final Key? sectionKey;
  final Map<String, GlobalKey>? fieldKeys;

  @override
  State<OrderCustomFormFill> createState() => _OrderCustomFormFillState();
}

class _OrderCustomFormFillState extends State<OrderCustomFormFill> {
  String? _selectedPetId;

  @override
  void initState() {
    super.initState();
    _selectedPetId = _pickInitialPetId();
  }

  @override
  void didUpdateWidget(OrderCustomFormFill oldWidget) {
    super.didUpdateWidget(oldWidget);
    final List<String> ids = _uniquePets
        .where(_hasQuestions)
        .map(CustomFormPetCondition.petIdOf)
        .toList();

    if (_selectedPetId == null || !ids.contains(_selectedPetId)) {
      _selectedPetId = _pickInitialPetId();
    }
  }

  List<Map<String, dynamic>> get _uniquePets {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    final Set<String> seen = <String>{};

    for (final Map<String, dynamic> pet in widget.pets) {
      final String petId = CustomFormPetCondition.petIdOf(pet);
      if (petId.isEmpty || seen.contains(petId)) {
        continue;
      }
      seen.add(petId);
      out.add(pet);
    }

    return out;
  }

  CustomFormModel _petForm(Map<String, dynamic> pet) {
    return BookingOrderFormAnswers.petFormFor(form: widget.form, pet: pet);
  }

  bool _hasQuestions(Map<String, dynamic> pet) {
    return _petForm(pet).hasEnabledQuestions;
  }

  bool _hasAnyAnswer(Map<String, dynamic> pet) {
    final String petId = CustomFormPetCondition.petIdOf(pet);
    final Map<String, dynamic> answers =
        widget.petAnswersByPetId[petId] ?? const <String, dynamic>{};

    for (final Object? value in answers.values) {
      if (value == null) {
        continue;
      }
      if (value is String && value.trim().isEmpty) {
        continue;
      }
      if (value is Iterable && value.isEmpty) {
        continue;
      }
      if (value is Map && value.isEmpty) {
        continue;
      }
      return true;
    }
    return false;
  }

  bool _isComplete(Map<String, dynamic> pet) {
    final String petId = CustomFormPetCondition.petIdOf(pet);

    return BookingOrderFormAnswers.validatePet(
      form: widget.form,
      pet: pet,
      answersByQuestionId:
          widget.petAnswersByPetId[petId] ?? const <String, dynamic>{},
    ).isValid;
  }

  String _optionLabel(Map<String, dynamic> pet) {
    final String name = (pet['name'] ?? '').toString().trim();
    final String who = name.isEmpty ? '寵物' : name;

    return _hasAnyAnswer(pet) ? '$who・已填寫' : who;
  }

  String? _pickInitialPetId() {
    final List<Map<String, dynamic>> pets = _uniquePets
        .where(_hasQuestions)
        .toList();

    if (pets.isEmpty) {
      return null;
    }

    for (final Map<String, dynamic> pet in pets) {
      if (!_hasAnyAnswer(pet)) {
        return CustomFormPetCondition.petIdOf(pet);
      }
    }

    for (final Map<String, dynamic> pet in pets) {
      if (!_isComplete(pet)) {
        return CustomFormPetCondition.petIdOf(pet);
      }
    }

    return CustomFormPetCondition.petIdOf(pets.first);
  }

  Map<String, dynamic>? _selectedPet() {
    for (final Map<String, dynamic> pet in _uniquePets.where(_hasQuestions)) {
      if (CustomFormPetCondition.petIdOf(pet) == _selectedPetId) {
        return pet;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.form.shouldCollectAnswers) {
      return const SizedBox.shrink();
    }

    final CustomFormModel orderForm = BookingOrderFormAnswers.orderForm(
      widget.form,
    );
    final bool showOrder = orderForm.hasEnabledQuestions;
    final bool showPets =
        BookingOrderFormAnswers.hasPetQuestions(widget.form) &&
        _uniquePets.any(_hasQuestions);

    if (!showOrder && !showPets) {
      return const SizedBox.shrink();
    }

    return KeyedSubtree(
      key: widget.sectionKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.title.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: widget.theme.textColor,
                ),
              ),
            ),
          if (widget.subtitle.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                widget.subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.theme.textColor.withValues(alpha: 0.72),
                ),
              ),
            ),
          if (showOrder) ...<Widget>[
            Text(
              '訂單資訊',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: widget.theme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            CustomFormResponseFields(
              form: orderForm.copyWith(enabled: true),
              answers: widget.orderAnswers,
              onChanged: widget.onOrderChanged,
              theme: widget.theme,
              fieldKeys: widget.fieldKeys,
            ),
            if (showPets) const SizedBox(height: 16),
          ],
          if (showPets) _petSelector(),
        ],
      ),
    );
  }

  Widget _petSelector() {
    final List<Map<String, dynamic>> pets = _uniquePets
        .where(_hasQuestions)
        .toList();
    final String selectedId =
        _selectedPetId ?? CustomFormPetCondition.petIdOf(pets.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '選擇寵物填寫',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: widget.theme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('pet-fill-$selectedId-${pets.length}'),
          initialValue: selectedId,
          decoration: const InputDecoration(
            labelText: '寵物',
            border: OutlineInputBorder(),
          ),
          items: pets.map((Map<String, dynamic> pet) {
            final String petId = CustomFormPetCondition.petIdOf(pet);

            return DropdownMenuItem<String>(
              value: petId,
              child: Text(
                _optionLabel(pet),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: widget.theme.textColor,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? value) {
            if (value == null) {
              return;
            }

            setState(() {
              _selectedPetId = value;
            });
          },
        ),
        const SizedBox(height: 12),
        _petBlock(_selectedPet() ?? pets.first),
      ],
    );
  }

  Widget _petBlock(Map<String, dynamic> pet) {
    final CustomFormModel petForm = _petForm(pet);
    final String petId = CustomFormPetCondition.petIdOf(pet);

    final Map<String, GlobalKey>? keys = widget.fieldKeys == null
        ? null
        : <String, GlobalKey>{
            for (final MapEntry<String, GlobalKey> entry
                in widget.fieldKeys!.entries)
              if (entry.key.startsWith('$petId::'))
                entry.key.substring(petId.length + 2): entry.value,
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          CustomFormPetCondition.careSectionTitle(pet),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: widget.theme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        CustomFormResponseFields(
          form: petForm.copyWith(enabled: true),
          answers: widget.petAnswersByPetId[petId] ?? const <String, dynamic>{},
          theme: widget.theme,
          fieldKeys: keys,
          onChanged: (Map<String, dynamic> next) {
            if (petId.isEmpty) {
              return;
            }
            widget.onPetChanged(petId, next);
          },
        ),
      ],
    );
  }
}
