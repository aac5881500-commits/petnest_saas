// 檔案名稱：lib/features/booking/pages/booking_detail_page.dart
// 功能說明：客戶端住宿／安親訂單詳細頁（暖色系、共用元件編排）

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:petnest_saas/core/models/create_payment_request_model.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';
import 'package:petnest_saas/core/services/payment_function_service.dart';
import 'package:petnest_saas/core/services/pre_arrival_guide_service.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_completion_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_customer_pet_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_finance_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_message_preview.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_policy_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_preparation_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_stay_services_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_summary_card.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';
import 'package:petnest_saas/features/payment/pages/ecpay_payment_page.dart';
import 'package:petnest_saas/features/shop/pages/policy_version_detail_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/terms_confirmation_sheet.dart';

class BookingDetailPage extends StatelessWidget {
  const BookingDetailPage({super.key, required this.data, required this.docId});

  final Map<String, dynamic> data;
  final String docId;

  @override
  Widget build(BuildContext context) {
    return ShopFrontendThemeScope(
      shopId: SafeParse.parseString(data['shopId']),
      builder: (BuildContext context) {
        return _BookingDetailBody(data: data, docId: docId);
      },
    );
  }
}

class _BookingDetailBody extends StatefulWidget {
  const _BookingDetailBody({required this.data, required this.docId});

  final Map<String, dynamic> data;
  final String docId;

