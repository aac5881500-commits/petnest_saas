// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_view_data.dart
// 功能說明：客戶端訂單詳細頁顯示資料：只做讀取與文案，不寫入 Firestore、不重算計價。

import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_parse.dart';

enum BookingDetailTermsState { confirmed, unconfirmed, needsReconfirm }

class BookingDetailFeeLine {
  const BookingDetailFeeLine({
    required this.label,
    required this.amount,
    this.subtitle = '',
    this.isDiscount = false,
    this.isTotal = false,
  });

  final String label;
  final int amount;
  final String subtitle;
  final bool isDiscount;
  final bool isTotal;
}

class BookingDetailTimelineItem {
  const BookingDetailTimelineItem({
    required this.title,
    this.time,
    this.active = false,
  });

  final String title;
  final DateTime? time;
  final bool active;
}

class BookingDetailPetInfo {
  const BookingDetailPetInfo({
    required this.name,
    required this.photoUrl,
    required this.careSummary,
    this.staffHidden = true,
  });

  final String name;
  final String photoUrl;
  final String careSummary;
  final bool staffHidden;
}

class BookingDetailViewData {
  BookingDetailViewData._({required this.raw, required this.docId});

  final Map<String, dynamic> raw;
  final String docId;

  factory BookingDetailViewData.fromBooking({
    required Map<String, dynamic>? data,
    required String docId,
  }) {
    return BookingDetailViewData._(
      raw: BookingDetailParse.parseMap(data),
      docId: docId.trim(),
    );
  }

  String get shopId => BookingDetailParse.parseString(raw['shopId']);

  String get shopName => BookingDetailParse.parseString(raw['shopName']);

  int get petCount {
    if (pets.isNotEmpty) {
      return pets.length;
    }
    return BookingDetailParse.parseList(raw['petIds']).length;
  }

  String get kind => BookingKind.resolve(raw);

  bool get isDaycare => kind == BookingKind.daycare;

  String get serviceLabel => BookingKind.label(kind);

  String get pageTitle => isDaycare ? '安親詳細' : '住宿詳細';

  String get bookingCode {
    final String code = BookingDetailParse.parseString(raw['bookingCode']);
    if (code.isNotEmpty) {
      return code;
    }
    if (docId.length <= 8) {
      return docId;
    }
    return docId.substring(0, 8);
  }

  String get status => BookingDetailParse.parseString(raw['status']);

  String get depositStatus =>
      BookingDetailParse.parseString(raw['depositStatus']);

  String get paymentMethod =>
      BookingDetailParse.parseString(raw['paymentMethod']);

  String get assignStatus =>
      BookingDetailParse.parseString(raw['assignStatus']);

  String get pricingMode {
    final String rawMode = BookingDetailParse.parseString(raw['pricingMode']);
    if (rawMode.isNotEmpty) {
      return DaycarePricingModes.normalize(rawMode);
    }
    if (isDaycare &&
        BookingDetailParse.parseString(raw['requestedRoomTypeId']).isNotEmpty) {
      return DaycarePricingModes.roomType;
    }
    return DaycarePricingModes.independentPlan;
  }

  bool get isIndependentDaycare =>
      isDaycare && !DaycarePricingModes.isRoomBased(pricingMode);

  bool get isRoomTypeDaycare =>
      isDaycare && DaycarePricingModes.isRoomBased(pricingMode);

  DateTime? get startDate =>
      BookingDetailParse.parseDate(raw['startDate']) ??
      BookingDetailParse.parseDate(raw['scheduledStartAt']);

  DateTime? get endDate =>
      BookingDetailParse.parseDate(raw['endDate']) ??
      BookingDetailParse.parseDate(raw['scheduledEndAt']);

  DateTime? get scheduledStartAt =>
      BookingDetailParse.parseDate(raw['scheduledStartAt']) ?? startDate;

  DateTime? get scheduledEndAt =>
      BookingDetailParse.parseDate(raw['scheduledEndAt']) ?? endDate;

  DateTime? get actualStartAt =>
      BookingDetailParse.parseDate(raw['actualStartAt']);

