// 檔案名稱：lib/features/shop/pages/shop_booking_page.dart
// 功能說明：前台住宿預約主頁，負責日期、寵物、房型、加值服務、優惠與送單流程。

import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/models/create_payment_request_model.dart';
import 'package:petnest_saas/core/services/payment_function_service.dart';
import 'package:petnest_saas/features/payment/pages/ecpay_payment_page.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/features/booking/pages/booking_success_page.dart';
import 'package:petnest_saas/core/widgets/app_drawer.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_app_drawer.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_room_type_section.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_addon_section.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_pet_section.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_summary_helper.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_date_section.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_next_step_section.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_payload.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_addons_helper.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_calendar_dialog.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_campaign_ui.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_member_coupon_ui.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_helper.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_submit_helper.dart';
import 'package:petnest_saas/core/models/discount_campaign_model.dart';
import 'package:petnest_saas/core/services/discount_campaign_service.dart';
import 'package:petnest_saas/core/services/discount_campaign_calculator.dart';
import 'package:petnest_saas/core/models/special_date_surcharge_model.dart';
import 'package:petnest_saas/core/services/special_date_surcharge_service.dart';
import 'package:petnest_saas/core/services/special_date_surcharge_calculator.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/coupon_template_model.dart';
import '../../../core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/services/booking_service.dart';

class ShopBookingPage extends StatefulWidget {
  const ShopBookingPage({
    super.key,
    required this.shopId,
    this.preSelectedRoomType,
    this.theme = HomeThemeModel.classicDefault,
    this.useModernDrawer = false,
  });

  final String shopId;
  final Map<String, dynamic>? preSelectedRoomType;
  final HomeThemeModel theme;
  final bool useModernDrawer;

  @override
  State<ShopBookingPage> createState() => _ShopBookingPageState();
}

class _ShopBookingPageState extends State<ShopBookingPage> {
  late final Stream<Map<String, dynamic>?> _shopStream;
  List<DiscountCampaignModel> _enabledCampaigns =
      const <DiscountCampaignModel>[];
  bool _campaignsLoading = true;
  List<SpecialDateSurchargeModel> _enabledSpecialDateSurcharges =
      const <SpecialDateSurchargeModel>[];
  bool _specialDateSurchargesLoading = true;
  Map<String, int> _memberCampaignUsage = <String, int>{};
  Map<String, int> _memberCampaignUsedNights = <String, int>{};

  /// 👤 會員加入目前店家的時間
  /// 來源：shops/{shopId}/members/{uid}.createdAt
  DateTime? _memberJoinedAt;

  bool _isFirstBooking = false;
  bool _firstBookingLoading = true;
  List<MemberCouponModel> _availableMemberCoupons = const <MemberCouponModel>[];
  MemberCouponModel? _selectedMemberCoupon;
  bool _memberCouponsLoading = true;
  Map<String, dynamic>? _currentShopData;

  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();

    _shopStream = ShopService.instance.streamShop(widget.shopId);

