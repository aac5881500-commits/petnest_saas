// 檔案名稱：lib/features/booking/models/booking_form_submit_data.dart
// 功能說明：BookingFormPage 送出時回傳的聯絡、緊急、付款與自訂表單答案資料物件。

import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';

class BookingFormSubmitData {
  const BookingFormSubmitData({
    required this.fullAddress,
    required this.emergencyName,
    required this.emergencyPhone,
    required this.emergencyRelation,
    required this.emergencyAddress,
    required this.secondaryPhone,
    required this.calculatedDeposit,
    required this.paymentMethod,
    required this.payAmountType,
    required this.termsConsent,
    this.customFormAnswers,
    this.petFormAnswersByPetId = const <String, dynamic>{},
  });

  final String fullAddress;
  final String emergencyName;
  final String emergencyPhone;
  final String emergencyRelation;
  final String emergencyAddress;
  final String secondaryPhone;
  final int calculatedDeposit;
  final String paymentMethod;
  final String payAmountType;
  final TermsConsentSnapshot termsConsent;
  final CustomFormAnswerSnapshot? customFormAnswers;
  final Map<String, dynamic> petFormAnswersByPetId;
}