  DateTime? get actualEndAt => BookingDetailParse.parseDate(raw['actualEndAt']);

  DateTime? get checkOutAt => BookingDetailParse.parseDate(raw['checkOutAt']);

  DateTime? get createdAt => BookingDetailParse.parseDate(raw['createdAt']);

  DateTime? get confirmedAt =>
      BookingDetailParse.parseDate(raw['confirmedAt']) ??
      BookingDetailParse.parseDate(raw['depositPaidAt']);

  DateTime? get checkInAt => BookingDetailParse.parseDate(raw['checkInAt']);

  DateTime? get cancelledAt => BookingDetailParse.parseDate(raw['cancelledAt']);

  DateTime? get depositSubmittedAt =>
      BookingDetailParse.parseDate(raw['depositSubmittedAt']);

  DateTime? get paidAt => BookingDetailParse.parseDate(raw['paidAt']);

  int get nights {
    final int stored = BookingDetailParse.parseMoney(raw['nights']);
    if (stored > 0) {
      return stored;
    }
    if (startDate == null || endDate == null) {
      return 0;
    }
    final int diff = DateTime(endDate!.year, endDate!.month, endDate!.day)
        .difference(DateTime(startDate!.year, startDate!.month, startDate!.day))
        .inDays;
    return diff < 0 ? 0 : diff;
  }

