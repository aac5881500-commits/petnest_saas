// 檔案名稱：lib/features/booking/pages/booking_form_page.dart
// 功能說明：預約資料填寫頁（條款確認＋暖色卡片版）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/emergency_relation_options.dart';
import 'package:petnest_saas/core/models/booking_fee_line_item.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/core/utils/dropdown_value.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';
import 'package:petnest_saas/features/shop/widgets/booking/terms_confirmation_card.dart';
import 'package:petnest_saas/features/shop/widgets/booking/terms_confirmation_sheet.dart';

enum BookingFormPaymentTestState { loading, error, empty, ready }

class BookingFormPage extends StatefulWidget {
  const BookingFormPage({
    required this.shopId,
    required this.onSubmitWithData,
    required this.addons,
    super.key,
    required this.formKey,
    required this.customerNameController,
    required this.customerPhoneController,
    required this.noteController,
    required this.serviceTypes,
    required this.selectedServiceType,
    required this.onServiceChanged,
    required this.onSubmit,
    required this.isSubmitting,
    required this.canSubmit,
    required this.isBlacklisted,
    required this.totalPrice,
    this.originalTotal = 0,
    this.discountAmount = 0,
    this.discountCampaignName = '',
    required this.roomPrice,
    this.submitLabel = '送出預約',
    this.feeSummaryTitle = '',
    this.allowCashOverride,
    this.daycareDepositType,
    this.daycareDepositValue = 0,
    this.theme = HomeThemeModel.classicDefault,
    this.termsServiceType = PolicyApplicableService.accommodation,
    this.feeLineItems = const <BookingFeeLineItem>[],
    this.skipRemoteLoads = false,
    this.seedMemberData,
    this.paymentTestState,
    this.depositOverrideAmount,
    this.showSubmitError = true,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController customerNameController;
  final TextEditingController customerPhoneController;
  final TextEditingController noteController;
  final List<Map<String, dynamic>> addons;

  final List<String> serviceTypes;
  final String? selectedServiceType;
  final Function(String?) onServiceChanged;

  final VoidCallback onSubmit;

  final bool isSubmitting;
  final bool canSubmit;
  final bool isBlacklisted;
  final int totalPrice;
  final int originalTotal;
  final int discountAmount;
  final String discountCampaignName;
  final int roomPrice;

  /// 送出按鈕文字。臨托使用「確認訂單」，住宿維持「送出預約」。
  final String submitLabel;

  /// 費用摘要標題。空白時不顯示額外標題。
  final String feeSummaryTitle;

  /// 若為 false，即使店家有開到店付款也不顯示。
  final bool? allowCashOverride;

  /// 臨托專用訂金方式。null 時沿用店家住宿訂金設定。
  final String? daycareDepositType;
  final int daycareDepositValue;
  final HomeThemeModel theme;
  final String termsServiceType;
  final List<BookingFeeLineItem> feeLineItems;

  /// 測試用：略過 Firestore，改用 seed 資料。
  @visibleForTesting
  final bool skipRemoteLoads;

  @visibleForTesting
  final Map<String, dynamic>? seedMemberData;

  @visibleForTesting
  final BookingFormPaymentTestState? paymentTestState;

  /// 安親等已算好的訂金，避免再被住宿訂金比例覆蓋。
  final int? depositOverrideAmount;

  /// 若父層已顯示錯誤，避免重複 Snackbar。
  final bool showSubmitError;

  final String shopId;

  final Future<void> Function(
    String address,
    String emergencyName,
    String emergencyPhone,
    String relation,
    String emergencyAddress,
    String phone2,
    int depositAmount,
    String paymentMethod,
    String payAmountType,
    TermsConsentSnapshot termsConsent,
  )
  onSubmitWithData;

  @override
  State<BookingFormPage> createState() => _BookingFormPageState();
}

class _BookingFormPageState extends State<BookingFormPage> {
  bool _isSubmitting = false;
  bool _depositEnabled = false;
  int _depositAmount = 0;
  double _depositRate = 0;
  String _depositBase = 'total';
  bool _cashEnabled = false;
  bool _transferEnabled = false;
  bool _loadingTerms = true;
  bool _paymentSettingsLoaded = false;
  String? _paymentLoadError;
  bool _termsLoadError = false;
  TermsStatus? _termsStatus;

  /// 💳 綠界線上付款方式
  /// 功能：只有通過平台審核且店家有啟用時才顯示。
  bool _creditCardEnabled = false;
  bool _atmEnabled = false;
  bool _cvsCodeEnabled = false;

  String? _paymentMethod;
  String _payAmountType = 'deposit';
  String? _city;
  String? _district;
  bool _sameAddress = false;
  final _detailAddressController = TextEditingController();

  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _customEmergencyRelationController = TextEditingController();
  String? _emergencyRelation;
  final _emergencyAddressController = TextEditingController();
  final _phone2Controller = TextEditingController();

  final Map<String, List<String>> cityData = {
    '台北市': [
      '中正區',
      '大同區',
      '中山區',
      '松山區',
      '大安區',
      '萬華區',
      '信義區',
      '士林區',
      '北投區',
      '內湖區',
      '南港區',
      '文山區',
    ],
    '新北市': [
      '板橋區',
      '新莊區',
      '中和區',
      '永和區',
      '土城區',
      '樹林區',
      '三重區',
      '蘆洲區',
      '新店區',
      '汐止區',
      '淡水區',
      '三峽區',
      '鶯歌區',
      '五股區',
      '泰山區',
      '林口區',
      '深坑區',
      '石碇區',
      '坪林區',
      '三芝區',
      '石門區',
      '八里區',
      '平溪區',
      '雙溪區',
      '貢寮區',
      '金山區',
      '萬里區',
      '烏來區',
    ],
    '桃園市': [
      '桃園區',
      '中壢區',
      '平鎮區',
      '八德區',
      '龜山區',
      '蘆竹區',
      '大溪區',
      '楊梅區',
      '大園區',
      '觀音區',
      '新屋區',
      '龍潭區',
      '復興區',
    ],
    '台中市': [
      '中區',
      '東區',
      '南區',
      '西區',
      '北區',
      '北屯區',
      '西屯區',
      '南屯區',
      '太平區',
      '大里區',
      '霧峰區',
      '烏日區',
      '豐原區',
      '后里區',
      '石岡區',
      '東勢區',
      '新社區',
      '潭子區',
      '大雅區',
      '神岡區',
      '大肚區',
      '沙鹿區',
      '龍井區',
      '梧棲區',
      '清水區',
      '大甲區',
      '外埔區',
      '大安區',
      '和平區',
    ],
    '台南市': [
      '中西區',
      '東區',
      '南區',
      '北區',
      '安平區',
      '安南區',
      '永康區',
      '歸仁區',
      '新化區',
      '左鎮區',
      '玉井區',
      '楠西區',
      '南化區',
      '仁德區',
      '關廟區',
      '龍崎區',
      '官田區',
      '麻豆區',
      '佳里區',
      '西港區',
      '七股區',
      '將軍區',
      '學甲區',
      '北門區',
      '新營區',
      '後壁區',
      '白河區',
      '東山區',
      '六甲區',
      '下營區',
      '柳營區',
      '鹽水區',
      '善化區',
      '大內區',
      '山上區',
      '新市區',
      '安定區',
    ],
    '高雄市': [
      '新興區',
      '前金區',
      '苓雅區',
      '鹽埕區',
      '鼓山區',
      '旗津區',
      '前鎮區',
      '三民區',
      '楠梓區',
      '小港區',
      '左營區',
      '仁武區',
      '大社區',
      '岡山區',
      '路竹區',
      '阿蓮區',
      '田寮區',
      '燕巢區',
      '橋頭區',
      '梓官區',
      '彌陀區',
      '永安區',
      '湖內區',
      '鳳山區',
      '大寮區',
      '林園區',
      '鳥松區',
      '大樹區',
      '旗山區',
      '美濃區',
      '六龜區',
      '內門區',
      '杉林區',
      '甲仙區',
      '桃源區',
      '那瑪夏區',
      '茂林區',
      '茄萣區',
    ],
    '新竹縣': [
      '竹北市',
      '竹東鎮',
      '新埔鎮',
      '關西鎮',
      '湖口鄉',
      '新豐鄉',
      '芎林鄉',
      '橫山鄉',
      '北埔鄉',
      '寶山鄉',
      '峨眉鄉',
      '尖石鄉',
      '五峰鄉',
    ],
    '苗栗縣': [
      '苗栗市',
      '苑裡鎮',
      '通霄鎮',
      '竹南鎮',
      '頭份市',
      '後龍鎮',
      '卓蘭鎮',
      '大湖鄉',
      '公館鄉',
      '銅鑼鄉',
      '南庄鄉',
      '頭屋鄉',
      '三義鄉',
      '西湖鄉',
      '造橋鄉',
      '三灣鄉',
      '獅潭鄉',
      '泰安鄉',
    ],
    '彰化縣': [
      '彰化市',
      '鹿港鎮',
      '和美鎮',
      '線西鄉',
      '伸港鄉',
      '福興鄉',
      '秀水鄉',
      '花壇鄉',
      '芬園鄉',
      '員林市',
      '溪湖鎮',
      '田中鎮',
      '大村鄉',
      '埔鹽鄉',
      '埔心鄉',
      '永靖鄉',
      '社頭鄉',
      '二水鄉',
      '北斗鎮',
      '二林鎮',
      '田尾鄉',
      '埤頭鄉',
      '芳苑鄉',
      '大城鄉',
      '竹塘鄉',
      '溪州鄉',
    ],
    '南投縣': [
      '南投市',
      '埔里鎮',
      '草屯鎮',
      '竹山鎮',
      '集集鎮',
      '名間鄉',
      '鹿谷鄉',
      '中寮鄉',
      '魚池鄉',
      '國姓鄉',
      '水里鄉',
      '信義鄉',
      '仁愛鄉',
    ],
    '雲林縣': [
      '斗六市',
      '斗南鎮',
      '虎尾鎮',
      '西螺鎮',
      '土庫鎮',
      '北港鎮',
      '古坑鄉',
      '大埤鄉',
      '莿桐鄉',
      '林內鄉',
      '二崙鄉',
      '崙背鄉',
      '麥寮鄉',
      '東勢鄉',
      '褒忠鄉',
      '台西鄉',
      '元長鄉',
      '四湖鄉',
      '口湖鄉',
      '水林鄉',
    ],
    '嘉義縣': [
      '太保市',
      '朴子市',
      '布袋鎮',
      '大林鎮',
      '民雄鄉',
      '溪口鄉',
      '新港鄉',
      '六腳鄉',
      '東石鄉',
      '義竹鄉',
      '鹿草鄉',
      '水上鄉',
      '中埔鄉',
      '竹崎鄉',
      '梅山鄉',
      '番路鄉',
      '大埔鄉',
      '阿里山鄉',
    ],
    '嘉義市': ['東區', '西區'],
    '屏東縣': [
      '屏東市',
      '潮州鎮',
      '東港鎮',
      '恆春鎮',
      '萬丹鄉',
      '長治鄉',
      '麟洛鄉',
      '九如鄉',
      '里港鄉',
      '鹽埔鄉',
      '高樹鄉',
      '萬巒鄉',
      '內埔鄉',
      '竹田鄉',
      '新埤鄉',
      '枋寮鄉',
      '新園鄉',
      '崁頂鄉',
      '林邊鄉',
      '南州鄉',
      '佳冬鄉',
      '琉球鄉',
      '車城鄉',
      '滿州鄉',
      '枋山鄉',
      '三地門鄉',
      '霧台鄉',
      '瑪家鄉',
      '泰武鄉',
      '來義鄉',
      '春日鄉',
      '獅子鄉',
      '牡丹鄉',
    ],
    '宜蘭縣': [
      '宜蘭市',
      '羅東鎮',
      '蘇澳鎮',
      '頭城鎮',
      '礁溪鄉',
      '壯圍鄉',
      '員山鄉',
      '冬山鄉',
      '五結鄉',
      '三星鄉',
      '大同鄉',
      '南澳鄉',
    ],
    '花蓮縣': [
      '花蓮市',
      '鳳林鎮',
      '玉里鎮',
      '新城鄉',
      '吉安鄉',
      '壽豐鄉',
      '光復鄉',
      '豐濱鄉',
      '瑞穗鄉',
      '富里鄉',
      '秀林鄉',
      '萬榮鄉',
      '卓溪鄉',
    ],
    '台東縣': [
      '台東市',
      '成功鎮',
      '關山鎮',
      '卑南鄉',
      '鹿野鄉',
      '池上鄉',
      '東河鄉',
      '長濱鄉',
      '太麻里鄉',
      '大武鄉',
      '綠島鄉',
      '海端鄉',
      '延平鄉',
      '金峰鄉',
      '達仁鄉',
      '蘭嶼鄉',
    ],
    '澎湖縣': ['馬公市', '湖西鄉', '白沙鄉', '西嶼鄉', '望安鄉', '七美鄉'],
    '金門縣': ['金城鎮', '金湖鎮', '金沙鎮', '金寧鄉', '烈嶼鄉', '烏坵鄉'],
    '連江縣': ['南竿鄉', '北竿鄉', '莒光鄉', '東引鄉'],
  };

  User? _currentAuthUser() {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.seedMemberData != null) {
      _applyMemberData(widget.seedMemberData!);
    }
    if (widget.skipRemoteLoads) {
      _applyPaymentTestState(
        widget.paymentTestState ?? BookingFormPaymentTestState.ready,
      );
      _loadingTerms = false;
      return;
    }
    _loadMemberData();
    _loadShopPaymentSettings();
    _loadTermsStatus();
  }

  void _applyPaymentTestState(BookingFormPaymentTestState state) {
    _cashEnabled = false;
    _transferEnabled = false;
    _creditCardEnabled = false;
    _atmEnabled = false;
    _cvsCodeEnabled = false;
    _paymentMethod = null;
    switch (state) {
      case BookingFormPaymentTestState.loading:
        _paymentSettingsLoaded = false;
        _paymentLoadError = null;
        break;
      case BookingFormPaymentTestState.error:
        _paymentSettingsLoaded = true;
        _paymentLoadError = '付款方式載入失敗';
        break;
      case BookingFormPaymentTestState.empty:
        _paymentSettingsLoaded = true;
        _paymentLoadError = null;
        break;
      case BookingFormPaymentTestState.ready:
        _paymentSettingsLoaded = true;
        _paymentLoadError = null;
        _cashEnabled = true;
        _transferEnabled = true;
        break;
    }
    final String? daycareType = widget.daycareDepositType;
    if (widget.depositOverrideAmount != null ||
        daycareType == DaycareDepositTypes.fixed ||
        daycareType == DaycareDepositTypes.percent ||
        daycareType == DaycareDepositTypes.full) {
      _depositEnabled = daycareType != DaycareDepositTypes.none;
      if (daycareType == DaycareDepositTypes.percent) {
        _depositRate = widget.daycareDepositValue / 100.0;
        _depositAmount = 0;
      } else if (daycareType == DaycareDepositTypes.full) {
        _depositAmount = widget.totalPrice;
        _depositRate = 0;
      } else {
        _depositAmount =
            widget.depositOverrideAmount ?? widget.daycareDepositValue;
        _depositRate = 0;
      }
    }
  }

  Future<void> _loadTermsStatus() async {
    final User? user = _currentAuthUser();
    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingTerms = false;
          _termsLoadError = false;
        });
      }
      return;
    }
    try {
      final TermsStatus status = await ShopPolicyService.instance
          .getTermsStatus(
            shopId: widget.shopId,
            userId: user.uid,
            serviceType: widget.termsServiceType,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _termsStatus = status;
        _loadingTerms = false;
        _termsLoadError = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingTerms = false;
        _termsLoadError = true;
      });
    }
  }

  Future<void> _openTermsSheet() async {
    final bool? confirmed = await showTermsConfirmationSheet(
      context: context,
      shopId: widget.shopId,
      theme: widget.theme,
      serviceType: widget.termsServiceType,
    );
    if (confirmed == true) {
      await _loadTermsStatus();
    }
  }

  InputDecoration _filledDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: widget.theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: widget.theme.cardBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: widget.theme.cardBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: widget.theme.primaryColor, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return BookingThemedCard(
      theme: widget.theme,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: widget.theme.textColor,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: widget.theme.textColor.withValues(alpha: 0.62),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _choiceCard({
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? widget.theme.primaryColor.withValues(alpha: 0.08)
                  : widget.theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? widget.theme.primaryColor
                    : widget.theme.cardBorderColor,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected
                          ? widget.theme.primaryColor
                          : widget.theme.textColor.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.theme.textColor,
                            ),
                          ),
                          if (subtitle != null) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.theme.textColor.withValues(
                                  alpha: 0.62,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _submitHint() {
    if (widget.customerPhoneController.text.trim().isEmpty) {
      return '請填寫聯絡電話';
    }
    if (_paymentMethod == null) {
      return '請選擇付款方式';
    }
    if (_termsStatus != null &&
        _termsStatus!.required &&
        !_termsStatus!.accepted) {
      return '請確認最新條款';
    }
    return '';
  }

  TermsConsentSnapshot _buildTermsConsent() {
    final TermsStatus status =
        _termsStatus ??
        TermsStatus(
          required: false,
          accepted: true,
          versionUpdated: false,
          version: 0,
          title: widget.skipRemoteLoads
              ? '服務條款'
              : ShopPolicyService.instance.termsTitleForService(
                  widget.termsServiceType,
                ),
        );
    final User? user = _currentAuthUser();
    return TermsConsentSnapshot(
      termsType: widget.termsServiceType,
      termsVersion: status.version,
      termsTitle: status.title,
      termsAcceptedAt: status.acceptedAt ?? DateTime.now(),
      consentRecordId: user == null
          ? ''
          : ShopPolicyService.instance.consentRecordPath(
              userId: user.uid,
              shopId: widget.shopId,
            ),
      termsVersionDocumentId: status.version > 0 ? 'v${status.version}' : '',
    );
  }

  @override
  void dispose() {
    _detailAddressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _customEmergencyRelationController.dispose();
    _emergencyAddressController.dispose();
    _phone2Controller.dispose();

    super.dispose();
  }

  /// 💳 讀取店家訂金與收款方式設定
  ///
  /// 收款方式統一讀取 paymentSetting.operationSettings。
  /// 綠界付款需同時符合：
  /// 1. 平台審核已核准
  /// 2. 店家未被平台停用
  /// 3. 店家已開啟綠界總開關
  /// 4. 對應的付款方式已核准且已開啟
  Future<void> _loadShopPaymentSettings() async {
    if (widget.skipRemoteLoads) {
      if (!mounted) {
        return;
      }
      setState(() {
        _applyPaymentTestState(
          widget.paymentTestState ?? BookingFormPaymentTestState.ready,
        );
      });
      return;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(widget.shopId)
              .get();

      final Map<String, dynamic>? data = document.data();

      if (!mounted) {
        return;
      }
      if (data == null) {
        setState(() {
          _paymentSettingsLoaded = true;
          _paymentLoadError = '付款方式載入失敗';
          _cashEnabled = false;
          _transferEnabled = false;
        });
        return;
      }

      // 💰 訂金設定
      bool depositEnabled = SafeParse.parseBool(
        data['depositEnabled'],
        fallback: false,
      );
      String depositType = (data['depositType'] ?? 'fixed').toString();
      String depositBase = (data['depositBase'] ?? 'room').toString();

      final dynamic rawDepositValue = data['depositValue'];

      int depositValue = rawDepositValue is int
          ? rawDepositValue
          : rawDepositValue is double
          ? rawDepositValue.toInt()
          : int.tryParse(rawDepositValue?.toString() ?? '') ?? 0;

      final String? daycareDepositType = widget.daycareDepositType;
      if (daycareDepositType != null) {
        depositType = daycareDepositType;
        depositBase = 'total';
        depositValue = widget.daycareDepositValue;
        depositEnabled =
            daycareDepositType == 'fixed' || daycareDepositType == 'percent';
      }

      // 💳 綠界公開設定
      final dynamic rawPaymentSetting = data['paymentSetting'];

      final Map<String, dynamic> paymentSetting = rawPaymentSetting is Map
          ? Map<String, dynamic>.from(rawPaymentSetting)
          : <String, dynamic>{};

      final String reviewStatus = (paymentSetting['reviewStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final bool platformSuspended = SafeParse.parseBool(
        paymentSetting['platformSuspended'],
      );

      final bool shopDisabled = SafeParse.parseBool(
        paymentSetting['shopDisabled'],
      );

      // 🏪 店家的實際營運開關
      final dynamic rawOperationSettings = paymentSetting['operationSettings'];

      final Map<String, dynamic> operationSettings = rawOperationSettings is Map
          ? Map<String, dynamic>.from(rawOperationSettings)
          : <String, dynamic>{};

      final bool cashEnabled = SafeParse.parseBool(
        operationSettings['cashPaymentEnabled'],
        fallback: true,
      );

      final bool transferEnabled = SafeParse.parseBool(
        operationSettings['bankTransferEnabled'],
        fallback: true,
      );

      final bool ecpayEnabled = SafeParse.parseBool(
        operationSettings['ecpayEnabled'],
      );

      // ✅ 平台核准的綠界付款方式
      final dynamic rawApprovedMethods = paymentSetting['enabledMethods'];

      final Map<String, dynamic> approvedMethods = rawApprovedMethods is Map
          ? Map<String, dynamic>.from(rawApprovedMethods)
          : <String, dynamic>{};

      final bool approvedCreditCard =
          SafeParse.parseBool(approvedMethods['creditCard']) ||
          SafeParse.parseBool(paymentSetting['creditCardEnabled']);

      final bool approvedAtm =
          SafeParse.parseBool(approvedMethods['atm']) ||
          SafeParse.parseBool(paymentSetting['atmEnabled']);

      final bool approvedCvsCode =
          SafeParse.parseBool(approvedMethods['cvsCode']) ||
          SafeParse.parseBool(paymentSetting['cvsCodeEnabled']) ||
          SafeParse.parseBool(paymentSetting['convenienceStoreCodeEnabled']);

      // 🔐 綠界總資格
      final bool canUseEcpay =
          reviewStatus == 'approved' &&
          !platformSuspended &&
          !shopDisabled &&
          ecpayEnabled;

      // 🎛️ 店家實際開啟的綠界付款方式
      final bool creditCardEnabled =
          canUseEcpay &&
          approvedCreditCard &&
          SafeParse.parseBool(operationSettings['creditCardEnabled']);

      final bool atmEnabled =
          canUseEcpay &&
          approvedAtm &&
          SafeParse.parseBool(operationSettings['atmEnabled']);

      final bool cvsCodeEnabled =
          canUseEcpay &&
          approvedCvsCode &&
          SafeParse.parseBool(operationSettings['cvsCodeEnabled']);

      setState(() {
        _depositEnabled = depositEnabled;
        _depositBase = depositBase;

        if (depositType == 'percent') {
          _depositAmount = 0;
          _depositRate = depositValue / 100;
        } else {
          _depositAmount = depositValue;
          _depositRate = 0;
        }

        _cashEnabled = cashEnabled && (widget.allowCashOverride ?? true);
        _transferEnabled = transferEnabled;

        _creditCardEnabled = creditCardEnabled;
        _atmEnabled = atmEnabled;
        _cvsCodeEnabled = cvsCodeEnabled;
        _paymentSettingsLoaded = true;
        _paymentLoadError = null;

        if (widget.daycareDepositType == 'full' ||
            widget.daycareDepositType == 'none' ||
            widget.daycareDepositType == 'staff_decide') {
          _payAmountType = 'full';
        }

        // 目前選擇的方式若已被店家關閉，就清除選擇
        final bool selectedMethodStillAvailable =
            (_paymentMethod == 'cash' && _cashEnabled) ||
            (_paymentMethod == 'transfer' && _transferEnabled) ||
            (_paymentMethod == 'credit_card' && _creditCardEnabled) ||
            (_paymentMethod == 'atm' && _atmEnabled) ||
            (_paymentMethod == 'cvs_code' && _cvsCodeEnabled);

        if (_paymentMethod != null && !selectedMethodStillAvailable) {
          _paymentMethod = null;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _paymentSettingsLoaded = true;
        _paymentLoadError = '付款方式載入失敗';
        _cashEnabled = false;
        _transferEnabled = false;
      });
    }
  }

  /// 🔥 會員資料完整帶入（重點）
  Future<void> _loadMemberData() async {
    try {
      final user = _currentAuthUser();
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid)
          .get();

      final data = doc.data();
      if (data == null) return;

      if (!mounted) {
        return;
      }

      setState(() {
        _applyMemberData(data);
      });
    } catch (_) {}
  }

  void _applyMemberData(Map<String, dynamic> data) {
    widget.customerNameController.text = (data['name'] ?? '').toString();
    widget.customerPhoneController.text = (data['phone'] ?? '').toString();

    final String address = (data['address'] ?? '').toString();
    _city = null;
    _district = null;
    for (final String city in cityData.keys) {
      if (address.startsWith(city)) {
        _city = dropdownValueIfAllowed(city, cityData.keys);
        final List<String> districts = cityData[city] ?? const <String>[];
        for (final String district in districts) {
          if (address.contains(district)) {
            _district = dropdownValueIfAllowed(district, districts);
            break;
          }
        }
        break;
      }
    }
    _city = dropdownValueIfAllowed(_city, cityData.keys);
    final List<String> selectedDistricts = _city == null
        ? const <String>[]
        : (cityData[_city] ?? const <String>[]);
    _district = dropdownValueIfAllowed(_district, selectedDistricts);

    String detail = address;
    if (_city != null && detail.startsWith(_city!)) {
      detail = detail.substring(_city!.length);
    }
    if (_district != null && detail.startsWith(_district!)) {
      detail = detail.substring(_district!.length);
    }
    _detailAddressController.text = detail;

    final dynamic emergency = data['emergencyContact'];
    if (emergency is Map) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(emergency);
      _emergencyNameController.text = (map['name'] ?? '').toString();
      _emergencyPhoneController.text = (map['phone'] ?? '').toString();
      _applyEmergencyRelation((map['relation'] ?? '').toString());
      _emergencyAddressController.text = (map['address'] ?? '').toString();
      _phone2Controller.text = (map['phone2'] ?? '').toString();
    }
  }

  void _applyEmergencyRelation(String raw) {
    final String relation = raw.trim();
    if (relation.isEmpty) {
      _emergencyRelation = null;
      return;
    }
    if (EmergencyRelationOptions.isFixedPreset(relation)) {
      _emergencyRelation = relation;
      return;
    }
    _emergencyRelation = EmergencyRelationOptions.other;
    if (relation != EmergencyRelationOptions.other) {
      _customEmergencyRelationController.text = relation;
    }
  }

  String _emergencyRelationForSubmit() {
    if (_emergencyRelation == EmergencyRelationOptions.other) {
      return _customEmergencyRelationController.text.trim();
    }
    return (_emergencyRelation ?? '').trim();
  }

  Future<void> _handleSubmit(int calculatedDeposit) async {
    debugPrint('[BookingSubmit] 02 handleSubmit entered');
    if (_isSubmitting) {
      debugPrint('[BookingSubmit] 03 local submitting locked');
      return;
    }
    final bool valid = widget.formKey.currentState?.validate() ?? false;
    if (!valid) {
      debugPrint('[BookingSubmit] 09 local Form validation failed');
      _showSubmitMessage('請完整填寫預約資料');
      return;
    }
    if (widget.customerNameController.text.trim().isEmpty ||
        widget.customerPhoneController.text.trim().isEmpty) {
      debugPrint('[BookingSubmit] 04 contact data invalid');
      _showSubmitMessage('請完整填寫聯絡人姓名與電話');
      return;
    }
    if (_city == null ||
        _district == null ||
        _detailAddressController.text.trim().isEmpty) {
      debugPrint('[BookingSubmit] 05 address invalid');
      _showSubmitMessage('請完整填寫地址');
      return;
    }
    if (_emergencyNameController.text.trim().isEmpty ||
        _emergencyPhoneController.text.trim().isEmpty ||
        _emergencyRelationForSubmit().isEmpty ||
        _emergencyAddressController.text.trim().isEmpty) {
      debugPrint('[BookingSubmit] 06 emergency contact invalid');
      _showSubmitMessage('請完整填寫緊急聯絡人資料');
      return;
    }
    if (_paymentMethod == null) {
      debugPrint('[BookingSubmit] 07 payment method missing');
      _showSubmitMessage('請選擇付款方式');
      return;
    }
    if (_termsStatus != null &&
        _termsStatus!.required &&
        !_termsStatus!.accepted) {
      debugPrint('[BookingSubmit] 08 terms missing');
      _showSubmitMessage('請確認最新條款');
      return;
    }
    final String fullAddress =
        '${_city ?? ''}${_district ?? ''}${_detailAddressController.text}';
    debugPrint('[BookingSubmit] 10 calling parent submit');
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmitWithData(
        fullAddress,
        _emergencyNameController.text,
        _emergencyPhoneController.text,
        _emergencyRelationForSubmit(),
        _emergencyAddressController.text,
        _phone2Controller.text,
        calculatedDeposit,
        _paymentMethod ?? '',
        _payAmountType,
        _buildTermsConsent(),
      );
    } catch (error, stackTrace) {
      debugPrint('[BookingSubmit] form submit failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (widget.showSubmitError && mounted) {
        _showSubmitMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSubmitMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      ),
    );
  }

  Widget _feeLinesSection(int payableAmount) {
    final List<BookingFeeLineItem> lines = widget.feeLineItems;
    if (lines.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.feeSummaryTitle.trim().isNotEmpty)
            Text(
              widget.feeSummaryTitle,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: widget.theme.textColor,
              ),
            ),
          if (widget.discountAmount > 0) ...<Widget>[
            _feeRow('優惠折抵', -widget.discountAmount, isDiscount: true),
          ],
          _feeRow('預估總額', widget.totalPrice, isTotal: true),
          _feeRow('本次應付', payableAmount, isPayable: true),
        ],
      );
    }
    return Column(
      children: lines.map((BookingFeeLineItem line) {
        return _feeRow(
          line.label,
          line.amount,
          isDiscount: line.kind == BookingFeeLineKind.discount,
          isTotal: line.kind == BookingFeeLineKind.total,
          isPayable: line.kind == BookingFeeLineKind.payable,
        );
      }).toList(),
    );
  }

  Widget _feeRow(
    String label,
    int amount, {
    bool isDiscount = false,
    bool isTotal = false,
    bool isPayable = false,
  }) {
    final String prefix = amount < 0 ? '-NT\$ ${amount.abs()}' : 'NT\$ $amount';
    final TextStyle style = TextStyle(
      fontSize: isPayable || isTotal ? 15 : 14,
      fontWeight: isPayable || isTotal ? FontWeight.w700 : FontWeight.w500,
      color: isDiscount
          ? widget.theme.primaryColor
          : isPayable
          ? widget.theme.primaryColor
          : widget.theme.textColor,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          Text(prefix, style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _currentAuthUser();
    final int depositBasePrice = _depositBase == 'room'
        ? widget.roomPrice
        : widget.totalPrice;
    final int rawCalculatedDeposit;
    if (widget.depositOverrideAmount != null) {
      rawCalculatedDeposit = widget.depositOverrideAmount!;
    } else {
      rawCalculatedDeposit = _depositEnabled
          ? (_depositRate > 0
                ? (depositBasePrice * _depositRate).round()
                : _depositAmount)
          : 0;
    }
    final int calculatedDeposit = rawCalculatedDeposit > widget.totalPrice
        ? widget.totalPrice
        : rawCalculatedDeposit;
    final int remainingAmount = widget.totalPrice - calculatedDeposit;
    final int payableAmount = _depositEnabled && _payAmountType == 'deposit'
        ? calculatedDeposit
        : widget.totalPrice;
    final String submitHint = _submitHint();
    final bool termsReady = _termsStatus?.canSubmit ?? true;
    final bool canPressSubmit =
        widget.canSubmit &&
        !widget.isBlacklisted &&
        !_isSubmitting &&
        !widget.isSubmitting &&
        _paymentMethod != null &&
        termsReady &&
        submitHint.isEmpty;

    return Scaffold(
      backgroundColor: widget.theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: widget.theme.backgroundColor,
        foregroundColor: widget.theme.textColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '填寫預約資料',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: widget.formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _sectionCard(
                title: '聯絡資料',
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: widget.theme.backgroundColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Email：${user?.email ?? ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.theme.textColor.withValues(alpha: 0.62),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: widget.customerNameController,
                    decoration: _filledDecoration('聯絡人姓名 *'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: widget.customerPhoneController,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() {}),
                    decoration: _filledDecoration('聯絡電話 *'),
                  ),
                ],
              ),
              _sectionCard(
                title: '地址',
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    value: dropdownValueIfAllowed(_city, cityData.keys),
                    decoration: _filledDecoration('縣市 *'),
                    hint: const Text('選擇縣市'),
                    items: cityData.keys
                        .map<DropdownMenuItem<String>>(
                          (String city) => DropdownMenuItem<String>(
                            value: city,
                            child: Text(city),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      setState(() {
                        _city = dropdownValueIfAllowed(value, cityData.keys);
                        _district = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: dropdownValueIfAllowed(
                      _district,
                      _city == null
                          ? const <String>[]
                          : (cityData[_city] ?? const <String>[]),
                    ),
                    decoration: _filledDecoration('鄉鎮 *'),
                    hint: const Text('選擇區域'),
                    items:
                        (_city == null
                                ? const <String>[]
                                : (cityData[_city] ?? const <String>[]))
                            .map<DropdownMenuItem<String>>(
                              (String d) => DropdownMenuItem<String>(
                                value: d,
                                child: Text(d),
                              ),
                            )
                            .toList(),
                    onChanged: (String? value) {
                      setState(() {
                        _district = dropdownValueIfAllowed(
                          value,
                          _city == null
                              ? const <String>[]
                              : (cityData[_city] ?? const <String>[]),
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _detailAddressController,
                    decoration: _filledDecoration('詳細地址 *'),
                  ),
                ],
              ),
              _sectionCard(
                title: '緊急聯絡人',
                children: <Widget>[
                  TextFormField(
                    controller: _emergencyNameController,
                    decoration: _filledDecoration('姓名 *'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emergencyPhoneController,
                    decoration: _filledDecoration('電話 *'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: dropdownValueIfAllowed(
                      _emergencyRelation,
                      EmergencyRelationOptions.presets,
                    ),
                    decoration: _filledDecoration('與飼主關係 *'),
                    items: EmergencyRelationOptions.presets
                        .map(
                          (String item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      setState(() {
                        _emergencyRelation = dropdownValueIfAllowed(
                          value,
                          EmergencyRelationOptions.presets,
                        );
                      });
                    },
                  ),
                  if (_emergencyRelation ==
                      EmergencyRelationOptions.other) ...<Widget>[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customEmergencyRelationController,
                      decoration: _filledDecoration('請填寫與飼主關係 *'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('同聯絡地址'),
                    value: _sameAddress,
                    activeColor: widget.theme.primaryColor,
                    onChanged: (bool? value) {
                      setState(() {
                        _sameAddress = value ?? false;
                        if (_sameAddress) {
                          _emergencyAddressController.text =
                              '${_city ?? ''}${_district ?? ''}${_detailAddressController.text}';
                        }
                      });
                    },
                  ),
                  if (!_sameAddress)
                    TextFormField(
                      controller: _emergencyAddressController,
                      decoration: _filledDecoration('緊急聯絡地址 *'),
                    ),
                ],
              ),
              _sectionCard(
                title: '訂單備註',
                subtitle: '選填',
                children: <Widget>[
                  TextFormField(
                    controller: widget.noteController,
                    maxLines: 3,
                    decoration: _filledDecoration(
                      '備註',
                      hint: '例如：貓咪比較怕生、希望安排安靜一點的位置',
                    ),
                  ),
                ],
              ),
              _sectionCard(
                title: '費用與付款',
                children: <Widget>[
                  _feeLinesSection(payableAmount),
                  if (!_paymentSettingsLoaded)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_paymentLoadError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '付款方式載入失敗',
                            style: TextStyle(color: widget.theme.primaryColor),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _paymentSettingsLoaded = false;
                                _paymentLoadError = null;
                              });
                              _loadShopPaymentSettings();
                            },
                            child: const Text('重新載入'),
                          ),
                        ],
                      ),
                    )
                  else if (!_cashEnabled &&
                      !_transferEnabled &&
                      !_creditCardEnabled &&
                      !_atmEnabled &&
                      !_cvsCodeEnabled)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('店家目前尚未設定可用的付款方式，請聯絡店家。'),
                    ),
                  if (_depositEnabled) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      '付款金額',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: widget.theme.textColor,
                      ),
                    ),
                    _choiceCard(
                      title: '先付訂金 NT\$ $calculatedDeposit',
                      subtitle: '剩餘 NT\$ $remainingAmount 於現場結清',
                      selected: _payAmountType == 'deposit',
                      onTap: () => setState(() => _payAmountType = 'deposit'),
                    ),
                    _choiceCard(
                      title: '一次付清 NT\$ ${widget.totalPrice}',
                      selected: _payAmountType == 'full',
                      onTap: () => setState(() => _payAmountType = 'full'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '付款方式',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: widget.theme.textColor,
                    ),
                  ),
                  if (_paymentSettingsLoaded &&
                      _paymentLoadError == null) ...<Widget>[
                    if (_cashEnabled)
                      _choiceCard(
                        title: '到店付款',
                        selected: _paymentMethod == 'cash',
                        onTap: () => setState(() => _paymentMethod = 'cash'),
                      ),
                    if (_transferEnabled)
                      _choiceCard(
                        title: '銀行轉帳',
                        selected: _paymentMethod == 'transfer',
                        onTap: () =>
                            setState(() => _paymentMethod = 'transfer'),
                      ),
                    if (_creditCardEnabled)
                      _choiceCard(
                        title: '信用卡',
                        subtitle: '透過綠界線上付款',
                        selected: _paymentMethod == 'credit_card',
                        onTap: () =>
                            setState(() => _paymentMethod = 'credit_card'),
                      ),
                    if (_atmEnabled)
                      _choiceCard(
                        title: 'ATM 虛擬帳號',
                        subtitle: '透過綠界取得轉帳帳號',
                        selected: _paymentMethod == 'atm',
                        onTap: () => setState(() => _paymentMethod = 'atm'),
                      ),
                    if (_cvsCodeEnabled)
                      _choiceCard(
                        title: '超商代碼',
                        subtitle: '透過綠界取得繳費代碼',
                        selected: _paymentMethod == 'cvs_code',
                        onTap: () =>
                            setState(() => _paymentMethod = 'cvs_code'),
                      ),
                  ],
                ],
              ),
              if (_loadingTerms)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_termsLoadError)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: <Widget>[
                      Text(
                        '條款載入失敗',
                        style: TextStyle(color: widget.theme.textColor),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loadingTerms = true;
                            _termsLoadError = false;
                          });
                          _loadTermsStatus();
                        },
                        child: const Text('重試'),
                      ),
                    ],
                  ),
                )
              else if (_termsStatus != null)
                TermsConfirmationCard(
                  theme: widget.theme,
                  serviceType: widget.termsServiceType,
                  status: _termsStatus!,
                  onTap: _openTermsSheet,
                ),
              const SizedBox(height: 16),
              BookingPrimaryButton(
                theme: widget.theme,
                label: widget.submitLabel,
                enabled: canPressSubmit,
                onPressed: () {
                  if (!canPressSubmit) {
                    final String reason = submitHint.isNotEmpty
                        ? submitHint
                        : '請先完成付款方式與條款確認';
                    debugPrint('[BookingSubmit] 01 ignored: $reason');
                    _showSubmitMessage(reason);
                    return;
                  }
                  _handleSubmit(calculatedDeposit);
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BookingStickyBar(
        theme: widget.theme,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (submitHint.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  submitHint,
                  style: TextStyle(
                    color: widget.theme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            BookingPrimaryButton(
              theme: widget.theme,
              label: widget.submitLabel,
              enabled: canPressSubmit,
              onPressed: () {
                if (!canPressSubmit) {
                  final String reason = submitHint.isNotEmpty
                      ? submitHint
                      : widget.isBlacklisted
                      ? '目前無法使用預約功能'
                      : !widget.canSubmit
                      ? '預約條件尚未完成'
                      : _isSubmitting || widget.isSubmitting
                      ? '正在送出，請稍候'
                      : '請先完成付款方式與條款確認';
                  debugPrint('[BookingSubmit] 01 ignored: $reason');
                  _showSubmitMessage(reason);
                  return;
                }
                _handleSubmit(calculatedDeposit);
              },
            ),
          ],
        ),
      ),
    );
  }
}
