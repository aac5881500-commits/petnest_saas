// 檔案名稱：lib/features/admin/widgets/admin_booking_form_answers_section.dart
// 功能說明：後台顯示／編輯客戶送單表單與手動訂單表單答案（僅該筆訂單）。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';
import 'package:petnest_saas/core/services/booking_form_visibility.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
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

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> pets = data['pets'] is List
        ? (data['pets'] as List)
              .whereType<Map>()
              .map((Map item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final dynamic customerRaw =
        data['customFormAnswers'] ??
        data['bookingFormAnswers'] ??
        data['formAnswers'];
    final dynamic adminRaw = data['adminCustomFormAnswers'];
    final bool showCustomer = BookingFormVisibility.showCustomerSubmitForm(
      data: data,
      hasAnswers: _hasVisibleAnswers(customerRaw),
    );
    final bool showAdmin = BookingFormVisibility.showAdminCreateForm(
      data: data,
      isShopView: true,
      hasAnswers: _hasVisibleAnswers(adminRaw),
    );
    return Column(
      children: <Widget>[
        AdminBookingPetCareForms(
          shopId: shopId,
          userId: (data['userId'] ?? '').toString(),
          pets: pets,
        ),
        if (showCustomer)
          _FormBlock(
            shopId: shopId,
            bookingId: bookingId,
            field: 'customFormAnswers',
            title: '客戶送單表單',
            fallback: data['bookingFormAnswers'] ?? data['formAnswers'],
            data: data,
          ),
        if (showAdmin)
          _FormBlock(
            shopId: shopId,
            bookingId: bookingId,
            field: 'adminCustomFormAnswers',
            title: '手動訂單表單',
            data: data,
          ),
      ],
    );
  }

  static bool _hasVisibleAnswers(dynamic raw) {
    final CustomFormAnswerSnapshot? snapshot =
        CustomFormAnswerSnapshot.tryParse(raw);
    if (snapshot == null) {
      return false;
    }
    return snapshot.answers.any(
      (CustomFormAnswerItem item) => item.displayValue.trim().isNotEmpty,
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
    this.fallback,
  });

  final String shopId;
  final String bookingId;
  final String field;
  final String title;
  final Map<String, dynamic> data;
  final dynamic fallback;

  @override
  Widget build(BuildContext context) {
    final dynamic raw = data[field] ?? fallback;
    final CustomFormAnswerSnapshot? snapshot =
        CustomFormAnswerSnapshot.tryParse(raw);
    return AdminBookingDetailSection(
      title: title,
      collapsible: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CustomFormAnswerView(
            raw: raw,
            title: title,
            theme: HomeThemeModel.classicDefault,
          ),
          if (snapshot != null &&
              !snapshot.isEmpty &&
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
    CustomFormAnswerSnapshot snapshot,
  ) async {
    final CustomFormModel form = snapshot.toEditableForm(shopId: shopId);
    Map<String, dynamic> answers = snapshot.toValueMap();
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
        'before': snapshot.toCallableMap(),
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