  int get daycareDays {
    if (startDate == null || endDate == null) {
      return 1;
    }
    final DateTime start = DateTime(
      startDate!.year,
      startDate!.month,
      startDate!.day,
    );
    final DateTime end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    final int diff = end.difference(start).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  String get durationLabel {
    if (isDaycare) {
      if (isIndependentDaycare) {
        final int minutes = BookingDetailParse.parseMoney(
          raw['actualMinutes'] != null && raw['actualMinutes'] != 0
              ? raw['actualMinutes']
              : (raw['quotedMinutes'] ?? raw['includedMinutes']),
        );
        if (minutes > 0) {
          final int hours = minutes ~/ 60;
          final int rest = minutes % 60;
          if (hours > 0 && rest > 0) {
            return '$hours 小時 $rest 分';
          }
          if (hours > 0) {
            return '$hours 小時';
          }
          return '$minutes 分鐘';
        }
      }
      return '$daycareDays 天';
    }
    return '${nights <= 0 ? 1 : nights} 晚';
  }

  String get dateRangeLabel {
    if (startDate == null) {
      return '';
    }
    final String start = _dateText(startDate!);
    if (endDate == null || _sameDay(startDate!, endDate!)) {
      return start;
    }
    return '$start － ${_dateText(endDate!)}';
  }

  List<Map<String, dynamic>> get pets =>
      BookingDetailParse.parseMapList(raw['pets']);

  String get petNames {
    final List<String> names = pets
        .map(
          (Map<String, dynamic> pet) =>
              BookingDetailParse.parseString(pet['name']),
        )
        .where((String name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) {
      return '';
    }
    return names.join('、');
  }

  String get roomTypeName {
    if (isIndependentDaycare && !_roomAssigned) {
      return '';
    }
    final String requested = BookingDetailParse.parseString(
      raw['requestedRoomTypeName'],
    );
    final String assigned = BookingDetailParse.parseString(
      raw['roomTypeNameSnapshot'] ?? raw['roomTypeName'],
    );
    if (isRoomTypeDaycare) {
      return assigned.isNotEmpty ? assigned : requested;
    }
    return assigned.isNotEmpty ? assigned : requested;
  }

  String get roomName {
    final String name = BookingDetailParse.parseString(
      raw['roomName'] ?? raw['roomNumber'] ?? raw['roomNumberSnapshot'],
    );
    if (name == '---' || name == '-' || name == '—') {
      return '';
    }
    return name;
  }

  bool get _roomAssigned {
    final String roomId = BookingDetailParse.parseString(raw['roomId']);
    return roomId.isNotEmpty ||
        roomName.isNotEmpty ||
        assignStatus == 'assigned';
  }

  String get roomAssignmentLabel {
    if (_roomAssigned) {
      final String type = roomTypeName;
      final String number = roomName;
      if (type.isNotEmpty && number.isNotEmpty) {
        return '$type ・ $number';
      }
      if (number.isNotEmpty) {
        return number;
      }
      if (type.isNotEmpty) {
        return type;
      }
    }
    if (isIndependentDaycare) {
      return '店家確認後安排房型與房間';
    }
    if (isRoomTypeDaycare) {
      final String requested = BookingDetailParse.parseString(
        raw['requestedRoomTypeName'],
      );
      if (requested.isNotEmpty) {
        return '$requested ・ 店家確認後安排房間';
      }
      return '店家確認後安排房間';
    }
    if (roomTypeName.isNotEmpty) {
      return '$roomTypeName ・ 店家確認後安排房間';
    }
    return '店家確認後安排房間';
  }

  bool get showsPlaceholderDash =>
      roomAssignmentLabel.contains('---') || roomName == '---';

  String get statusTitle {
    if (status == 'cancelled') {
      return '已取消';
    }
    if (status == 'completed') {
      return '已完成';
    }
    if (status == 'checked_in') {
      return isDaycare ? '安親中' : '入住中';
    }
    if (status == 'confirmed') {
      if (_isUpcoming) {
        return isDaycare ? '即將安親' : '即將入住';
      }
      return '店家已確認';
    }
    if (depositStatus == 'pending_review') {
      return '付款資料審核中';
    }
    if (_needsPaymentAction) {
      return '等待付款';
    }
    return '等待店家確認';
  }

  bool get _isUpcoming {
    if (startDate == null) {
      return false;
    }
    final DateTime now = DateTime.now();
    final DateTime startDay = DateTime(
      startDate!.year,
      startDate!.month,
      startDate!.day,
    );
    final DateTime today = DateTime(now.year, now.month, now.day);
    return !startDay.isAfter(today.add(const Duration(days: 2))) &&
        !startDay.isBefore(today);
  }

  bool get _needsPaymentAction {
    if (status == 'cancelled' || status == 'completed') {
      return false;
    }
    if (remainingAmount > 0 &&
        (paymentMethod == PaymentMethodType.bankTransfer ||
            PaymentMethodType.isOnlinePayment(paymentMethod) ||
            depositStatus == 'unpaid' ||
            depositStatus == 'pending' ||
            depositStatus.isEmpty)) {
      if (depositStatus == 'pending_review' || depositStatus == 'confirmed') {
        return remainingAmount > 0 && depositStatus != 'pending_review';
      }
      if (status == 'pending' || status == 'unpaid') {
        return remainingAmount > 0 ||
            BookingDetailParse.parseMoney(raw['depositAmount']) > 0;
      }
    }
    return status == 'unpaid';
  }

  String get nextStepHint {
    if (status == 'cancelled') {
      return '此訂單已取消。';
    }
    if (status == 'completed') {
      return isDaycare ? '本次安親已完成，感謝您的預約。' : '本次住宿已完成，感謝您的預約。';
    }
    if (status == 'checked_in') {
      return isDaycare ? '安親進行中，可查看每日照護與房間服務。' : '住宿進行中，可查看每日照護與房間服務。';
    }
    if (depositStatus == 'pending_review') {
      return '付款資料已送出，店家確認後會更新付款狀態。';
    }
    if (status == 'confirmed') {
      return isDaycare ? '預約已確認，請於送達前完成相關資料。' : '房間已保留，請於入住前完成相關資料。';
    }
    if (statusTitle == '等待付款') {
      return '請在期限內完成付款，以保留本次預約。';
    }
    return '預約已送出，店家確認後會通知您。';
  }

  int get totalAmount {
    final int payable = BookingDetailParse.parseMoney(
      raw['totalPayableAmount'],
    );
    if (payable > 0) {
      return payable;
    }
    final int total = BookingDetailParse.parseMoney(raw['totalPrice']);
    if (total > 0) {
      return total;
    }
    if (isIndependentDaycare || isRoomTypeDaycare) {
      final int estimate = BookingDetailParse.parseMoney(
        raw['estimateTotalPrice'] ?? raw['quotedTotalPrice'],
      );
      if (estimate > 0) {
        return estimate;
      }
    }
    return BookingDetailParse.parseMoney(
      raw['totalAmount'] ?? raw['total'] ?? 0,
    );
  }

  int get paidAmount => BookingDetailParse.parseMoney(raw['paidAmount']);

  int get remainingAmount {
    final int remain = totalAmount - paidAmount;
    return remain < 0 ? 0 : remain;
  }

  bool get isPaidInFull => remainingAmount <= 0 && totalAmount > 0;

  bool get showEstimateLabel {
    if (!isDaycare) {
      return false;
    }
    if (status == 'completed') {
      return false;
    }
    if (BookingDetailParse.parseBool(raw['priceQuoteLocked'])) {
      return false;
    }
    if (BookingDetailParse.parseDate(raw['priceConfirmedAt']) != null &&
        !isRoomTypeDaycare) {
      return false;
    }
    if (isRoomTypeDaycare &&
        BookingDetailParse.parseMoney(raw['totalPrice']) <= 0) {
      return true;
    }
    return isIndependentDaycare && status != 'completed';
  }

  String get totalAmountLabel => showEstimateLabel ? '暫估金額' : '訂單總額';

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case PaymentMethodType.bankTransfer:
      case 'bank_transfer':
      case 'bankTransfer':
      case '銀行轉帳':
        return '銀行轉帳';
      case PaymentMethodType.cash:
        return '到店付款';
      case PaymentMethodType.creditCard:
        return '信用卡';
      case PaymentMethodType.atm:
        return 'ATM 虛擬帳號';
      case PaymentMethodType.convenienceStoreCode:
        return '超商代碼';
      default:
        return paymentMethod.isEmpty ? '未設定' : paymentMethod;
    }
  }

