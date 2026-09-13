// 檔案名稱：lib/features/admin/widgets/admin_booking_form_answers_section.dart
// 功能說明：後台表單資料：寵物照護／客戶送單唯讀，僅手動訂單表單可編輯。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';
import 'package:petnest_saas/core/services/booking_form_visibility.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/services/custom_form_service.dart';
import 'package:petnest_saas/core/services/pet_shop_form_answers.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_form_focus.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_care_forms.dart';
import 'package:petnest_saas/features/custom_form/widgets/custom_form_answer_view.dart';
import 'package:petnest_saas/features/custom_form/widgets/custom_form_response_fields.dart';

class AdminBookingFormAnswersSection extends StatelessWidget {
  const AdminBookingFormAnswersSection({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.data,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> data;

  static List<Map<String, dynamic>> petsOf(Map<String, dynamic> data) {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    final Set<String> seen = <String>{};
    int snapshotsMissingPetId = 0;
    void add(Map<String, dynamic> pet) {
      final String id = PetShopFormAnswers.petIdOf(pet);
      if (id.isNotEmpty) {
        if (seen.contains(id)) {
          return;
        }
        seen.add(id);
      } else {
        snapshotsMissingPetId += 1;
      }
      out.add(pet);
    }

    if (data['pets'] is List) {
      for (final Object? item in data['pets'] as List) {
        if (item is Map) {
          add(Map<String, dynamic>.from(item));
        }
      }
    }
    final Object? ids = data['petIds'];
    if (ids is List) {
      final List<String> petIds = ids
          .map((Object? id) => id.toString().trim())
          .where((String id) => id.isNotEmpty)
          .toList();
      if (out.isNotEmpty && out.length == petIds.length) {
        return out;
      }
      int positionalBudget = snapshotsMissingPetId;
      for (final String petId in petIds) {
        if (seen.contains(petId)) {
          continue;
        }
        if (positionalBudget > 0) {
          positionalBudget -= 1;
          continue;
        }
        add(<String, dynamic>{'petId': petId});
      }
    }
    return out;
  }

  static bool hasVisibleAnswers(dynamic raw) {
    return (CustomFormAnswerSnapshot.tryParse(raw)?.filledCount ?? 0) > 0;
  }

  static int filledCount(dynamic raw) {
    return CustomFormAnswerSnapshot.tryParse(raw)?.filledCount ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> pets = petsOf(data);
    final dynamic customerRaw =
        data['customFormAnswers'] ??
        data['bookingFormAnswers'] ??
        data['formAnswers'];
    final dynamic adminRaw = data['adminCustomFormAnswers'];
    final bool showCustomer = BookingFormVisibility.showCustomerSubmitForm(
      data: data,
      hasAnswers: hasVisibleAnswers(customerRaw),
    );
    final bool showAdmin = BookingFormVisibility.showAdminCreateForm(
      data: data,
      isShopView: true,
      hasAnswers: hasVisibleAnswers(adminRaw),
    );
    return Column(
      children: <Widget>[
        KeyedSubtree(
          key:
              AdminBookingFormFocusScope.maybeOf(
                context,
              )?.anchorKeys[AdminBookingFormAnchor.petCare] ??
              const ValueKey<String>('form-anchor-petCare'),
          child: AdminBookingPetCareForms(
            shopId: shopId,
            userId: PetShopFormAnswers.bookingUserId(data),
            bookingId: bookingId,
            pets: pets,
          ),
        ),
        if (showCustomer)
          KeyedSubtree(
            key:
                AdminBookingFormFocusScope.maybeOf(
                  context,
                )?.anchorKeys[AdminBookingFormAnchor.customerSubmit] ??
                const ValueKey<String>('form-anchor-customerSubmit'),
            child: _FormBlock(
              shopId: shopId,
              bookingId: bookingId,
              field: 'customFormAnswers',
              title: '客戶送單表單',
              fallback: data['bookingFormAnswers'] ?? data['formAnswers'],
              data: data,
              editable: false,
              anchor: AdminBookingFormAnchor.customerSubmit,
            ),
          ),
        if (showAdmin)
          KeyedSubtree(
            key:
                AdminBookingFormFocusScope.maybeOf(
                  context,
                )?.anchorKeys[AdminBookingFormAnchor.adminCreate] ??
                const ValueKey<String>('form-anchor-adminCreate'),
            child: _FormBlock(
              shopId: shopId,
              bookingId: bookingId,
              field: 'adminCustomFormAnswers',
              title: '手動訂單表單',
              data: data,
              editable: true,
              anchor: AdminBookingFormAnchor.adminCreate,
            ),
          ),
      ],
    );
  }
}

class _FormBlock extends StatelessWidget {
  const _FormBlock({
    required this.shopId,
    required this.bookingId,
    required this.field,
    required this.title,
    required this.data,
    required this.editable,
    required this.anchor,
    this.fallback,
  });

  final String shopId;
  final String bookingId;
  final String field;
  final String title;
  final Map<String, dynamic> data;
  final bool editable;
  final AdminBookingFormAnchor anchor;
  final dynamic fallback;

  @override
  Widget build(BuildContext context) {
    final dynamic raw = data[field] ?? fallback;
    final CustomFormAnswerSnapshot? snapshot =
        CustomFormAnswerSnapshot.tryParse(raw);
    final AdminBookingFormFocusScope? focus =
        AdminBookingFormFocusScope.maybeOf(context);
    final bool expanded = focus?.isExpanded(anchor) ?? true;
    return AdminBookingDetailSection(
      title: title,
      collapsible: true,
      initiallyExpanded: expanded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CustomFormAnswerView(
            raw: raw,
            title: title,
            theme: HomeThemeModel.classicDefault,
          ),
          if (editable &&
              !BookingSettlementMath.isSettlementLocked(data))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _edit(context, snapshot),
                child: const Text('編輯'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    CustomFormAnswerSnapshot? snapshot,
  ) async {
    CustomFormModel form;
    Map<String, dynamic> answers;
    if (snapshot != null && !snapshot.isEmpty) {
      form = snapshot.toEditableForm(shopId: shopId);
      answers = snapshot.toValueMap();
    } else {
      form = await CustomFormService.instance.getForm(
        shopId: shopId,
        formType: CustomFormType.adminCreate,
      );
      answers = <String, dynamic>{};
    }
    if (!context.mounted) {
      return;
    }
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModal) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '編輯$title',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          child: CustomFormResponseFields(
                            form: form,
                            answers: answers,
                            theme: HomeThemeModel.classicDefault,
                            onChanged: (Map<String, dynamic> next) {
                              setModal(() => answers = next);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          final CustomFormValidationResult result =
                              CustomFormAnswerSnapshot.validate(
                                form: form,
                                answersByQuestionId: answers,
                              );
                          if (!result.isValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.message.isEmpty
                                      ? '請完成必填題'
                                      : result.message,
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context, true);
                        },
                        child: const Text('儲存'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    if (saved != true) {
      return;
    }
    final CustomFormAnswerSnapshot next = CustomFormAnswerSnapshot.build(
      form: form,
      answersByQuestionId: answers,
    );
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update(<String, dynamic>{
          field: next.toFirestoreMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
    final User? user = FirebaseAuth.instance.currentUser;
    await ActionLogService.instance.logAction(
      shopId: shopId,
      targetType: 'booking',
      targetId: bookingId,
      action: 'booking_form_answers_updated',
      operatorUid: user?.uid ?? '',
      operatorRole: 'staff',
      payload: <String, dynamic>{
        'field': field,
        'before': snapshot?.toCallableMap(),
        'after': next.toCallableMap(),
        'operatorEmail': (user?.email ?? '').trim(),
      },
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$title已更新')));
    }
  }
}