  @override
  State<_BookingDetailBody> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<_BookingDetailBody> {
  final TextEditingController _last5Controller = TextEditingController();
  final FocusNode _last5FocusNode = FocusNode();
  final GlobalKey _messageSectionKey = GlobalKey();
  final GlobalKey _financeKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _creatingPayment = false;
  bool _autoCancelling = false;
  Timer? _expireTimer;
  Future<DailyCareSettingModel>? _dailyCareSettingFuture;
  Future<PreArrivalGuideModel>? _guideFuture;
  String? _guideShopKey;

  @override
  void dispose() {
    _expireTimer?.cancel();
    _last5Controller.dispose();
    _last5FocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.docId)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return Scaffold(
                backgroundColor: BookingDetailUi.of(context).background,
                appBar: AppBar(
                  title: const Text('訂單詳細'),
                  backgroundColor: BookingDetailUi.of(context).background,
                ),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Scaffold(
                backgroundColor: BookingDetailUi.of(context).background,
                appBar: AppBar(
                  title: const Text('訂單詳細'),
                  backgroundColor: BookingDetailUi.of(context).background,
                ),
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('訂單載入失敗'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('重試'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final DocumentSnapshot<Map<String, dynamic>>? doc = snapshot.data;
            if (doc == null || !doc.exists || doc.data() == null) {
              return Scaffold(
                backgroundColor: BookingDetailUi.of(context).background,
                appBar: AppBar(
                  title: const Text('訂單詳細'),
                  backgroundColor: BookingDetailUi.of(context).background,
                ),
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('找不到訂單'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('返回'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final Map<String, dynamic> data = SafeParse.parseMap(doc.data());
            final BookingDetailViewData view =
                BookingDetailViewData.fromBooking(
                  data: data,
                  docId: widget.docId,
                );
            final String shopId = SafeParse.parseString(data['shopId']);
            final String transferLast5 = SafeParse.parseString(
              data['transferLast5'],
            );
            if (_last5Controller.text.isEmpty && transferLast5.isNotEmpty) {
              _last5Controller.text = transferLast5;
            }
            if (_isDepositExpired(data)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _autoCancelExpiredBooking(data);
              });
            } else {
              _scheduleDepositExpireCheck(data);
            }
            _dailyCareSettingFuture ??= _loadDailyCareSetting(shopId);
            final String guideKey = '$shopId:${view.kind}';
            if (_guideShopKey != guideKey) {
              _guideShopKey = guideKey;
              _guideFuture = PreArrivalGuideService.instance.getCustomerGuide(
                shopId: shopId,
                serviceType: view.kind,
              );
            }

            return Scaffold(
              backgroundColor: BookingDetailUi.of(context).background,
              appBar: AppBar(
                backgroundColor: BookingDetailUi.of(context).background,
                leading: IconButton(
                  icon: const Icon(Icons.home_rounded),
                  tooltip: '回首頁',
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => ShopPublicPage(shopId: shopId),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                ),
                title: Text(view.pageTitle),
                actions: <Widget>[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 168),
                    child: InkWell(
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: view.bookingCode),
                        );
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已複製訂單編號')),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                view.bookingCode,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: BookingDetailUi.of(context).text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy,
                              size: 16,
                              color: BookingDetailUi.of(context).muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: BookingDetailUi.constrain(
                ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(BookingDetailUi.pagePadding),
                  children: <Widget>[
                    BookingDetailSummaryCard(
                      view: view,
                      onCancel: () => _onCancel(view),
                      onContactShop: _scrollToMessageSection,
                    ),
                    FutureBuilder<PreArrivalGuideModel>(
                      future: _guideFuture,
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<PreArrivalGuideModel> guideSnap,
                          ) {
                            return BookingDetailPreparationSection(
                              view: view,
                              guide: guideSnap.data,
                              onOpenTerms: () => _openTerms(view),
                              onOpenPayment: _scrollToFinance,
                            );
                          },
                    ),
                    FutureBuilder<DailyCareSettingModel>(
                      future: _dailyCareSettingFuture,
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<DailyCareSettingModel> careSnap,
                          ) {
                            final DailyCareSettingModel setting =
                                careSnap.data ?? const DailyCareSettingModel();
                            return BookingDetailStayServicesSection(
                              view: view,
                              bookingId: widget.docId,
                              downloadHoursAfterCheckout:
                                  setting.downloadHoursAfterCheckout,
                            );
                          },
                    ),
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: shopId.isEmpty
                          ? const Stream.empty()
                          : FirebaseFirestore.instance
                                .collection('shops')
                                .doc(shopId)
                                .snapshots(),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<
                              DocumentSnapshot<Map<String, dynamic>>
                            >
                            shopSnapshot,
                          ) {
                            final Map<String, dynamic> shopData =
                                SafeParse.parseMap(shopSnapshot.data?.data());
                            final Map<String, dynamic> paymentSetting =
                                SafeParse.parseMap(shopData['paymentSetting']);
                            final Map<String, dynamic> operationSettings =
                                SafeParse.parseMap(
                                  paymentSetting['operationSettings'],
                                );
                            final String reviewStatus = SafeParse.parseString(
                              paymentSetting['reviewStatus'],
                            ).toLowerCase();
                            final bool ecpayEnabled = SafeParse.parseBool(
                              operationSettings['ecpayEnabled'],
                            );
                            final bool creditCardEnabled = SafeParse.parseBool(
                              operationSettings['creditCardEnabled'],
                            );
                            final bool atmEnabled = SafeParse.parseBool(
                              operationSettings['atmEnabled'],
                            );
                            final bool cvsEnabled = SafeParse.parseBool(
                              operationSettings['cvsCodeEnabled'],
                            );
                            final bool canCreateOnlinePayment =
                                reviewStatus == 'approved' &&
                                ecpayEnabled &&
                                (creditCardEnabled ||
                                    atmEnabled ||
                                    cvsEnabled) &&
                                !SafeParse.parseBool(
                                  paymentSetting['platformSuspended'],
                                ) &&
                                !SafeParse.parseBool(
                                  paymentSetting['shopDisabled'],
                                ) &&
                                view.canCreateOnlinePaymentCandidate;
                            return KeyedSubtree(
                              key: _financeKey,
                              child: BookingDetailFinanceSection(
                                view: view,
                                bookingId: widget.docId,
                                shopFlags: BookingDetailShopPaymentFlags(
                                  canCreateOnlinePayment:
                                      canCreateOnlinePayment,
                                  creditCardEnabled: creditCardEnabled,
                                  atmEnabled: atmEnabled,
                                  cvsEnabled: cvsEnabled,
                                ),
                                last5Controller: _last5Controller,
                                loading: _loading,
                                creatingPayment: _creatingPayment,
                                onUploadImage: _uploadImage,
                                onSubmitDeposit: _submitDeposit,
                                onDeleteTransferImage: _deleteTransferImage,
                                onPayOnline: () =>
                                    _showOnlinePaymentMethodSheet(
                                      booking: data,
                                      flags: BookingDetailShopPaymentFlags(
                                        canCreateOnlinePayment:
                                            canCreateOnlinePayment,
                                        creditCardEnabled: creditCardEnabled,
                                        atmEnabled: atmEnabled,
                                        cvsEnabled: cvsEnabled,
                                      ),
                                    ),
                              ),
                            );
                          },
                    ),
                    BookingDetailCustomerPetSection(data: data, view: view),
                    BookingDetailPolicySection(
                      view: view,
                      onOpen: () => _openTerms(view),
                    ),
                    BookingDetailMessagePreview(
                      view: view,
                      bookingId: widget.docId,
                      sectionKey: _messageSectionKey,
                    ),
                    BookingDetailCompletionSection(
                      view: view,
                      bookingId: widget.docId,
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }

  Future<DailyCareSettingModel> _loadDailyCareSetting(String shopId) async {
    if (shopId.trim().isEmpty) {
      return const DailyCareSettingModel();
    }
    return DailyCareSettingService.instance.getSetting(shopId.trim());
  }

  void _scrollToMessageSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _messageSectionKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        return;
      }
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _scrollToFinance() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _financeKey.currentContext;
      if (target == null) {
        return;
      }
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _onCancel(BookingDetailViewData view) async {
    if (view.paidCancelNeedsRefundHint) {
      final bool? go = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('取消訂單'),
            content: const Text('取消訂單不會自動完成退款。付款退款狀態請聯絡店家。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('返回'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('繼續取消'),
              ),
            ],
          );
        },
      );
      if (go != true) {
        return;
      }
    }
    if (!context.mounted) {
      return;
    }
    final String? cancelReason = await _showCancelReasonDialog(context);
    if (cancelReason == null || !context.mounted) {
      return;
    }
    await BookingService.instance.cancelBooking(
      bookingId: widget.docId,
      cancelReason: cancelReason,
      cancelBy: 'customer',
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('訂單已取消')));
  }