  String get paymentStatusLabel {
    if (status == 'cancelled') {
      return '已取消';
    }
    if (isPaidInFull) {
      return '已付清';
    }
    if (depositStatus == 'pending_review') {
      return '付款資料審核中';
    }
    if (depositStatus == 'confirmed' && remainingAmount > 0) {
      return '尚有尾款';
    }
    if (remainingAmount > 0) {
      return '待付款';
    }
    return '未付款';
  }

  bool get isBankTransfer {
    return paymentMethod == PaymentMethodType.bankTransfer ||
        paymentMethod == 'bank_transfer' ||
        paymentMethod == 'bankTransfer' ||
        paymentMethod == '銀行轉帳';
  }

  bool get showBankTransferForm {
    if (!isBankTransfer) {
      return false;
    }
    if (status == 'cancelled' || status == 'completed') {
      return false;
    }
    if (depositStatus == 'pending_review' || depositStatus == 'confirmed') {
      return false;
    }
    return remainingAmount > 0 ||
        BookingDetailParse.parseMoney(raw['depositAmount']) > 0;
  }

  bool get canCreateOnlinePaymentCandidate {
    return remainingAmount > 0 &&
        status != 'cancelled' &&
        status != 'completed';
  }

  String get customerName =>
      BookingDetailParse.parseString(raw['customerName']);

  String get customerPhone =>
      BookingDetailParse.parseString(raw['customerPhone']);

  String get address => BookingDetailParse.parseString(raw['address']);

  Map<String, dynamic> get emergency =>
      BookingDetailParse.parseMap(raw['emergencyContact']);

  String get emergencyName => BookingDetailParse.parseString(emergency['name']);

  String get emergencyPhone =>
      BookingDetailParse.parseString(emergency['phone']);

  String get emergencyRelation =>
      BookingDetailParse.parseString(emergency['relation']);

  String get customerNote {
    final String note = BookingDetailParse.parseString(raw['note']);
    if (note.isEmpty || note == '無' || note == '沒有' || note == '尚無') {
      return '';
    }
    return note;
  }