    _loadMemberData();
    _loadAddons();
    _loadDiscountCampaigns();
    _loadSpecialDateSurcharges();
    _loadFirstBookingStatus();
    _loadMemberCampaignUsage();
    _loadAvailableMemberCoupons();
  }

  final _formKey = GlobalKey<FormState>();

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _noteController = TextEditingController();

  bool _submitting = false;

  /// 🔒 同一次送出流程固定使用同一個請求 ID
  String? _bookingRequestId;

  /// 🔒 記錄產生 requestId 時的預約內容
  String? _bookingRequestSignature;

  final bool _checkingRange = false;
  bool _isBlacklisted = false;

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;
  String? _selectedServiceType;
  Map<String, dynamic>? _selectedRoomType;
  bool _showAddons = true;
  final List<Map<String, dynamic>> _selectedValueServices = [];
  final Map<String, List<String>> _selectedCustomServices = {};

  /// 🕐 每日分時段服務選擇結果
  ///
  /// 第一層 key：服務 ID
  /// 第二層 key：寵物 ID
  /// 第三層 key：住宿日期 yyyy-MM-dd
  /// value：該日期選擇的時段 ID 清單
  final Map<String, Map<String, Map<String, List<String>>>>
  _selectedDailyTimedServices = {};
  Map<String, dynamic>? _selectedTimeAddon;
  Map<String, dynamic>? _addonData;
  bool _addonLoading = true;

  bool _rangeChecked = false;
  bool _rangeBookable = false;
  String _rangeMessage = '';

  /// 1 日期與貓咪、2 房型與服務、3 費用與確認
  int _currentStep = 1;

  final List<String> _selectedPetIds = [];
  List<Map<String, dynamic>> _pets = [];

  Future<void> _loadMemberData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data == null) return;

    final shopMemberDoc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('members')
        .doc(user.uid)
        .get();

    final shopMemberData = shopMemberDoc.data() ?? {};
    final isShopBlacklisted = shopMemberData['blacklisted'] == true;

    /// 👤 會員加入目前店家的時間
    final dynamic memberCreatedAt = shopMemberData['createdAt'];

    DateTime? memberJoinedAt;

    if (memberCreatedAt is Timestamp) {
      memberJoinedAt = memberCreatedAt.toDate();
    }

    if (!mounted) return;

    setState(() {
      _customerNameController.text = data['name'] ?? '';
      _customerPhoneController.text = data['phone'] ?? '';
      _isBlacklisted = isShopBlacklisted;
      _memberJoinedAt = memberJoinedAt;
    });
  }

  Future<void> _loadAddons() async {
    final doc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('addons')
        .doc('main')
        .get();

    setState(() {
      _addonData = doc.data();
      _addonLoading = false;
    });
  }

  Future<void> _loadDiscountCampaigns() async {
    try {
      final List<DiscountCampaignModel> campaigns =
          await DiscountCampaignService.instance.getEnabledCampaigns(
            widget.shopId,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _enabledCampaigns = campaigns;
        _campaignsLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _enabledCampaigns = const <DiscountCampaignModel>[];
        _campaignsLoading = false;
      });

      debugPrint('讀取優惠活動失敗：$error');
    }
  }

  Future<void> _loadSpecialDateSurcharges() async {
    try {
      final List<SpecialDateSurchargeModel> surcharges =
          await SpecialDateSurchargeService.instance.getEnabledSurcharges(
            widget.shopId,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _enabledSpecialDateSurcharges = surcharges;
        _specialDateSurchargesLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _enabledSpecialDateSurcharges = const <SpecialDateSurchargeModel>[];
        _specialDateSurchargesLoading = false;
      });

      debugPrint('讀取特殊日期加價失敗：$error');
    }
  }

  Future<void> _loadFirstBookingStatus() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isFirstBooking = false;
        _firstBookingLoading = false;
      });
      return;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('bookings')
              .where('shopId', isEqualTo: widget.shopId)
              .where('userId', isEqualTo: user.uid)
              .get();

      final bool hasValidBooking = snapshot.docs.any((
        QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
        final String status = (document.data()['status'] ?? '').toString();

        return status == 'pending' ||
            status == 'confirmed' ||
            status == 'checked_in' ||
            status == 'completed';
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _isFirstBooking = !hasValidBooking;
        _firstBookingLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      // 查詢失敗時不套用首次優惠，避免誤折。
      setState(() {
        _isFirstBooking = false;
        _firstBookingLoading = false;
      });

      debugPrint('判斷首次預約失敗：$error');
    }
  }

  Future<void> _loadMemberCampaignUsage() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _memberCampaignUsage = <String, int>{};
        _memberCampaignUsedNights = <String, int>{};
      });
      return;
    }

    try {
      final List<Map<String, int>> results =
          await Future.wait(<Future<Map<String, int>>>[
            DiscountCampaignService.instance.getMemberCampaignUsage(
              shopId: widget.shopId,
              userId: user.uid,
            ),
            DiscountCampaignService.instance.getMemberCampaignUsedNights(
              shopId: widget.shopId,
              userId: user.uid,
            ),
          ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _memberCampaignUsage = results[0];
        _memberCampaignUsedNights = results[1];
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _memberCampaignUsage = <String, int>{};
        _memberCampaignUsedNights = <String, int>{};
      });

      debugPrint('讀取會員優惠使用資料失敗：$error');
    }
  }

  Future<void> _loadAvailableMemberCoupons() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _availableMemberCoupons = const <MemberCouponModel>[];
        _selectedMemberCoupon = null;
        _memberCouponsLoading = false;
      });
      return;
    }

    try {
      final List<MemberCouponModel> coupons = await MemberCouponService.instance
          .getAvailableMemberCoupons(shopId: widget.shopId, userId: user.uid);

      if (!mounted) return;

      setState(() {
        _availableMemberCoupons = coupons;
        _memberCouponsLoading = false;

        if (_selectedMemberCoupon != null &&
            !coupons.any(
              (MemberCouponModel coupon) =>
                  coupon.id == _selectedMemberCoupon!.id,
            )) {
          _selectedMemberCoupon = null;
        }
      });
    } catch (error) {
      debugPrint('讀取會員優惠券失敗：$error');

      if (!mounted) return;

      setState(() {
        _availableMemberCoupons = const <MemberCouponModel>[];
        _selectedMemberCoupon = null;
        _memberCouponsLoading = false;
      });
    }
  }

  DateTime _calendarMonth = DateTime.now();
  Future<FrontCalendarPayload>? _calendarFuture;

  @override
  void dispose() {
    _scrollController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _nights {
    if (_startDate == null || _endDate == null) return 0;
    return BookingService.instance.calculateNights(
      startDate: _startDate!,
      endDate: _endDate!,
    );
  }

  bool get _canShowFormFields {
    return _startDate != null && _endDate != null;
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step.clamp(1, 3);
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  int get _selectedAddonCount {
    return BookingAddonsHelper.selectedItemCount(
      selectedTimeAddon: _selectedTimeAddon,
      selectedValueServices: _selectedValueServices,
      selectedCustomServices: _selectedCustomServices,
      selectedDailyTimedServices: _selectedDailyTimedServices,
    );
  }

  int _addonTotalAmount() {
    final Map<String, int> parts = BookingSummaryHelper.calculatePriceParts(
      selectedRoomType:
          _selectedRoomType ??
          const <String, dynamic>{'price': 0, 'extraPrice': 0},
      nights: _nights,
      selectedPetIds: _selectedPetIds,
      selectedTimeAddon: _selectedTimeAddon,
      selectedValueServices: _selectedValueServices,
      selectedCustomServices: _selectedCustomServices,
      selectedDailyTimedServices: _selectedDailyTimedServices,
      addonData: _addonData,
    );
    return parts['addonTotal'] ?? 0;
  }

  int _estimatedTotal(Map<String, dynamic> shop) {
    if (_selectedRoomType == null) {
      return _addonTotalAmount();
    }
    return (_calculateMemberCouponInfo(shop)['finalTotalAfterCoupon'] ?? 0)
        .toInt();
  }

  String? get _step1Hint {
    if (_startDate == null || _endDate == null) {
      return '請選擇入住與退房日期';
    }
    if (_selectedPetIds.isEmpty) {
      return '請選擇入住寵物';
    }
    return null;
  }

  String? get _step2Hint {
    if (_selectedRoomType == null) {
      return '請選擇房型';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep <= 1,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || _currentStep <= 1) {
          return;
        }
        _goToStep(_currentStep - 1);
      },
      child: Scaffold(
        backgroundColor: widget.theme.backgroundColor,
        appBar: AppBar(
          backgroundColor: widget.theme.cardColor,
          foregroundColor: widget.theme.textColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: _currentStep <= 1,
          leading: _currentStep > 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _goToStep(_currentStep - 1),
                )
              : null,
          title: Text(
            '我要預約',
            style: TextStyle(
              color: widget.theme.textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        drawer: widget.useModernDrawer
            ? StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('shops')
                    .doc(widget.shopId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Drawer(
                      child: Center(
                        child: Text(
                          '選單載入失敗',
                          style: TextStyle(color: widget.theme.textColor),
                        ),
                      ),
                    );
                  }

                  final shop = snapshot.data?.data();

                  if (shop == null) {
                    return Drawer(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: widget.theme.primaryColor,
                        ),
                      ),
                    );
                  }

                  return ModernAppDrawer(
                    shopId: widget.shopId,
                    shop: shop,
                    theme: widget.theme,
                  );
                },
              )
            : AppDrawer(shopId: widget.shopId, theme: widget.theme),

        body: StreamBuilder<Map<String, dynamic>?>(
          stream: _shopStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('讀取店家資料失敗：${snapshot.error}'));
            }

            final shop = snapshot.data;
            if (shop == null) {
              return const Center(child: Text('找不到店家資料'));
            }

            _currentShopData = shop;

            final List<dynamic> rawServiceTypes = shop['serviceTypes'] ?? [];
            final List<String> serviceTypes = rawServiceTypes
                .map((e) => e.toString())
                .toList();

            if (_selectedServiceType == null && serviceTypes.isNotEmpty) {
              _selectedServiceType = serviceTypes.first;
            }

            final bool bookingEnabled = BookingAddonsHelper.parseBool(
              shop['bookingEnabled'],
              fallback: true,
            );

            if (_isBlacklisted) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.block,
                              size: 48,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '目前無法使用預約功能',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.red.shade800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '目前無法使用線上預約服務。\n如需協助，請聯繫店家確認。',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: <Widget>[
                BookingStepIndicator(
                  currentStep: _currentStep,
                  theme: widget.theme,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: PageStorageKey<String>(
                      'shop_booking_scroll_$_currentStep',
                    ),
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: _buildStepContent(
                          shop: shop,
                          bookingEnabled: bookingEnabled,
                        ),
                      ),
                    ),
                  ),
                ),
                BookingStickyBar(
                  theme: widget.theme,
                  child: _buildStepBottomBar(
                    shop: shop,
                    serviceTypes: serviceTypes,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStepContent({
    required Map<String, dynamic> shop,
    required bool bookingEnabled,
  }) {
    if (_currentStep == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BookingDateSection(
            shopName: shop['name'] ?? '未命名店家',
            bookingEnabled: bookingEnabled,
            theme: widget.theme,
            startDate: _startDate,
            endDate: _endDate,
            nights: _nights,
            onOpenCalendar: () async {
              await _openCalendarDialog(shop);
            },
          ),
          if (_startDate == null || _endDate == null)
            BookingThemedCard(
              theme: widget.theme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '預約前提醒',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: widget.theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '訂房安全提醒',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: widget.theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '本平台僅提供預約系統服務，實際住宿與照護內容由店家負責。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: widget.theme.textColor.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          BookingPetSection(
            selectedPetIds: _selectedPetIds,
            theme: widget.theme,
            onPetsLoaded: (pets) {
              _pets = pets;
            },
            onTogglePet: (petId, value) {
              setState(() {
                if (value) {
                  _selectedPetIds.add(petId);
                } else {
                  _selectedPetIds.remove(petId);
                }
                _selectedRoomType = null;
              });
            },
          ),
        ],
      );
    }

    if (_currentStep == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BookingRoomTypeSection(
            shopId: widget.shopId,
            startDate: _startDate,
            endDate: _endDate,
            selectedPetIds: _selectedPetIds,
            selectedRoomType: _selectedRoomType,
            theme: widget.theme,
            onSelectRoomType: (roomType) {
              setState(() {
                _selectedRoomType = roomType;
              });
            },
          ),
          if (_selectedRoomType != null) ...<Widget>[
            _buildCurrentCampaignCard(shop),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '已選房型：${_selectedRoomType!['name']}',
                style: const TextStyle(
                  color: Color(0xFF2E8B47),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          BookingAddonSection(
            showAddons: _showAddons,
            addonLoading: _addonLoading,
            addonData: _addonData,
            selectedPetIds: _selectedPetIds,
            pets: _pets,
            selectedTimeAddon: _selectedTimeAddon,
            selectedValueServices: _selectedValueServices,
            selectedCustomServices: _selectedCustomServices,
            startDate: _startDate,
            endDate: _endDate,
            selectedDailyTimedServices: _selectedDailyTimedServices,
            theme: widget.theme,
            addonTotal: _addonTotalAmount(),
            onDailyTimedServicesChanged: () {
              setState(() {});
            },
            onToggleShowAddons: () {
              setState(() {
                _showAddons = !_showAddons;
              });
            },
            onSelectTimeAddon: (item) {
              setState(() {
                _selectedTimeAddon = item;
              });
            },
            onToggleValueService: (item) {
              setState(() {
                final isSelected = _selectedValueServices.any(
                  (e) => e['name'] == item['name'],
                );
                if (isSelected) {
                  _selectedValueServices.removeWhere(
                    (e) => e['name'] == item['name'],
                  );
                } else {
                  _selectedValueServices.add({
                    ...item,
                    'petIds': List<String>.from(_selectedPetIds),
                  });
                }
              });
            },
            onToggleCustomService: (item) {
              setState(() {
                final name = item['name'];
                if (_selectedCustomServices.containsKey(name)) {
                  _selectedCustomServices.remove(name);
                } else {
                  _selectedCustomServices[name] = List.from(_selectedPetIds);
                }
              });
            },
            onToggleCustomPet: (serviceName, petId, selected) {
              setState(() {
                final selectedList = _selectedCustomServices[serviceName] ?? [];
                final newList = List<String>.from(selectedList);
                if (selected) {
                  newList.add(petId);
                } else {
                  newList.remove(petId);
                }
                _selectedCustomServices[serviceName] = newList;
              });
            },
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_selectedRoomType != null &&
            _startDate != null &&
            _endDate != null) ...<Widget>[
          _buildMemberCouponSection(),
          const SizedBox(height: 4),
          _buildBookingSummary(shop),
        ] else
          BookingThemedCard(
            theme: widget.theme,
            child: Text(
              '請先完成日期、寵物與房型選擇。',
              style: TextStyle(fontSize: 14, color: widget.theme.textColor),
            ),
          ),
      ],
    );
  }

  Widget _buildStepBottomBar({
    required Map<String, dynamic> shop,
    required List<String> serviceTypes,
  }) {
    if (_currentStep == 1) {
      final String? hint = _step1Hint;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                hint,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.theme.textColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          BookingPrimaryButton(
            theme: widget.theme,
            label: '下一步',
            onPressed: hint == null ? () => _goToStep(2) : null,
          ),
        ],
      );
    }

    if (_currentStep == 2) {
      final String? hint = _step2Hint;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '已選 $_selectedAddonCount 項加值服務',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Text(
                '預估總額 ${ShopReportFormat.money(_estimatedTotal(shop))}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: widget.theme.textColor,
                ),
              ),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                hint,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.theme.textColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          const SizedBox(height: 8),
          BookingPrimaryButton(
            theme: widget.theme,
            label: '下一步',
            onPressed: hint == null ? () => _goToStep(3) : null,
          ),
        ],
      );
    }

    return BookingNextStepSection(
      selectedPetIds: _selectedPetIds,
      startDate: _startDate,
      endDate: _endDate,
      canShow: _canShowFormFields,
      canSubmit: _canSubmit(serviceTypes),
      isBlacklisted: _isBlacklisted,
      selectedRoomType: _selectedRoomType == null
          ? null
          : <String, dynamic>{
              ..._selectedRoomType!,
              'selectedPetCount': _selectedPetIds.length,
            },
      nights: _nights,
      totalPrice: _selectedRoomType == null
          ? 0
          : (_calculateMemberCouponInfo(shop)['finalTotalAfterCoupon'] ?? 0)
                .toInt(),
      originalTotal: _selectedRoomType == null
          ? 0
          : (_calculateDiscountInfo(shop)['originalTotal'] ?? 0).toInt(),
      discountAmount: _selectedRoomType == null
          ? 0
          : (_calculateDiscountInfo(shop)['discountAmount'] ?? 0).toInt(),
      discountCampaignName: _selectedRoomType == null
          ? ''
          : (_calculateDiscountInfo(shop)['discountCampaignName'] ?? '')
                .toString(),
      specialDateSurchargeAmount: _selectedRoomType == null
          ? 0
          : (_calculateDiscountInfo(shop)['specialDateSurchargeAmount'] ?? 0)
                .toInt(),
      valueServices: _selectedValueServices,
      formKey: _formKey,
      shopId: widget.shopId,
      serviceTypes: serviceTypes,
      selectedServiceType: _selectedServiceType,
      customerNameController: _customerNameController,
      customerPhoneController: _customerPhoneController,
      noteController: _noteController,
      isSubmitting: _submitting,
      theme: widget.theme,
      compact: true,
      onServiceChanged: (value) {
        setState(() {
          _selectedServiceType = value;
        });
      },
      onSubmitWithData:
          (
            address,
            emergencyName,
            emergencyPhone,
            relation,
            emergencyAddress,
            phone2,
            depositAmount,
            paymentMethod,
            payAmountType,
            termsConsent,
          ) async {
            await _submitBooking(
              shop,
              address: address,
              emergencyName: emergencyName,
              emergencyPhone: emergencyPhone,
              relation: relation,
              emergencyAddress: emergencyAddress,
              phone2: phone2,
              depositAmount: depositAmount,
              paymentMethod: paymentMethod,
              payAmountType: payAmountType,
              termsConsent: termsConsent,
            );
          },
    );
  }

  Widget _buildMemberCouponSection() {
    final MemberCouponModel? selectedCoupon = _selectedMemberCoupon;
    final Map<String, dynamic> discountInfo = _calculateDiscountInfo(
      _currentShopData,
    );
    final bool couponBlockedBySpecialDate =
        (discountInfo['couponBlockedBySpecialDate'] ?? false) == true;
    final String? unavailableReason = selectedCoupon == null
        ? null
        : _memberCouponUnavailableReason(selectedCoupon);
    final int couponDiscountAmount = selectedCoupon == null
        ? 0
        : (_calculateMemberCouponInfo(
                    _currentShopData,
                  )['couponDiscountAmount'] ??
                  0)
              .toInt();

    return BookingMemberCouponSection(
      theme: widget.theme,
      selectedCoupon: selectedCoupon,
      availableCoupons: _availableMemberCoupons,
      loading: _memberCouponsLoading,
      couponBlockedBySpecialDate: couponBlockedBySpecialDate,
      unavailableReason: unavailableReason,
      couponDiscountAmount: couponDiscountAmount,
      onClear: () {
        setState(() {
          _selectedMemberCoupon = null;
        });
      },
      onPick: _showMemberCouponPicker,
    );
  }

  Future<void> _showMemberCouponPicker() async {
    final MemberCouponModel? result = await showBookingMemberCouponPicker(
      context: context,
      theme: widget.theme,
      coupons: _availableMemberCoupons,
      selectedCoupon: _selectedMemberCoupon,
    );

    if (result == null || !mounted) {
      return;
    }

    final String? unavailableReason = _memberCouponUnavailableReason(result);

    if (unavailableReason != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(unavailableReason)));
      return;
    }

    setState(() {
      _selectedMemberCoupon = result;
    });
  }

  String? _memberCouponUnavailableReason(MemberCouponModel coupon) {
    if (!coupon.canUseNow) {
      return '這張優惠券目前無法使用';
    }

    if (_selectedRoomType == null) {
      return '請先選擇房型';
    }

    final String selectedRoomTypeId =
        (_selectedRoomType!['id'] ?? _selectedRoomType!['roomTypeId'] ?? '')
            .toString()
            .trim();

    if (coupon.roomTypeIds.isNotEmpty &&
        !coupon.roomTypeIds.contains(selectedRoomTypeId)) {
      return '這張優惠券不適用目前選擇的房型';
    }

    final Map<String, dynamic> campaignInfo = _calculateDiscountInfo(
      _currentShopData,
    );

    final bool couponBlockedBySpecialDate =
        (campaignInfo['couponBlockedBySpecialDate'] ?? false) == true;

    if (couponBlockedBySpecialDate) {
      return '目前住宿日期包含不可使用優惠券的特殊日期';
    }

    final int originalTotal = (campaignInfo['originalTotal'] ?? 0).toInt();

    if (coupon.minimumAmount > 0 && originalTotal < coupon.minimumAmount) {
      return '此優惠券最低消費為 NT\$ ${coupon.minimumAmount}';
    }
    final int campaignDiscountAmount = (campaignInfo['discountAmount'] ?? 0)
        .toInt();

    final bool campaignAllowCouponTogether =
        (campaignInfo['allowCouponTogether'] ?? false) == true;

    if (campaignDiscountAmount > 0 && !campaignAllowCouponTogether) {
      return '目前套用的自動優惠活動不可搭配會員優惠券';
    }

    return null;
  }

  Future<FrontCalendarPayload> _buildFrontCalendarPayload({
    required Map<String, dynamic> shop,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return FrontCalendarHelper.buildPayload(
      shopId: widget.shopId,
      shop: shop,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }

  Future<void> _handleCalendarTap({
    required Map<String, dynamic> shop,
    required DateTime date,
  }) async {
    final tapped = _dateOnly(date);

    if (_checkingRange || _submitting) return;

    /// 第一次點 or 重選
    if (_tempStartDate == null ||
        (_tempStartDate != null && _tempEndDate != null)) {
      setState(() {
        _tempStartDate = tapped;
        _tempEndDate = null;
      });

      return;
    }

    /// 第二次點
    if (_tempEndDate == null) {
      /// 點到比開始早 → 重設開始
      if (!tapped.isAfter(_tempStartDate!)) {
        /// 🔥 同一天 → 自動+1天（安全寫法）
        final sameDay =
            tapped.year == _tempStartDate!.year &&
            tapped.month == _tempStartDate!.month &&
            tapped.day == _tempStartDate!.day;

        if (sameDay) {
          final nextDay = _tempStartDate!.add(const Duration(days: 1));
          final payload = await _calendarFuture;

          if (payload != null) {
            final key = ShopService.instance.formatDateKey(nextDay);

            /// ❌ 隔天是關閉日
            if (payload.blockedDateKeys.contains(key)) {
              _showSnackBar('隔天為休息日，請重新選擇');

              setState(() {
                _tempStartDate = null;
                _tempEndDate = null;
              });

              return;
            }

            /// ❌ 隔天滿房
            if (payload.unbookableDateKeys.contains(key)) {
              _showSnackBar('隔天已滿房，請重新選擇');

              setState(() {
                _tempStartDate = null;
                _tempEndDate = null;
              });

              return;
            }
          }

          /// ✅ 正常才走這裡
          setState(() {
            _tempEndDate = nextDay;
            _rangeMessage = ''; // 🔥 清掉錯誤訊息
          });

          return;
        }

        /// 🔥 比開始早 → 重選開始
        setState(() {
          _tempStartDate = tapped;
          _tempEndDate = null;
          _rangeMessage = ''; // 🔥 清掉
        });

        return;
      }

      /// 🔥 檢查區間內是否有不可預約
      final payload = await _calendarFuture;

      if (payload != null) {
        DateTime temp = _tempStartDate!;

        while (!temp.isAfter(tapped.subtract(const Duration(days: 1)))) {
          final key = ShopService.instance.formatDateKey(temp);

          /// ❌ 有關閉日
          if (payload.blockedDateKeys.contains(key)) {
            _showSnackBar('區間包含關閉日期');
            return;
          }

          /// ❌ 房滿
          if (payload.unbookableDateKeys.contains(key)) {
            _showSnackBar('區間包含已滿日期');
            return;
          }

          temp = temp.add(const Duration(days: 1));
        }
      }

      /// 正常設定結束
      setState(() {
        _tempEndDate = tapped;
        _rangeMessage = ''; // 🔥 清掉
      });

      return;
    }
  }

  bool _canSubmit(List<String> serviceTypes) {
    return !_submitting &&
        !_checkingRange &&
        _rangeChecked &&
        _rangeBookable &&
        _startDate != null &&
        _endDate != null &&
        serviceTypes.isNotEmpty;
  }

  /// 🔒 建立目前預約內容的簡易簽章
  ///
  /// 內容相同時沿用原 requestId；
  /// 日期、房型、寵物、服務或資料改變時，改用新的 requestId。
  String _buildBookingRequestSignature({
    required String address,
    required String emergencyName,
    required String emergencyPhone,
    required String relation,
    required String emergencyAddress,
    required String phone2,
    required int depositAmount,
    required String paymentMethod,
    required String payAmountType,
  }) {
    final List<String> sortedPetIds = List<String>.from(_selectedPetIds)
      ..sort();

    final List<String> valueServices = _selectedValueServices.map((
      Map<String, dynamic> item,
    ) {
      return [
        (item['id'] ?? '').toString(),
        (item['name'] ?? '').toString(),
        (item['price'] ?? 0).toString(),
      ].join(':');
    }).toList()..sort();

    final List<String> customServices = _selectedCustomServices.entries.map((
      MapEntry<String, List<String>> entry,
    ) {
      final List<String> petIds = List<String>.from(entry.value)..sort();
      return '${entry.key}:${petIds.join(",")}';
    }).toList()..sort();

    return [
      widget.shopId,
      _startDate?.toIso8601String() ?? '',
      _endDate?.toIso8601String() ?? '',
      (_selectedRoomType?['id'] ??
              _selectedRoomType?['roomTypeId'] ??
              _selectedRoomType?['name'] ??
              '')
          .toString(),
      _selectedServiceType ?? '',
      sortedPetIds.join(','),
      valueServices.join('|'),
      customServices.join('|'),
      _selectedDailyTimedServices.toString(),
      (_selectedTimeAddon?['id'] ?? _selectedTimeAddon?['name'] ?? '')
          .toString(),
      _selectedMemberCoupon?.id ?? '',
      _customerNameController.text.trim(),
      _customerPhoneController.text.trim(),
      _noteController.text.trim(),
      address.trim(),
      emergencyName.trim(),
      emergencyPhone.trim(),
      relation.trim(),
      emergencyAddress.trim(),
      phone2.trim(),
      depositAmount.toString(),
      paymentMethod,
      payAmountType,
    ].join('||');
  }

  Future<void> _submitBooking(
    Map<String, dynamic> shop, {
    String address = '',
    String emergencyName = '',
    String emergencyPhone = '',
    String relation = '',
    String emergencyAddress = '',
    String phone2 = '',
    int depositAmount = 0,
    String paymentMethod = '',
    String payAmountType = '',
    TermsConsentSnapshot? termsConsent,
  }) async {
    /// 🔒 防止卡頓、連點或其他事件重複進入建單流程
    if (_submitting) return;

    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      _showSnackBar('請先選擇入住與退房日期');
      return;
    }

    if (_nights <= 0) {
      _showSnackBar('退房日必須晚於入住日');
      return;
    }

    if (_selectedServiceType == null || _selectedServiceType!.isEmpty) {
      _showSnackBar('請選擇服務類型');
      return;
    }

    if (_selectedRoomType == null) {
      _showSnackBar('請先選擇房型');
      return;
    }

    if (_selectedPetIds.isEmpty) {
      _showSnackBar('請選擇入住寵物');
      return;
    }

    final MemberCouponModel? selectedCoupon = _selectedMemberCoupon;

    if (selectedCoupon != null) {
      final String? couponUnavailableReason = _memberCouponUnavailableReason(
        selectedCoupon,
      );

      if (couponUnavailableReason != null) {
        _showSnackBar(
          '「${selectedCoupon.name}」目前無法使用：$couponUnavailableReason\n'
          '請取消使用、改選其他優惠券，或調整預約條件後再送出。',
        );
        return;
      }
    }

    final bool depositEnabled = shop['depositEnabled'] == true;

    final String resolvedPayAmountType =
        depositEnabled && payAmountType == PaymentAmountType.deposit
        ? PaymentAmountType.deposit
        : PaymentAmountType.full;

    final String currentRequestSignature = _buildBookingRequestSignature(
      address: address,
      emergencyName: emergencyName,
      emergencyPhone: emergencyPhone,
      relation: relation,
      emergencyAddress: emergencyAddress,
      phone2: phone2,
      depositAmount: depositAmount,
      paymentMethod: paymentMethod,
      payAmountType: resolvedPayAmountType,
    );

    setState(() {
      _submitting = true;

      /// 預約內容有改變時，視為新的送出請求
      if (_bookingRequestSignature != currentRequestSignature) {
        _bookingRequestId = FirebaseFirestore.instance
            .collection('bookings')
            .doc()
            .id;

        _bookingRequestSignature = currentRequestSignature;
      }

      /// 同一內容重試時沿用原本 ID
      _bookingRequestId ??= FirebaseFirestore.instance
          .collection('bookings')
          .doc()
          .id;

      _bookingRequestSignature ??= currentRequestSignature;
    });

    String? createdBookingId;

    try {
      final discountInfo = _calculateMemberCouponInfo(shop);

      createdBookingId = await BookingSubmitHelper.submitBooking(
        shopId: widget.shopId,
        customerName: _customerNameController.text,
        customerPhone: _customerPhoneController.text,
        selectedPetIds: _selectedPetIds,
        pets: _pets,
        selectedRoomType: _selectedRoomType!,
        selectedServiceType: _selectedServiceType!,
        startDate: _startDate!,
        endDate: _endDate!,
        nights: _nights,
        note: _noteController.text,
        totalPrice: (discountInfo['finalTotalAfterCoupon'] ?? 0).toInt(),

        originalTotal: discountInfo['originalTotal'] ?? 0,
        specialDateSurchargeAmount:
            (discountInfo['specialDateSurchargeAmount'] ?? 0).toInt(),

        specialDateSurchargeDetails: List<Map<String, dynamic>>.from(
          discountInfo['specialDateSurchargeDetails'] ?? const <dynamic>[],
        ),
        discountAmount: discountInfo['discountAmount'] ?? 0,
        discountUsedNights: discountInfo['discountUsedNights'] ?? 0,
        discountPercent: discountInfo['discountPercent'] ?? 0,
        discountMinNights: discountInfo['discountMinNights'] ?? 0,
        discountBase: (discountInfo['discountBase'] ?? '').toString(),
        discountCampaignId: (discountInfo['discountCampaignId'] ?? '')
            .toString(),

        discountCampaignName: (discountInfo['discountCampaignName'] ?? '')
            .toString(),

        discountCampaignDescription:
            (discountInfo['discountCampaignDescription'] ?? '').toString(),

        discountCampaignType: (discountInfo['discountCampaignType'] ?? '')
            .toString(),

        discountValueType: (discountInfo['discountValueType'] ?? '').toString(),

        discountValue: (discountInfo['discountValue'] ?? 0) as num,

        allowCouponTogether: BookingAddonsHelper.parseBool(
          discountInfo['allowCouponTogether'],
        ),

        couponId: (discountInfo['couponId'] ?? '').toString(),
        couponName: (discountInfo['couponName'] ?? '').toString(),
        couponType: (discountInfo['couponType'] ?? '').toString(),
        couponDiscountAmount: (discountInfo['couponDiscountAmount'] ?? 0)
            .toInt(),

        addons: _buildAddonsData(),
        address: address,
        emergencyName: emergencyName,
        emergencyPhone: emergencyPhone,
        relation: relation,
        emergencyAddress: emergencyAddress,
        phone2: phone2,
        depositAmount: depositAmount,
        paymentMethod: paymentMethod,
        payAmountType: resolvedPayAmountType,

        /// 🔒 同一次送出固定使用同一個訂單文件 ID
        requestId: _bookingRequestId!,
        termsConsent: termsConsent,
      );
      if (!mounted) return;

      /// 💳 判斷是否為綠界線上付款
      /// 功能：信用卡、ATM、超商代碼會建立綠界付款，
      /// 到店付款與銀行轉帳則維持原本預約完成頁。
      final bool isEcpayPayment =
          paymentMethod == 'credit_card' ||
          paymentMethod == 'atm' ||
          paymentMethod == 'cvs_code';

      if (isEcpayPayment) {
        final int finalTotal = (discountInfo['finalTotalAfterCoupon'] ?? 0)
            .toInt();

        final int requestedAmount =
            resolvedPayAmountType == PaymentAmountType.deposit
            ? depositAmount
            : finalTotal;

        /// 🔒 每次付款建立獨立的防重複請求 ID
        final String paymentRequestId = FirebaseFirestore.instance
            .collection('payments')
            .doc()
            .id;

        final paymentResult = await PaymentFunctionService.instance
            .createPayment(
              request: CreatePaymentRequestModel(
                shopId: widget.shopId,
                bookingId: createdBookingId,
                paymentMethod: paymentMethod,
                amountType: resolvedPayAmountType,

                /// 首次預約付款只會是訂金或全額。
                paymentPurpose:
                    resolvedPayAmountType == PaymentAmountType.deposit
                    ? PaymentPurpose.deposit
                    : PaymentPurpose.full,

                amount: requestedAmount,
                requestId: paymentRequestId,
              ),
            );

        if (!mounted) return;

        if (!paymentResult.hasPaymentHtml) {
          throw const PaymentFunctionException(
            code: 'missing-payment-html',
            message: '綠界付款頁資料不完整，請稍後再試。',
          );
        }

        /// 🌐 開啟綠界付款頁
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EcpayPaymentPage(
              paymentHtml: paymentResult.paymentHtml,
              paymentId: paymentResult.paymentId,
              bookingId: createdBookingId!,
            ),
          ),
        );

        return;
      }

      /// 💵 到店付款與銀行轉帳維持原本完成頁
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingSuccessPage(
            shopName: shop['name'] ?? '',
            shopId: widget.shopId,
          ),
        ),
      );
    } catch (e, st) {
      /// 💳 線上付款建立失敗時保留 Booking
      ///
      /// 正式付款架構中，一筆 Booking 可以對應多筆 Payment。
      /// 因此付款建立失敗時不刪除訂單，也不恢復優惠券，
      /// 讓會員之後可以針對同一筆 Booking 重新付款，
      /// 避免產生重複訂單。
      debugPrint('[BookingSubmit] submit failed: $e');
      debugPrint('[BookingSubmit] stack:\n$st');

      if (e is! PaymentFunctionException) {
        _bookingRequestId = null;
        _bookingRequestSignature = null;
      }

      if (!mounted) return;

      final String message = e is PaymentFunctionException
          ? e.message
          : InventoryException.userMessage(e);

      _showSnackBar(message);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showSnackBar(String text) {
    setState(() {
      _rangeMessage = text;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: Colors.red));
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _openCalendarDialog(Map<String, dynamic> shop) async {
    final today = _dateOnly(DateTime.now());
    final maxDays = _toInt(shop['maxAdvanceBookingDays'], fallback: 30);

    _tempStartDate = _startDate;
    _tempEndDate = _endDate;

    // 🔥 當前月份範圍
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDay = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);

    // 🔥 只抓一次
    _calendarFuture = _buildFrontCalendarPayload(
      shop: shop,
      firstDate: firstDay,
      lastDate: lastDay,
    );

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return FutureBuilder<FrontCalendarPayload>(
              future: _calendarFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('日曆載入失敗：${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: Text('沒有資料'));
                }

                final payload = snapshot.data!;

                return BookingCalendarDialog(
                  payload: payload,
                  calendarMonth: _calendarMonth,
                  today: today,
                  maxDays: maxDays,
                  tempStartDate: _tempStartDate,
                  tempEndDate: _tempEndDate,
                  rangeMessage: _rangeMessage,

                  onMonthChanged: (newMonth) {
                    if (!mounted) return;

                    final firstDay = DateTime(newMonth.year, newMonth.month, 1);

                    final lastDay = DateTime(
                      newMonth.year,
                      newMonth.month + 1,
                      0,
                    );

                    setState(() {
                      _calendarMonth = newMonth;

                      _calendarFuture = _buildFrontCalendarPayload(
                        shop: shop,
                        firstDate: firstDay,
                        lastDate: lastDay,
                      );
                    });
                  },

                  onDayTap: (date) async {
                    await _handleCalendarTap(shop: shop, date: date);

                    if (!mounted) return;

                    setInnerState(() {});
                  },

                  onCancel: () {
                    Navigator.pop(context);
                  },

                  onConfirm: () async {
                    setState(() {
                      _startDate = _tempStartDate;
                      _endDate = _tempEndDate;

                      _rangeChecked = true;
                      _rangeBookable = true;
                      _rangeMessage = '';
                    });

                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  DiscountCampaignModel? _findCampaignById(String campaignId) {
    for (final DiscountCampaignModel campaign in _enabledCampaigns) {
      if (campaign.id == campaignId) {
        return campaign;
      }
    }

    return null;
  }

  Widget _buildCurrentCampaignCard(Map<String, dynamic> shop) {
    if (_selectedRoomType == null ||
        _startDate == null ||
        _endDate == null ||
        _campaignsLoading ||
        _firstBookingLoading) {
      return const SizedBox.shrink();
    }

    final Map<String, dynamic> discountInfo = _calculateDiscountInfo(shop);
    final String campaignId = (discountInfo['discountCampaignId'] ?? '')
        .toString()
        .trim();
    final DiscountCampaignModel? campaign = campaignId.isEmpty
        ? null
        : _findCampaignById(campaignId);

    return BookingCurrentCampaignCard(
      theme: widget.theme,
      discountInfo: discountInfo,
      campaign: campaign,
      onShowDetail: (DiscountCampaignModel selected) {
        showBookingCampaignDetailSheet(context: context, campaign: selected);
      },
    );
  }

  Map<String, dynamic> _calculateDiscountInfo(Map<String, dynamic>? shop) {
    final priceParts = BookingSummaryHelper.calculatePriceParts(
      selectedRoomType: _selectedRoomType!,
      nights: _nights,
      selectedPetIds: _selectedPetIds,
      selectedTimeAddon: _selectedTimeAddon,
      selectedValueServices: _selectedValueServices,
      selectedCustomServices: _selectedCustomServices,
      selectedDailyTimedServices: _selectedDailyTimedServices,
      addonData: _addonData,
    );

    final int baseRoomTotal = (priceParts['roomTotal'] ?? 0).toInt();
    final int petTotal = (priceParts['petTotal'] ?? 0).toInt();
    final int baseSubtotal = (priceParts['subtotal'] ?? 0).toInt();

    final int extraServiceTotal = (baseSubtotal - baseRoomTotal - petTotal)
        .clamp(0, baseSubtotal)
        .toInt();

    int specialDateSurchargeAmount = 0;
    List<Map<String, dynamic>> specialDateSurchargeDetails =
        <Map<String, dynamic>>[];

    bool campaignBlockedBySpecialDate = false;
    bool couponBlockedBySpecialDate = false;

    final String roomTypeId =
        (_selectedRoomType?['id'] ?? _selectedRoomType?['roomTypeId'] ?? '')
            .toString()
            .trim();

    if (!_specialDateSurchargesLoading &&
        _startDate != null &&
        _endDate != null &&
        _enabledSpecialDateSurcharges.isNotEmpty) {
      final SpecialDateSurchargeCalculationResult surchargeResult =
          SpecialDateSurchargeCalculator.calculate(
            checkInDate: _startDate!,
            checkOutDate: _endDate!,
            roomTypeId: roomTypeId,
            surcharges: _enabledSpecialDateSurcharges,
          );
      specialDateSurchargeAmount = surchargeResult.totalAmount;
      campaignBlockedBySpecialDate = surchargeResult.nightDetails.any(
        (SpecialDateSurchargeNightDetail detail) => detail.surcharges.any(
          (SpecialDateSurchargeModel surcharge) =>
              !surcharge.allowCampaignDiscount,
        ),
      );
      couponBlockedBySpecialDate = surchargeResult.nightDetails.any(
        (SpecialDateSurchargeNightDetail detail) => detail.surcharges.any(
          (SpecialDateSurchargeModel surcharge) => !surcharge.allowCoupon,
        ),
      );
      specialDateSurchargeDetails = surchargeResult.nightDetails
          .where(
            (SpecialDateSurchargeNightDetail detail) => detail.hasSurcharge,
          )
          .map((SpecialDateSurchargeNightDetail detail) {
            return <String, dynamic>{
              'date': _formatDate(detail.stayDate),
              'amount': detail.amount,
              'items': detail.surcharges.map((
                SpecialDateSurchargeModel surcharge,
              ) {
                return <String, dynamic>{
                  'id': surcharge.id,
                  'name': surcharge.name,
                  'amountPerNight': surcharge.amountPerNight,
                  'allowCampaignDiscount': surcharge.allowCampaignDiscount,
                  'allowCoupon': surcharge.allowCoupon,
                  'roomTypeIds': List<String>.from(surcharge.roomTypeIds),
                };
              }).toList(),
            };
          })
          .toList();
    }

    /// 價格順序：
    /// 原始房價 → 特殊日期加價 → Campaign → 優惠券
    final int roomTotal = baseRoomTotal + specialDateSurchargeAmount;
    final int originalTotal = baseSubtotal + specialDateSurchargeAmount;

    if (!campaignBlockedBySpecialDate &&
        !_campaignsLoading &&
        _enabledCampaigns.isNotEmpty &&
        _startDate != null &&
        _endDate != null &&
        _selectedRoomType != null) {
      final DiscountCampaignCalculationResult? bestCampaign =
          DiscountCampaignCalculator.findBestCampaign(
            campaigns: _enabledCampaigns,
            input: DiscountCampaignCalculationInput(
              checkInDate: _startDate!,
              checkOutDate: _endDate!,
              roomTypeId: roomTypeId,
              roomAmount: roomTotal,
              petAmount: petTotal,
              extraServiceAmount: extraServiceTotal,
              isFirstBooking: !_firstBookingLoading && _isFirstBooking,

              /// 👤 會員加入目前店家的時間
              memberJoinedAt: _memberJoinedAt,

              memberCampaignUsage: _memberCampaignUsage,
              memberCampaignUsedNights: _memberCampaignUsedNights,

              // 尚未建立 Google 評論驗證，因此先固定為 false。
              hasVerifiedGoogleReview: false,
            ),
          );

      if (bestCampaign != null) {
        final DiscountCampaignModel campaign = bestCampaign.campaign;
        final int discountAmount = bestCampaign.discountAmount;
        final int finalTotal = (originalTotal - discountAmount)
            .clamp(0, originalTotal)
            .toInt();

        String discountBase;

        switch (campaign.applyTarget) {
          case DiscountApplyTarget.room:
            discountBase = 'room';

          case DiscountApplyTarget.roomAndPet:
            discountBase = 'room_pet';

          case DiscountApplyTarget.total:
            discountBase = 'total';
        }

        return <String, dynamic>{
          'originalTotal': originalTotal,
          'baseSubtotal': baseSubtotal,
          'baseRoomTotal': baseRoomTotal,
          'petTotal': petTotal,
          'specialDateSurchargeAmount': specialDateSurchargeAmount,
          'specialDateSurchargeDetails': specialDateSurchargeDetails,
          'campaignBlockedBySpecialDate': campaignBlockedBySpecialDate,
          'couponBlockedBySpecialDate': couponBlockedBySpecialDate,
          'discountPercent': campaign.valueType == DiscountValueType.percent
              ? campaign.discountValue.toInt()
              : 0,
          'discountAmount': discountAmount,
          'discountUsedNights': bestCampaign.discountUsedNights,
          'remainingDiscountNights':
              campaign.type == DiscountCampaignType.newMember
              ? (DiscountCampaignCalculator.remainingNewMemberDiscountNights(
                          campaign: campaign,
                          input: DiscountCampaignCalculationInput(
                            checkInDate: _startDate!,
                            checkOutDate: _endDate!,
                            roomTypeId: roomTypeId,
                            roomAmount: roomTotal,
                            petAmount: petTotal,
                            extraServiceAmount: extraServiceTotal,
                            isFirstBooking:
                                !_firstBookingLoading && _isFirstBooking,
                            memberJoinedAt: _memberJoinedAt,
                            memberCampaignUsage: _memberCampaignUsage,
                            memberCampaignUsedNights: _memberCampaignUsedNights,
                            hasVerifiedGoogleReview: false,
                          ),
                        ) -
                        bestCampaign.discountUsedNights)
                    .clamp(0, campaign.newMemberDiscountNights)
                    .toInt()
              : 0,
          'discountMinNights': campaign.minimumNights,
          'discountBase': discountBase,
          'finalTotal': finalTotal,

          // 新優惠額外資料，之後會寫入 booking。
          'discountCampaignId': campaign.id,
          'discountCampaignName': campaign.name,
          'discountCampaignDescription': campaign.description.trim(),
          'discountCampaignType': campaign.type.name,
          'discountValueType': campaign.valueType.name,
          'discountValue': campaign.discountValue,
          'discountApplyTarget': campaign.applyTarget.name,
          'allowCouponTogether': campaign.allowCouponTogether,
        };
      }
    }

    /// 沒有符合新的優惠活動時，不再套用舊版 discountSetting。
    ///
    /// 之後所有自動折扣統一由 DiscountCampaign 系統處理。
    return <String, dynamic>{
      'originalTotal': originalTotal,
      'baseSubtotal': baseSubtotal,
      'baseRoomTotal': baseRoomTotal,
      'petTotal': petTotal,
      'specialDateSurchargeAmount': specialDateSurchargeAmount,
      'specialDateSurchargeDetails': specialDateSurchargeDetails,
      'campaignBlockedBySpecialDate': campaignBlockedBySpecialDate,
      'couponBlockedBySpecialDate': couponBlockedBySpecialDate,
      'discountPercent': 0,
      'discountAmount': 0,
      'discountUsedNights': 0,
      'remainingDiscountNights': 0,
      'discountMinNights': 0,
      'discountBase': '',
      'finalTotal': originalTotal,
      'discountCampaignId': '',
      'discountCampaignName': '',
      'discountCampaignDescription': '',
      'discountCampaignType': '',
      'discountValueType': '',
      'discountValue': 0,
      'discountApplyTarget': '',
      'allowCouponTogether': false,
    };
  }

  Map<String, dynamic> _calculateMemberCouponInfo(Map<String, dynamic>? shop) {
    final Map<String, dynamic> campaignInfo = _calculateDiscountInfo(shop);

    final int campaignFinalTotal = (campaignInfo['finalTotal'] ?? 0).toInt();

    final MemberCouponModel? coupon = _selectedMemberCoupon;

    if (coupon == null || campaignFinalTotal <= 0) {
      return <String, dynamic>{
        ...campaignInfo,
        'couponId': '',
        'couponName': '',
        'couponType': '',
        'couponDiscountAmount': 0,
        'finalTotalAfterCoupon': campaignFinalTotal,
      };
    }

    final String? unavailableReason = _memberCouponUnavailableReason(coupon);

    if (unavailableReason != null) {
      return <String, dynamic>{
        ...campaignInfo,
        'couponId': '',
        'couponName': '',
        'couponType': '',
        'couponDiscountAmount': 0,
        'finalTotalAfterCoupon': campaignFinalTotal,
      };
    }

    final int baseRoomTotal = (campaignInfo['baseRoomTotal'] ?? 0).toInt();

    final int petTotal = (campaignInfo['petTotal'] ?? 0).toInt();

    final int specialDateSurchargeAmount =
        (campaignInfo['specialDateSurchargeAmount'] ?? 0).toInt();

    final int roomDiscountBase = baseRoomTotal + specialDateSurchargeAmount;

    final int roomAndPetDiscountBase = roomDiscountBase + petTotal;

    final int campaignDiscountAmount = (campaignInfo['discountAmount'] ?? 0)
        .toInt();

    final String campaignDiscountBase = (campaignInfo['discountBase'] ?? '')
        .toString();

    int remainingRoomDiscountBase = roomDiscountBase;
    int remainingRoomAndPetDiscountBase = roomAndPetDiscountBase;

    if (campaignDiscountAmount > 0) {
      switch (campaignDiscountBase) {
        case 'room':
          remainingRoomDiscountBase =
              (roomDiscountBase - campaignDiscountAmount).clamp(
                0,
                roomDiscountBase,
              );

          remainingRoomAndPetDiscountBase =
              remainingRoomDiscountBase + petTotal;

        case 'room_pet':
          remainingRoomAndPetDiscountBase =
              (roomAndPetDiscountBase - campaignDiscountAmount).clamp(
                0,
                roomAndPetDiscountBase,
              );

          remainingRoomDiscountBase = remainingRoomAndPetDiscountBase.clamp(
            0,
            roomDiscountBase,
          );

        case 'total':
          // Campaign 是折整單時，無法精準拆回房價占比。
          // 為避免 Coupon 對同一筆金額重複折扣，
          // 這裡最多只能折 Campaign 後剩餘總額。
          remainingRoomDiscountBase = roomDiscountBase.clamp(
            0,
            campaignFinalTotal,
          );

          remainingRoomAndPetDiscountBase = roomAndPetDiscountBase.clamp(
            0,
            campaignFinalTotal,
          );

        default:
          break;
      }
    }

    final int couponDiscountBase;

    switch (coupon.applyTarget) {
      case MemberCouponApplyTarget.room:
        couponDiscountBase = remainingRoomDiscountBase.clamp(
          0,
          campaignFinalTotal,
        );

      case MemberCouponApplyTarget.roomAndPet:
        couponDiscountBase = remainingRoomAndPetDiscountBase.clamp(
          0,
          campaignFinalTotal,
        );

      case MemberCouponApplyTarget.total:
        couponDiscountBase = campaignFinalTotal;

      case MemberCouponApplyTarget.service:
        couponDiscountBase = 0;
    }

    int couponDiscountAmount = 0;

    switch (coupon.type) {
      case MemberCouponType.fixedAmount:
        couponDiscountAmount = coupon.discountValue.toInt().clamp(
          0,
          couponDiscountBase,
        );

      case MemberCouponType.percent:
        couponDiscountAmount = (couponDiscountBase * coupon.discountValue / 100)
            .round()
            .clamp(0, couponDiscountBase);

        if (coupon.maximumDiscountAmount > 0 &&
            couponDiscountAmount > coupon.maximumDiscountAmount) {
          couponDiscountAmount = coupon.maximumDiscountAmount;
        }

        couponDiscountAmount = couponDiscountAmount.clamp(
          0,
          campaignFinalTotal,
        );

      case MemberCouponType.freeStay:
        final Map<String, dynamic> priceParts =
            BookingSummaryHelper.calculatePriceParts(
              selectedRoomType: _selectedRoomType!,
              nights: _nights,
              selectedPetIds: _selectedPetIds,
              selectedTimeAddon: _selectedTimeAddon,
              selectedValueServices: _selectedValueServices,
              selectedCustomServices: _selectedCustomServices,
              selectedDailyTimedServices: _selectedDailyTimedServices,
              addonData: _addonData,
            );

        final int baseRoomTotal = (priceParts['roomTotal'] ?? 0).toInt();

        final int specialDateSurchargeAmount =
            (campaignInfo['specialDateSurchargeAmount'] ?? 0).toInt();

        final int roomTotal = baseRoomTotal + specialDateSurchargeAmount;

        if (_nights > 0 && roomTotal > 0) {
          final int usableFreeNights = coupon.freeStayNights.clamp(0, _nights);

          final double averageRoomPricePerNight = roomTotal / _nights;

          couponDiscountAmount = (averageRoomPricePerNight * usableFreeNights)
              .round()
              .clamp(0, campaignFinalTotal);
        }

      case MemberCouponType.freeService:
        final String couponServiceId = coupon.serviceId.trim();

        if (couponServiceId.isEmpty) {
          couponDiscountAmount = 0;
          break;
        }

        if (coupon.serviceCategory == CouponServiceCategory.value) {
          final Map<String, dynamic> selectedService = _selectedValueServices
              .firstWhere((Map<String, dynamic> item) {
                return (item['id'] ?? '').toString().trim() == couponServiceId;
              }, orElse: () => <String, dynamic>{});

          couponDiscountAmount = ((selectedService['price'] ?? 0) as num)
              .toInt()
              .clamp(0, campaignFinalTotal);
        } else if (coupon.serviceCategory == CouponServiceCategory.custom) {
          final List<Map<String, dynamic>> customServices =
              List<Map<String, dynamic>>.from(
                _addonData?['customServices'] ?? <dynamic>[],
              );

          final Map<String, dynamic> matchedService = customServices.firstWhere(
            (Map<String, dynamic> item) {
              return (item['id'] ?? '').toString().trim() == couponServiceId;
            },
            orElse: () => <String, dynamic>{},
          );

          final String serviceName = (matchedService['name'] ?? '')
              .toString()
              .trim();

          final int servicePrice = ((matchedService['price'] ?? 0) as num)
              .toInt();

          final int selectedPetCount =
              _selectedCustomServices[serviceName]?.length ?? 0;

          couponDiscountAmount = (servicePrice * selectedPetCount).clamp(
            0,
            campaignFinalTotal,
          );
        }
    }

    final int finalTotalAfterCoupon =
        (campaignFinalTotal - couponDiscountAmount).clamp(
          0,
          campaignFinalTotal,
        );

    return <String, dynamic>{
      ...campaignInfo,
      'couponId': coupon.id,
      'couponName': coupon.name,
      'couponType': coupon.type.name,
      'couponDiscountAmount': couponDiscountAmount,
      'finalTotalAfterCoupon': finalTotalAfterCoupon,
    };
  }

  Widget _buildBookingSummary(Map<String, dynamic> shop) {
    final Map<String, dynamic> discountInfo = _calculateMemberCouponInfo(shop);

    final int totalPrice = (discountInfo['finalTotalAfterCoupon'] ?? 0).toInt();

    final MemberCouponModel? selectedCoupon = _selectedMemberCoupon;

    final String? couponUnavailableReason = selectedCoupon == null
        ? null
        : _memberCouponUnavailableReason(selectedCoupon);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookingSummaryHelper.buildSummary(
          theme: widget.theme,
          startDateText: _formatDate(_startDate!),
          endDateText: _formatDate(_endDate!),
          nights: _nights,
          selectedPetIds: _selectedPetIds,
          pets: _pets,
          selectedRoomType: _selectedRoomType!,
          totalPrice: totalPrice,
          originalTotal: discountInfo['originalTotal'],
          discountAmount: discountInfo['discountAmount'] ?? 0,
          discountPercent: discountInfo['discountPercent'] ?? 0,
          discountMinNights: discountInfo['discountMinNights'] ?? 0,
          discountBase: (discountInfo['discountBase'] ?? '').toString(),

          discountCampaignName: (discountInfo['discountCampaignName'] ?? '')
              .toString(),

          discountValueType: (discountInfo['discountValueType'] ?? '')
              .toString(),

          discountValue: (discountInfo['discountValue'] ?? 0) as num,

          discountCampaignType: (discountInfo['discountCampaignType'] ?? '')
              .toString(),

          discountUsedNights: (discountInfo['discountUsedNights'] ?? 0).toInt(),

          remainingDiscountNights:
              (discountInfo['remainingDiscountNights'] ?? 0).toInt(),

          specialDateSurchargeAmount:
              (discountInfo['specialDateSurchargeAmount'] ?? 0).toInt(),

          specialDateSurchargeDetails: List<Map<String, dynamic>>.from(
            discountInfo['specialDateSurchargeDetails'] ?? const <dynamic>[],
          ),

          couponName: (discountInfo['couponName'] ?? '').toString(),
          couponDiscountAmount: (discountInfo['couponDiscountAmount'] ?? 0)
              .toInt(),

          selectedTimeAddon: _selectedTimeAddon,
          selectedValueServices: _selectedValueServices,
          selectedCustomServices: _selectedCustomServices,
          selectedDailyTimedServices: _selectedDailyTimedServices,
          addonData: _addonData,
        ),

        if (selectedCoupon != null && couponUnavailableReason != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade800,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '「${selectedCoupon.name}」目前未套用\n'
                    '$couponUnavailableReason',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> _buildAddonsData() {
    return BookingAddonsHelper.buildAddonsData(
      selectedTimeAddon: _selectedTimeAddon,
      selectedValueServices: _selectedValueServices,
      selectedCustomServices: _selectedCustomServices,
      selectedDailyTimedServices: _selectedDailyTimedServices,
      addonData: _addonData,
      selectedPetIds: _selectedPetIds,
      pets: _pets,
    );
  }
}
