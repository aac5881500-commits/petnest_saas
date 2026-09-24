// 檔案名稱：lib/features/admin/widgets/admin_booking_form_answers_section.dart
// 功能說明：後台表單資料：客戶送單唯讀，僅手動訂單表單可編輯（含寵物資訊）。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_order_form_answers.dart';
import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/custom_form_pet_condition.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';
import 'package:petnest_saas/core/services/booking_form_visibility.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/services/custom_form_service.dart';
import 'package:petnest_saas/core/services/pet_shop_form_answers.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_form_focus.dart';
import 'package:petnest_saas/features/custom_form/widgets/order_custom_form_fill.dart';
import 'package:petnest_saas/features/custom_form/widgets/order_form_answers_view.dart';

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

  static bool hasVisibleAnswers(
    dynamic raw, {
    Map<String, dynamic> petAnswersByPetId = const <String, dynamic>{},
  }) {
    return OrderFormAnswersView.hasVisibleContent(
      orderRaw: raw,
      petAnswersByPetId: petAnswersByPetId,
    );
  }

  static int filledCount(
    dynamic raw, {
    Map<String, dynamic> petAnswersByPetId = const <String, dynamic>{},
  }) {
    return (CustomFormAnswerSnapshot.tryParse(raw)?.filledCount ?? 0) +
        BookingOrderFormAnswers.filledCountOfMap(petAnswersByPetId);
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> pets = petsOf(data);
    final dynamic customerRaw =
        data['customFormAnswers'] ??
        data['bookingFormAnswers'] ??
        data['formAnswers'];
    final dynamic adminRaw = data['adminCustomFormAnswers'];
    final Map<String, dynamic> customerPets =
        BookingOrderFormAnswers.resolveByPetId(booking: data, admin: false);
    final Map<String, dynamic> adminPets =
        BookingOrderFormAnswers.resolveByPetId(booking: data, admin: true);
    final bool showCustomer = BookingFormVisibility.showCustomerSubmitForm(
      data: data,
      hasAnswers: hasVisibleAnswers(
        customerRaw,
        petAnswersByPetId: customerPets,
      ),
    );
    final bool showAdmin = BookingFormVisibility.showAdminCreateForm(
      data: data,
      isShopView: true,
      hasAnswers: hasVisibleAnswers(adminRaw, petAnswersByPetId: adminPets),
    );
    return Column(
      children: <Widget>[
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
              petField: BookingOrderFormAnswers.petFormAnswersByPetIdField,
              title: '客戶送單表單',
              fallback: data['bookingFormAnswers'] ?? data['formAnswers'],
              data: data,
              pets: pets,
              petAnswersByPetId: customerPets,
              editable: false,
              admin: false,
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
              petField: BookingOrderFormAnswers.adminPetFormAnswersByPetIdField,
              title: '手動訂單表單',
              data: data,
              pets: pets,
              petAnswersByPetId: adminPets,
              editable: true,
              admin: true,
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
    required this.petField,
    required this.title,
    required this.data,
    required this.pets,
    required this.petAnswersByPetId,
    required this.editable,
    required this.admin,
    required this.anchor,
    this.fallback,
  });

  final String shopId;
  final String bookingId;
  final String field;
  final String petField;
  final String title;
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> pets;
  final Map<String, dynamic> petAnswersByPetId;
  final bool editable;
  final bool admin;
  final AdminBookingFormAnchor anchor;
  final dynamic fallback;

  @override
  Widget build(BuildContext context) {
    final dynamic raw = data[field] ?? fallback;
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
          OrderFormAnswersView(
            orderRaw: raw,
            petAnswersByPetId: petAnswersByPetId,
            pets: pets,
            theme: HomeThemeModel.classicDefault,
            orderTitle: '訂單資訊',
          ),
          if (editable && !BookingSettlementMath.isSettlementLocked(data))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _edit(context, raw),
                child: const Text('編輯'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, dynamic raw) async {
    CustomFormModel live = await CustomFormService.instance.getForm(
      shopId: shopId,
      formType: CustomFormType.adminCreate,
    );
    if (!live.shouldCollectAnswers) {
      final CustomFormAnswerSnapshot? snapshot =
          CustomFormAnswerSnapshot.tryParse(raw);
      if (snapshot != null && !snapshot.isEmpty) {
        live = snapshot.toEditableForm(shopId: shopId);
      }
    }
    Map<String, dynamic> orderAnswers =
        CustomFormAnswerSnapshot.tryParse(raw)?.toValueMap() ??
        <String, dynamic>{};
    final Map<String, Map<String, dynamic>> petAnswers =
        <String, Map<String, dynamic>>{
          for (final MapEntry<String, dynamic> entry
              in petAnswersByPetId.entries)
            entry.key:
                CustomFormAnswerSnapshot.tryParse(entry.value)?.toValueMap() ??
                <String, dynamic>{},
        };
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
                    children: <Widget>[
                      Text(
                        '編輯$title',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: OrderCustomFormFill(
                            form: live.copyWith(enabled: true),
                            title: title,
                            orderAnswers: orderAnswers,
                            petAnswersByPetId: petAnswers,
                            pets: pets,
                            theme: HomeThemeModel.classicDefault,
                            onOrderChanged: (Map<String, dynamic> next) {
                              setModal(() => orderAnswers = next);
                            },
                            onPetChanged:
                                (String petId, Map<String, dynamic> next) {
                                  setModal(() {
                                    petAnswers[petId] = next;
                                  });
                                },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          final CustomFormValidationResult order =
                              BookingOrderFormAnswers.validateOrder(
                                form: live,
                                answersByQuestionId: orderAnswers,
                              );
                          if (!order.isValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  order.message.isEmpty
                                      ? '請完成必填題'
                                      : order.message,
                                ),
                              ),
                            );
                            return;
                          }
                          for (final Map<String, dynamic> pet in pets) {
                            final String petId = CustomFormPetCondition.petIdOf(
                              pet,
                            );
                            final CustomFormValidationResult petCheck =
                                BookingOrderFormAnswers.validatePet(
                                  form: live,
                                  pet: pet,
                                  answersByQuestionId:
                                      petAnswers[petId] ??
                                      const <String, dynamic>{},
                                );
                            if (!petCheck.isValid) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(petCheck.message)),
                              );
                              return;
                            }
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
    final CustomFormAnswerSnapshot? orderSnapshot =
        BookingOrderFormAnswers.buildOrderSnapshot(
          form: live,
          answersByQuestionId: orderAnswers,
        );
    final Map<String, dynamic> byPetId = BookingOrderFormAnswers.encodeByPetId(
      form: live,
      pets: pets,
      answersByPetId: petAnswers,
    );
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update(<String, dynamic>{
          if (orderSnapshot != null) field: orderSnapshot.toFirestoreMap(),
          petField: byPetId,
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
        'petField': petField,
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