  bool get showCustomerNote => customerNote.isNotEmpty;

  String get staffNote => BookingDetailParse.parseString(
    raw['staffNote'] ?? raw['adminNote'] ?? raw['internalNote'],
  );

  bool get isManualOrder {
    final String source = BookingDetailParse.parseString(raw['source']);
    return source == 'admin' || source == 'manual';
  }

  bool get canCancel {
    return status == 'pending' || status == 'unpaid';
  }

  bool get contactShopInsteadOfCancel =>
      canCancel && depositStatus == 'pending_review';

  bool get paidCancelNeedsRefundHint =>
      paidAmount > 0 || depositStatus == 'confirmed';

  String get cancelReason =>
      BookingDetailParse.parseString(raw['cancelReason']);

  bool get couponReturnedKnown {
    return raw.containsKey('couponReturned') ||
        raw.containsKey('couponRefunded');
  }

  bool get couponReturned => BookingDetailParse.parseBool(
    raw['couponReturned'] ?? raw['couponRefunded'],
  );

  bool get pointsReturnedKnown {
    return raw.containsKey('pointsReturned') ||
        raw.containsKey('pointsRefunded');
  }

  bool get pointsReturned => BookingDetailParse.parseBool(
    raw['pointsReturned'] ?? raw['pointsRefunded'],
  );

  int get earnedPoints => BookingDetailParse.parseMoney(
    raw['issuedPoints'] ??
        raw['pointsIssued'] ??
        raw['rewardPoints'] ??
        raw['earnedPoints'],
  );

  bool get showEarnedPoints => status == 'completed' && earnedPoints > 0;

  bool get reviewed => BookingDetailParse.parseBool(raw['reviewed']);

  bool get showReview => status == 'completed';

  String get reviewLabel => isDaycare ? '安親評價' : '住宿評價';

  int get termsVersion => BookingDetailParse.parseMoney(
    raw['termsVersion'] ?? raw['policyVersion'],
  );

  String get termsTitle {
    final String title = BookingDetailParse.parseString(
      raw['termsTitle'] ?? raw['policyTitle'],
    );
    if (title.isNotEmpty) {
      return title;
    }
    return isDaycare ? '安親條款' : '住宿條款';
  }

  String get policySectionTitle => isDaycare ? '安親條款' : '住宿條款';

  DateTime? get termsAcceptedAt =>
      BookingDetailParse.parseDate(raw['termsAcceptedAt']) ??
      BookingDetailParse.parseDate(raw['policyAcceptedAt']);

  BookingDetailTermsState get termsState {
    if (BookingDetailParse.parseBool(raw['termsNeedsReconfirm']) ||
        BookingDetailParse.parseBool(raw['policyNeedsReconfirm'])) {
      return BookingDetailTermsState.needsReconfirm;
    }
    if (termsVersion > 0 ||
        BookingDetailParse.parseBool(raw['policyAccepted'])) {
      return BookingDetailTermsState.confirmed;
    }
    return BookingDetailTermsState.unconfirmed;
  }

  bool get stayArrangementComplete {
    if (isDaycare) {
      return scheduledStartAt != null && scheduledEndAt != null;
    }
    return startDate != null && endDate != null;
  }

  bool get feedingComplete {
    for (final Map<String, dynamic> pet in pets) {
      final List<String> keys = <String>[
        'note',
        'medicalStatus',
        'vaccine',
        'food',
        'medication',
        'diet',
        'feeding',
        'medicine',
        'litterType',
      ];
      for (final String key in keys) {
        if (BookingDetailParse.parseString(pet[key]).isNotEmpty) {
          return true;
        }
      }
    }
    final Map<String, dynamic> answers = BookingDetailParse.parseMap(
      raw['customFormAnswers'] ??
          raw['bookingFormAnswers'] ??
          raw['formAnswers'],
    );
    return answers.isNotEmpty;
  }

  bool get paymentTaskComplete => isPaidInFull;