  Future<void> _openTerms(BookingDetailViewData view) async {
    if (view.termsState == BookingDetailTermsState.needsReconfirm) {
      await showTermsConfirmationSheet(
        context: context,
        shopId: SafeParse.parseString(view.raw['shopId']),
        theme: ShopFrontendTheme.of(context).home,
        serviceType: view.isDaycare
            ? PolicyApplicableService.daycare
            : PolicyApplicableService.accommodation,
      );
      return;
    }
    final String shopId = SafeParse.parseString(view.raw['shopId']);
    final String docId = SafeParse.parseString(
      view.raw['termsVersionDocumentId'],
    );
    final String versionId = docId.isNotEmpty
        ? docId
        : (view.termsVersion > 0 ? 'v${view.termsVersion}' : '');
    if (shopId.isEmpty || versionId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('舊訂單／尚無條款確認紀錄')));
      return;
    }
    final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('shops')
        .doc(shopId)
        .collection('policy_versions')
        .doc(versionId)
        .get();
    if (!mounted) {
      return;
    }
    if (!doc.exists || doc.data() == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('找不到該版本條款')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PolicyVersionDetailPage(data: doc.data()!),
      ),
    );
  }

  Future<void> _showOnlinePaymentMethodSheet({
    required Map<String, dynamic> booking,
    required BookingDetailShopPaymentFlags flags,
  }) async {
    if (_creatingPayment) {
      return;
    }
    final String? selectedMethod = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext bottomSheetContext) {
        Widget tile({
          required String method,
          required String title,
          required String subtitle,
          required IconData icon,
        }) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(icon)),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(bottomSheetContext, method),
          );
        }

        final List<Widget> tiles = <Widget>[];
        if (flags.creditCardEnabled) {
          tiles.add(
            tile(
              method: PaymentMethodType.creditCard,
              title: '信用卡',
              subtitle: '前往綠界信用卡付款頁',
              icon: Icons.credit_card,
            ),
          );
        }
        if (flags.atmEnabled) {
          tiles.add(
            tile(
              method: PaymentMethodType.atm,
              title: 'ATM 虛擬帳號',
              subtitle: '取得 ATM 繳費帳號',
              icon: Icons.account_balance,
            ),
          );
        }
        if (flags.cvsEnabled) {
          tiles.add(
            tile(
              method: PaymentMethodType.convenienceStoreCode,
              title: '超商代碼',
              subtitle: '取得超商繳費代碼',
              icon: Icons.storefront_outlined,
            ),
          );
        }
        if (tiles.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text('店家目前未開放線上付款方式'),
          );
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '選擇付款方式',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ...tiles,
                TextButton(
                  onPressed: () => Navigator.pop(bottomSheetContext),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selectedMethod == null || !mounted) {
      return;
    }
    await _createRemainingPayment(
      booking: booking,
      paymentMethod: selectedMethod,
    );
  }

  Future<void> _createRemainingPayment({
    required Map<String, dynamic> booking,
    required String paymentMethod,
  }) async {
    if (_creatingPayment) {
      return;
    }
    final BookingDetailViewData view = BookingDetailViewData.fromBooking(
      data: booking,
      docId: widget.docId,
    );
    final String shopId = SafeParse.parseString(booking['shopId']);
    if (shopId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('找不到店家資料。')));
      return;
    }
    if (!PaymentMethodType.isOnlinePayment(paymentMethod)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇有效的線上付款方式。')));
      return;
    }
    if (view.totalAmount <= 0 || view.remainingAmount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('這筆訂單目前沒有待支付金額。')));
      return;
    }
    final String paymentPurpose = view.paidAmount > 0
        ? PaymentPurpose.balance
        : PaymentPurpose.full;
    const String amountType = PaymentAmountType.full;
    final String paymentRequestId = FirebaseFirestore.instance
        .collection('payments')
        .doc()
        .id;
    setState(() {
      _creatingPayment = true;
    });
    try {
      final paymentResult = await PaymentFunctionService.instance.createPayment(
        request: CreatePaymentRequestModel(
          shopId: shopId,
          bookingId: widget.docId,
          paymentMethod: paymentMethod,
          amountType: amountType,
          paymentPurpose: paymentPurpose,
          amount: view.remainingAmount,
          requestId: paymentRequestId,
        ),
      );
      if (!mounted) {
        return;
      }
      if (!paymentResult.hasPaymentHtml) {
        throw const PaymentFunctionException(
          code: 'missing-payment-html',
          message: '綠界付款頁資料不完整，請稍後再試。',
        );
      }
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => EcpayPaymentPage(
            paymentHtml: paymentResult.paymentHtml,
            paymentId: paymentResult.paymentId,
            bookingId: widget.docId,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = error is PaymentFunctionException
          ? error.message
          : error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _creatingPayment = false;
        });
      }
    }
  }

  Future<String?> _showCancelReasonDialog(BuildContext context) async {
    String selectedReason = '客戶自行取消';
    final TextEditingController otherReasonController = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('取消訂單原因'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: '客戶自行取消', child: Text('客戶自行取消')),
                      DropdownMenuItem(value: '行程變更', child: Text('行程變更')),
                      DropdownMenuItem(value: '重複預約', child: Text('重複預約')),
                      DropdownMenuItem(
                        value: '改用其他付款方式',
                        child: Text('改用其他付款方式'),
                      ),
                      DropdownMenuItem(value: '其他', child: Text('其他')),
                    ],
                    onChanged: (String? value) {
                      setDialogState(() {
                        selectedReason = value ?? '客戶自行取消';
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: '取消原因',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (selectedReason == '其他') ...<Widget>[
                    const SizedBox(height: 12),
                    TextField(
                      controller: otherReasonController,
                      decoration: const InputDecoration(
                        labelText: '其他原因',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final String reason = selectedReason == '其他'
                        ? otherReasonController.text.trim()
                        : selectedReason;
                    if (reason.isEmpty) {
                      return;
                    }
                    Navigator.pop(context, reason);
                  },
                  child: const Text('確認取消'),
                ),
              ],
            );
          },
        );
      },
    );
    otherReasonController.dispose();
    return result;
  }

  Future<void> _submitDeposit() async {
    final String last5 = _last5Controller.text.trim();
    final DocumentSnapshot<Map<String, dynamic>> bookingDoc =
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.docId)
            .get();
    final Map<String, dynamic> bookingData = SafeParse.parseMap(
      bookingDoc.data(),
    );
    final String transferImageUrl = SafeParse.parseString(
      bookingData['transferImageUrl'],
    );
    if (transferImageUrl.isEmpty) {
      if (!context.mounted) {
        return;
      }
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('尚未上傳轉帳截圖'),
          content: const Text('你目前沒有上傳轉帳截圖，確定只送出後五碼嗎？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('返回上傳'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確定送出'),
            ),
          ],
        ),
      );
      if (confirm != true) {
        return;
      }
    }
    if (last5.length != 5) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入正確的後五碼')));
      return;
    }
    try {
      setState(() {
        _loading = true;
      });
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.docId)
          .update(<String, dynamic>{
            'transferLast5': last5,
            'depositStatus': 'pending_review',
            'depositSubmittedAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('訂金已送出')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('錯誤：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _uploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 75,
    );
    if (picked == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('圖片太大，請選擇 5MB 以下的圖片')));
        setState(() {
          _loading = false;
        });
        return;
      }
      final ref = FirebaseStorage.instance
          .ref()
          .child('booking_images')
          .child(widget.docId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final String url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.docId)
          .update(<String, dynamic>{'transferImageUrl': url});
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('圖片上傳成功')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上傳失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteTransferImage(String imageUrl) async {
    if (imageUrl.isEmpty) {
      return;
    }
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除轉帳截圖'),
        content: const Text('確定要刪除目前上傳的轉帳截圖嗎？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定刪除'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.docId)
          .update(<String, dynamic>{'transferImageUrl': FieldValue.delete()});
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除轉帳截圖')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool _needDepositPayment(Map<String, dynamic> data) {
    final int depositAmount = SafeParse.parseMoney(data['depositAmount']);
    final String paymentMethod = SafeParse.parseString(data['paymentMethod']);
    final String depositStatus = SafeParse.parseString(data['depositStatus']);
    final String status = SafeParse.parseString(data['status']);
    return depositAmount > 0 &&
        (paymentMethod == 'transfer' || paymentMethod == 'cash') &&
        depositStatus != 'pending' &&
        depositStatus != 'pending_review' &&
        depositStatus != 'confirmed' &&
        status != 'cancelled';
  }

  bool _isDepositExpired(Map<String, dynamic> data) {
    if (!_needDepositPayment(data)) {
      return false;
    }
    final DateTime? expireAt = SafeParse.parseDate(data['depositExpireAt']);
    if (expireAt == null) {
      return false;
    }
    return DateTime.now().isAfter(expireAt);
  }

  Future<void> _autoCancelExpiredBooking(Map<String, dynamic> data) async {
    if (_autoCancelling) {
      return;
    }
    _autoCancelling = true;
    try {
      await BookingService.instance.cancelBooking(
        bookingId: widget.docId,
        cancelReason: '訂單保留逾期自動取消',
        cancelBy: 'system',
      );
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.docId)
          .update(<String, dynamic>{'depositExpired': true});
    } finally {
      _autoCancelling = false;
    }
  }

  void _scheduleDepositExpireCheck(Map<String, dynamic> data) {
    if (!_needDepositPayment(data)) {
      return;
    }
    final DateTime? expireAt = SafeParse.parseDate(data['depositExpireAt']);
    if (expireAt == null) {
      return;
    }
    _expireTimer?.cancel();
    final Duration diff = expireAt.difference(DateTime.now());
    if (diff.isNegative) {
      return;
    }
    _expireTimer = Timer(diff, () {
      if (!mounted) {
        return;
      }
      _autoCancelExpiredBooking(data);
    });
  }
}