  bool get stayDataComplete =>
      stayArrangementComplete &&
      feedingComplete &&
      termsState != BookingDetailTermsState.unconfirmed &&
      termsState != BookingDetailTermsState.needsReconfirm &&
      paymentTaskComplete;

  bool get showCamera {
    return status == 'checked_in' &&
        BookingDetailParse.parseString(raw['roomId']).isNotEmpty &&
        BookingDetailParse.parseString(raw['shopId']).isNotEmpty;
  }

  DateTime? dailyCareDownloadDeadline(int downloadHoursAfterCheckout) {
    if (checkOutAt == null) {
      return null;
    }
    return checkOutAt!.add(Duration(hours: downloadHoursAfterCheckout));
  }

  bool canViewDailyCare({
    required int downloadHoursAfterCheckout,
    DateTime? now,
  }) {
    if (status == 'checked_in') {
      return true;
    }
    if (status != 'completed') {
      return false;
    }
    final DateTime? deadline = dailyCareDownloadDeadline(
      downloadHoursAfterCheckout,
    );
    if (deadline == null) {
      return false;
    }
    return (now ?? DateTime.now()).isBefore(deadline);
  }

  bool dailyCareDownloadExpired({
    required int downloadHoursAfterCheckout,
    DateTime? now,
  }) {
    if (status != 'completed') {
      return false;
    }
    final DateTime? deadline = dailyCareDownloadDeadline(
      downloadHoursAfterCheckout,
    );
    if (deadline == null) {
      return false;
    }
    return !(now ?? DateTime.now()).isBefore(deadline);
  }

  int get overtimeMinutes =>
      BookingDetailParse.parseMoney(raw['overtimeMinutes']);

  int get overtimeAmount =>
      BookingDetailParse.parseMoney(raw['overtimeAmount']);

  int get graceMinutes => BookingDetailParse.parseMoney(
    raw['overtimeGraceMinutes'] ?? raw['graceMinutes'],
  );

  List<Map<String, dynamic>> get extraCharges =>
      BookingDetailParse.parseMapList(raw['extraCharges']);

  bool get hasExtraCharges => extraCharges.isNotEmpty;

  int get extraChargesTotal {
    int sum = 0;
    for (final Map<String, dynamic> item in extraCharges) {
      sum += BookingDetailParse.parseMoney(item['amount']);
    }
    return sum;
  }

  List<BookingDetailFeeLine> get feeLines {
    final List<BookingDetailFeeLine> lines = <BookingDetailFeeLine>[];

    void addLine({
      required String label,
      required int amount,
      String subtitle = '',
      bool isDiscount = false,
      bool force = false,
    }) {
      if (!force && amount == 0 && subtitle.isEmpty) {
        return;
      }
      if (!force && amount == 0) {
        return;
      }
      lines.add(
        BookingDetailFeeLine(
          label: label,
          amount: amount,
          subtitle: subtitle,
          isDiscount: isDiscount,
        ),
      );
    }

    if (isDaycare) {
      final Map<String, dynamic> snap = BookingDetailParse.parseMap(
        raw['daycarePricingSnapshot'],
      );
      final String planName = BookingDetailParse.parseString(
        BookingDetailParse.parseMap(raw['daycarePlanSnapshot'])['name'] ??
            raw['daycarePlanName'],
      );
      addLine(
        label: planName.isEmpty ? '安親費用' : planName,
        amount: BookingDetailParse.parseMoney(
          snap['baseAmount'] ?? raw['basePrice'],
        ),
      );
      addLine(
        label: '多寵物加價',
        amount: BookingDetailParse.parseMoney(
          snap['extraPetAmount'] ?? raw['extraPetTotal'],
        ),
      );
      addLine(
        label: '房型加價',
        amount: BookingDetailParse.parseMoney(snap['roomTypeExtra']),
      );
      addLine(
        label: '時間加購',
        amount: BookingDetailParse.parseMoney(snap['timeAddonAmount']),
      );
      if (overtimeAmount > 0) {
        addLine(
          label: '逾時費',
          amount: overtimeAmount,
          subtitle: overtimeMinutes > 0 ? '$overtimeMinutes 分鐘' : '',
        );
      }
      if (graceMinutes > 0) {
        addLine(
          label: '寬限時間',
          amount: 0,
          subtitle: '$graceMinutes 分鐘',
          force: true,
        );
      }
    } else {
      final int room = BookingDetailParse.parseMoney(raw['roomSubtotal']);
      final int base = BookingDetailParse.parseMoney(raw['basePrice']);
      final int nightCount = nights <= 0 ? 1 : nights;
      addLine(
        label: '房費',
        amount: room > 0 ? room : base * nightCount,
        subtitle: '$nightCount 晚',
      );
      addLine(
        label: '多寵物加價',
        amount: BookingDetailParse.parseMoney(raw['extraPetTotal']) > 0
            ? BookingDetailParse.parseMoney(raw['extraPetTotal'])
            : BookingDetailParse.parseMoney(raw['extraPetPrice']) *
                  BookingDetailParse.parseMoney(raw['extraPetCount']) *
                  nightCount,
      );
    }

    for (final Map<String, dynamic> addon in BookingDetailParse.parseMapList(
      raw['addons'],
    )) {
      final String type = BookingDetailParse.parseString(addon['type']);
      final String name = BookingDetailParse.parseString(addon['name']);
      final int count = BookingDetailParse.parseMoney(addon['count'] ?? 1);
      final int total = BookingDetailParse.parseMoney(
        addon['total'] ??
            (BookingDetailParse.parseMoney(addon['price']) * count),
      );
      String group = '加購';
      if (type == 'time' || type == 'time_addon') {
        group = '時間加購';
      } else if (type == 'custom') {
        group = '客製服務';
      } else if (type == 'daily_timed') {
        group = '每日分時段服務';
      }
      addLine(
        label: name.isEmpty ? group : name,
        amount: total,
        subtitle: _addonSubtitle(addon, count),
      );
    }

    addLine(
      label: '特殊日期加價',
      amount: BookingDetailParse.parseMoney(raw['specialDateSurchargeAmount']),
    );
    addLine(
      label: BookingDetailParse.parseString(raw['discountCampaignName']).isEmpty
          ? '優惠活動折扣'
          : BookingDetailParse.parseString(raw['discountCampaignName']),
      amount: BookingDetailParse.parseMoney(raw['discountAmount']),
      isDiscount: true,
    );
    addLine(
      label: BookingDetailParse.parseString(raw['couponName']).isEmpty
          ? '優惠券折扣'
          : BookingDetailParse.parseString(raw['couponName']),
      amount: BookingDetailParse.parseMoney(raw['couponDiscountAmount']),
      isDiscount: true,
    );
    addLine(
      label: '點數折抵',
      amount: BookingDetailParse.parseMoney(
        raw['pointAmount'] ?? raw['pointsDiscountAmount'],
      ),
      isDiscount: true,
    );
    if (hasExtraCharges) {
      addLine(label: '退房追加費用', amount: extraChargesTotal);
    }

    lines.add(
      BookingDetailFeeLine(
        label: showEstimateLabel ? '暫估總額' : '最終總額',
        amount: totalAmount,
        isTotal: true,
      ),
    );
    return lines;
  }

  String _addonSubtitle(Map<String, dynamic> addon, int count) {
    final List<String> parts = <String>[];
    if (count > 1) {
      parts.add('x$count');
    }
    final List<dynamic> dates = BookingDetailParse.parseList(addon['dates']);
    if (dates.isNotEmpty) {
      parts.add('${dates.length} 日');
    }
    return parts.join(' ・ ');
  }

  List<BookingDetailTimelineItem> get timeline {
    final List<BookingDetailTimelineItem> items = <BookingDetailTimelineItem>[
      BookingDetailTimelineItem(title: '已送出預約', time: createdAt, active: true),
    ];
    if (depositSubmittedAt != null || depositStatus == 'pending_review') {
      items.add(
        BookingDetailTimelineItem(
          title: '付款資料已送出',
          time: depositSubmittedAt,
          active: true,
        ),
      );
    }
    if (paidAt != null || depositStatus == 'confirmed' || paidAmount > 0) {
      items.add(
        BookingDetailTimelineItem(
          title: '付款完成',
          time: paidAt ?? BookingDetailParse.parseDate(raw['depositPaidAt']),
          active: paidAmount > 0 || depositStatus == 'confirmed',
        ),
      );
    }
    items.add(
      BookingDetailTimelineItem(
        title: '店家已確認',
        time: confirmedAt,
        active:
            status == 'confirmed' ||
            status == 'checked_in' ||
            status == 'completed',
      ),
    );
    items.add(
      BookingDetailTimelineItem(
        title: isDaycare ? '安親開始' : '已入住',
        time: checkInAt ?? actualStartAt,
        active: status == 'checked_in' || status == 'completed',
      ),
    );
    items.add(
      BookingDetailTimelineItem(
        title: '已完成',
        time: checkOutAt ?? actualEndAt,
        active: status == 'completed',
      ),
    );
    if (status == 'cancelled') {
      items.add(
        BookingDetailTimelineItem(
          title: cancelReason.isEmpty ? '已取消' : '已取消：$cancelReason',
          time: cancelledAt,
          active: true,
        ),
      );
    }
    return items;
  }

  List<BookingDetailPetInfo> get petInfos {
    return pets.map((Map<String, dynamic> pet) {
      final List<String> care = <String>[];
      void take(String key, String label) {
        final String value = BookingDetailParse.parseString(pet[key]);
        if (value.isNotEmpty) {
          care.add('$label：$value');
        }
      }

      take('note', '備註');
      take('medicalStatus', '健康／疫苗');
      take('vaccine', '疫苗');
      take('food', '餵食');
      take('diet', '飲食');
      take('medication', '用藥');
      take('medicine', '用藥');
      take('litterType', '貓砂');
      return BookingDetailPetInfo(
        name: BookingDetailParse.parseString(pet['name']),
        photoUrl: BookingDetailParse.parseString(
          pet['photoUrl'] ?? pet['imageUrl'] ?? pet['image'],
        ),
        careSummary: care.join('、'),
      );
    }).toList();
  }

  int get customerUnreadCount =>
      BookingDetailParse.parseMoney(raw['customerUnreadMessageCount']);

  String get lastMessageText =>
      BookingDetailParse.parseString(raw['lastMessageText']);

  DateTime? get lastMessageAt =>
      BookingDetailParse.parseDate(raw['lastMessageAt']);

  String formatDateTime(DateTime? value) {
    if (value == null) {
      return '';
    }
    final String y = value.year.toString().padLeft(4, '0');
    final String m = value.month.toString().padLeft(2, '0');
    final String d = value.day.toString().padLeft(2, '0');
    final String h = value.hour.toString().padLeft(2, '0');
    final String min = value.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $h:$min';
  }

  String formatDate(DateTime? value) {
    if (value == null) {
      return '';
    }
    return _dateText(value);
  }

  static String _dateText(DateTime value) {
    final String y = value.year.toString().padLeft(4, '0');
    final String m = value.month.toString().padLeft(2, '0');
    final String d = value.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String paymentPurposeLabel(String purpose) {
    switch (purpose) {
      case PaymentPurpose.deposit:
        return '訂金';
      case PaymentPurpose.balance:
        return '尾款';
      case PaymentPurpose.full:
        return '全額';
      case PaymentPurpose.additional:
        return '補款';
      default:
        return '付款';
    }
  }

  static String paymentRecordStatusLabel(String status) {
    switch (status) {
      case PaymentTransactionStatus.paid:
        return '已付款';
      case PaymentTransactionStatus.awaitingPayment:
      case PaymentTransactionStatus.pending:
        return '待付款';
      case PaymentTransactionStatus.processing:
        return '處理中';
      case PaymentTransactionStatus.failed:
        return '失敗';
      case PaymentTransactionStatus.expired:
        return '已逾期';
      case PaymentTransactionStatus.cancelled:
        return '已取消';
      default:
        return status;
    }
  }
}
