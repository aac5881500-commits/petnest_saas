// 檔案名稱 lib/features/shop/pages/shop_booking_page.dart
//
// 前台預約頁（共用月曆版）
//
// 功能：
// - 第一眼先顯示月曆
// - 顯示每日價格 / 剩餘房數 / 不可預約狀態
// - 先選入住與退房
// - 再填預約資料
// - 送出前再次驗證區間
//
// 規則：
// - 第一次點：入住日
// - 第二次點：退房日
// - 若第二次點的日期 <= 入住日，則重新選入住日
// - 顯示區間晚數 / 總價 / 最少剩餘房數

// 💳 綠界線上付款
import 'package:petnest_saas/core/models/create_payment_request_model.dart';
import 'package:petnest_saas/core/services/payment_function_service.dart';
import 'package:petnest_saas/features/payment/pages/ecpay_payment_page.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
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
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_payload.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_addons_helper.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_calendar_dialog.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_helper.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_submit_helper.dart';
import 'package:petnest_saas/core/models/discount_campaign_model.dart';
import 'package:petnest_saas/core/services/discount_campaign_service.dart';
import 'package:petnest_saas/core/services/discount_campaign_calculator.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/coupon_template_model.dart';

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
  Map<String, int> _memberCampaignUsage = <String, int>{};
  Map<String, int> _memberCampaignUsedNights = <String, int>{};
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

  bool _checkingRange = false;
  bool _isBlacklisted = false;

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;
  String? _selectedServiceType;
  Map<String, dynamic>? _selectedRoomType;
  bool _showAddons = true;
  List<Map<String, dynamic>> _selectedValueServices = [];
  Map<String, List<String>> _selectedCustomServices = {};

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

  List<String> _selectedPetIds = [];
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

    setState(() {
      _customerNameController.text = data['name'] ?? '';
      _customerPhoneController.text = data['phone'] ?? '';
      _isBlacklisted = isShopBlacklisted;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: widget.theme.cardColor,
        foregroundColor: widget.theme.textColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '我要預約',
          style: TextStyle(
            color: widget.theme.textColor,
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

          final bookingEnabled = shop['bookingEnabled'] ?? true;

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

          return SingleChildScrollView(
            key: const PageStorageKey<String>('shop_booking_scroll'),
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BookingDateSection(
                      shopName: shop['name'] ?? '未命名店家',
                      bookingEnabled: bookingEnabled,
                      startDate: _startDate,
                      endDate: _endDate,
                      nights: _nights,
                      onOpenCalendar: () async {
                        await _openCalendarDialog(shop);
                      },
                    ),

                    const SizedBox(height: 16),

                    const SizedBox(height: 16),

                    if (_startDate == null || _endDate == null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: widget.theme.primaryColor.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '預約前提醒',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: widget.theme.textColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '訂房安全提醒',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: widget.theme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '• 本平台僅提供預約系統服務，實際住宿與照護內容由店家負責。',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color.fromRGBO(214, 12, 22, 0.952),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_startDate != null && _endDate != null) ...[
                      const SizedBox(height: 16),

                      BookingPetSection(
                        selectedPetIds: _selectedPetIds,
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
                              _selectedCustomServices[name] = List.from(
                                _selectedPetIds,
                              );
                            }
                          });
                        },

                        onToggleCustomPet: (serviceName, petId, selected) {
                          setState(() {
                            final selectedList =
                                _selectedCustomServices[serviceName] ?? [];

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

                      if (_selectedRoomType != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          '✅ 已選房型：${_selectedRoomType!['name']}',

                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],

                      if (_selectedRoomType != null &&
                          _startDate != null &&
                          _endDate != null) ...[
                        const SizedBox(height: 16),

                        _buildMemberCouponSection(),

                        const SizedBox(height: 16),

                        _buildBookingSummary(shop),
                      ],

                      BookingNextStepSection(
                        selectedPetIds: _selectedPetIds,
                        startDate: _startDate,
                        endDate: _endDate,
                        canShow: _canShowFormFields,
                        canSubmit: _canSubmit(serviceTypes),
                        isBlacklisted: _isBlacklisted,
                        selectedRoomType: _selectedRoomType == null
                            ? null
                            : {
                                ..._selectedRoomType!,
                                'selectedPetCount': _selectedPetIds.length,
                              },
                        nights: _nights,
                        totalPrice: _selectedRoomType == null
                            ? 0
                            : (_calculateMemberCouponInfo(
                                        shop,
                                      )['finalTotalAfterCoupon'] ??
                                      0)
                                  .toInt(),
                        originalTotal: _selectedRoomType == null
                            ? 0
                            : (_calculateDiscountInfo(shop)['originalTotal'] ??
                                      0)
                                  .toInt(),
                        discountAmount: _selectedRoomType == null
                            ? 0
                            : (_calculateDiscountInfo(shop)['discountAmount'] ??
                                      0)
                                  .toInt(),
                        discountCampaignName: _selectedRoomType == null
                            ? ''
                            : (_calculateDiscountInfo(
                                        shop,
                                      )['discountCampaignName'] ??
                                      '')
                                  .toString(),
                        valueServices: _selectedValueServices,
                        formKey: _formKey,
                        shopId: widget.shopId,
                        serviceTypes: serviceTypes,
                        selectedServiceType: _selectedServiceType,
                        customerNameController: _customerNameController,
                        customerPhoneController: _customerPhoneController,
                        noteController: _noteController,
                        isSubmitting: _submitting,
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
                              );
                            },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMemberCouponSection() {
    final MemberCouponModel? selectedCoupon = _selectedMemberCoupon;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.confirmation_number_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '使用優惠券',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                if (selectedCoupon != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedMemberCoupon = null;
                      });
                    },
                    child: const Text('不使用'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_memberCouponsLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_availableMemberCoupons.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '目前沒有可使用的優惠券',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              )
            else
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _showMemberCouponPicker,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selectedCoupon == null
                          ? widget.theme.cardBorderColor
                          : widget.theme.primaryColor,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: selectedCoupon == null
                            ? const Text('點擊選擇優惠券')
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedCoupon.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _memberCouponBenefitText(selectedCoupon),
                                    style: TextStyle(
                                      color: widget.theme.textColor.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),

            if (selectedCoupon != null) ...[
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final Map<String, dynamic> couponInfo =
                      _calculateMemberCouponInfo(_currentShopData);

                  final int couponDiscountAmount =
                      (couponInfo['couponDiscountAmount'] ?? 0).toInt();

                  if (selectedCoupon.type == MemberCouponType.freeService &&
                      couponDiscountAmount <= 0) {
                    return Text(
                      '免費服務券將在下一步比對加購服務後計算',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }

                  return Text(
                    '本次預估折抵：NT\$ $couponDiscountAmount',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ],

            if (selectedCoupon != null &&
                selectedCoupon.description.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                selectedCoupon.description.trim(),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showMemberCouponPicker() async {
    final MemberCouponModel?
    result = await showModalBottomSheet<MemberCouponModel>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(bottomSheetContext).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '選擇優惠券',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(bottomSheetContext);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _availableMemberCoupons.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final MemberCouponModel coupon =
                          _availableMemberCoupons[index];

                      final bool isSelected =
                          coupon.id == _selectedMemberCoupon?.id;

                      return Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: isSelected
                                ? widget.theme.primaryColor
                                : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(bottomSheetContext, coupon);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: widget.theme.primaryColor
                                      .withValues(alpha: 0.12),
                                  child: Icon(
                                    Icons.confirmation_number_outlined,
                                    color: widget.theme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        coupon.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        _memberCouponBenefitText(coupon),
                                        style: TextStyle(
                                          color: widget.theme.textColor
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                      if (coupon.minimumAmount > 0) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '最低消費 NT\$ ${coupon.minimumAmount}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                      ],
                                      if (coupon.expireAt != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '有效期限：${_formatCouponDate(coupon.expireAt!)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

    final int originalTotal = (priceParts['subtotal'] ?? 0).toInt();

    if (coupon.minimumAmount > 0 && originalTotal < coupon.minimumAmount) {
      return '此優惠券最低消費為 NT\$ ${coupon.minimumAmount}';
    }

    final Map<String, dynamic> campaignInfo = _calculateDiscountInfo(
      _currentShopData,
    );
    final int campaignDiscountAmount = (campaignInfo['discountAmount'] ?? 0)
        .toInt();

    final bool campaignAllowCouponTogether =
        (campaignInfo['allowCouponTogether'] ?? false) == true;

    if (campaignDiscountAmount > 0 && !campaignAllowCouponTogether) {
      return '目前套用的自動優惠活動不可搭配會員優惠券';
    }

    return null;
  }

  String _memberCouponBenefitText(MemberCouponModel coupon) {
    switch (coupon.type) {
      case MemberCouponType.fixedAmount:
        return '折抵 NT\$ ${coupon.discountValue.toInt()}';

      case MemberCouponType.percent:
        return '折抵 ${_couponNumberText(coupon.discountValue)}%';

      case MemberCouponType.freeStay:
        return '免費住宿 ${coupon.freeStayNights} 晚';

      case MemberCouponType.freeService:
        if (coupon.serviceName.trim().isEmpty) {
          return '免費指定服務';
        }

        return '免費 ${coupon.serviceName.trim()}';
    }
  }

  String _couponNumberText(num value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  String _formatCouponDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '${date.year}/$month/$day';
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

    final String currentRequestSignature = _buildBookingRequestSignature(
      address: address,
      emergencyName: emergencyName,
      emergencyPhone: emergencyPhone,
      relation: relation,
      emergencyAddress: emergencyAddress,
      phone2: phone2,
      depositAmount: depositAmount,
      paymentMethod: paymentMethod,
      payAmountType: payAmountType,
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
    Map<String, dynamic>? submittedDiscountInfo;

    try {
      final discountInfo = _calculateMemberCouponInfo(shop);
      submittedDiscountInfo = discountInfo;

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
        discountAmount: discountInfo['discountAmount'] ?? 0,
        discountUsedNights: discountInfo['discountUsedNights'] ?? 0,
        discountPercent: discountInfo['discountPercent'] ?? 0,
        discountMinNights: discountInfo['discountMinNights'] ?? 0,
        discountBase: (discountInfo['discountBase'] ?? '').toString(),
        discountCampaignId: (discountInfo['discountCampaignId'] ?? '')
            .toString(),

        discountCampaignName: (discountInfo['discountCampaignName'] ?? '')
            .toString(),

        discountCampaignType: (discountInfo['discountCampaignType'] ?? '')
            .toString(),

        discountValueType: (discountInfo['discountValueType'] ?? '').toString(),

        discountValue: (discountInfo['discountValue'] ?? 0) as num,

        allowCouponTogether:
            (discountInfo['allowCouponTogether'] ?? false) as bool,

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
        payAmountType: payAmountType,

        /// 🔒 同一次送出固定使用同一個訂單文件 ID
        requestId: _bookingRequestId!,
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

        final int requestedAmount = payAmountType == 'deposit'
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
                amountType: payAmountType,
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
            builder: (_) =>
                EcpayPaymentPage(paymentHtml: paymentResult.paymentHtml),
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
    } catch (e) {
      final bool isEcpayPayment =
          paymentMethod == 'credit_card' ||
          paymentMethod == 'atm' ||
          paymentMethod == 'cvs_code';

      if (isEcpayPayment && createdBookingId != null) {
        final String couponId = (submittedDiscountInfo?['couponId'] ?? '')
            .toString()
            .trim();

        try {
          if (couponId.isNotEmpty) {
            await MemberCouponService.instance.restoreCouponForCancelledBooking(
              shopId: widget.shopId,
              couponId: couponId,
              bookingId: createdBookingId,
            );
          }

          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(createdBookingId)
              .delete();

          _bookingRequestId = null;
          _bookingRequestSignature = null;
        } catch (rollbackError) {
          debugPrint('EC_PAY_BOOKING_ROLLBACK_ERROR: $rollbackError');
        }
      }

      if (!mounted) return;

      final String message = e is PaymentFunctionException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');

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

    final roomTotal = priceParts['roomTotal'] ?? 0;
    final petTotal = priceParts['petTotal'] ?? 0;
    final originalTotal = priceParts['subtotal'] ?? 0;

    final int extraServiceTotal = (originalTotal - roomTotal - petTotal)
        .clamp(0, originalTotal)
        .toInt();

    if (!_campaignsLoading &&
        _enabledCampaigns.isNotEmpty &&
        _startDate != null &&
        _endDate != null &&
        _selectedRoomType != null) {
      final String roomTypeId =
          (_selectedRoomType!['id'] ?? _selectedRoomType!['roomTypeId'] ?? '')
              .toString();

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
          'discountCampaignType': campaign.type.name,
          'discountValueType': campaign.valueType.name,
          'discountValue': campaign.discountValue,
          'allowCouponTogether': campaign.allowCouponTogether,
        };
      }
    }

    if (shop == null || _nights <= 0) {
      return {
        'originalTotal': originalTotal,
        'discountPercent': 0,
        'discountAmount': 0,
        'finalTotal': originalTotal,
      };
    }

    final discountSetting = shop['discountSetting'] as Map<String, dynamic>?;

    if (discountSetting == null || discountSetting['enabled'] != true) {
      return {
        'originalTotal': originalTotal,
        'discountPercent': 0,
        'discountAmount': 0,
        'finalTotal': originalTotal,
      };
    }

    final rules = discountSetting['rules'];

    if (rules is! List || rules.isEmpty) {
      return {
        'originalTotal': originalTotal,
        'discountPercent': 0,
        'discountAmount': 0,
        'finalTotal': originalTotal,
      };
    }

    Map<String, dynamic>? matchedRule;

    for (final rule in rules) {
      if (rule is! Map) continue;

      final minNights = ((rule['minNights'] ?? 0) as num).toInt();

      if (_nights >= minNights) {
        if (matchedRule == null ||
            minNights > ((matchedRule['minNights'] ?? 0) as num).toInt()) {
          matchedRule = Map<String, dynamic>.from(rule);
        }
      }
    }

    if (matchedRule == null) {
      return {
        'originalTotal': originalTotal,
        'discountPercent': 0,
        'discountAmount': 0,
        'finalTotal': originalTotal,
      };
    }

    final discountPercent = ((matchedRule['discountPercent'] ?? 0) as num)
        .toInt();

    if (discountPercent <= 0) {
      return {
        'originalTotal': originalTotal,
        'discountPercent': 0,
        'discountAmount': 0,
        'finalTotal': originalTotal,
      };
    }

    final discountBase = (discountSetting['base'] ?? 'total').toString();

    int discountTargetAmount;

    switch (discountBase) {
      case 'room':
        discountTargetAmount = roomTotal;
        break;
      case 'room_pet':
        discountTargetAmount = roomTotal + petTotal;
        break;
      case 'total':
      default:
        discountTargetAmount = originalTotal;
        break;
    }

    final discountAmount = (discountTargetAmount * discountPercent / 100)
        .round();

    return {
      'originalTotal': originalTotal,
      'discountPercent': discountPercent,
      'discountAmount': discountAmount,
      'discountMinNights': ((matchedRule['minNights'] ?? 0) as num).toInt(),
      'discountBase': discountBase,
      'finalTotal': originalTotal - discountAmount,
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

    int couponDiscountAmount = 0;

    switch (coupon.type) {
      case MemberCouponType.fixedAmount:
        couponDiscountAmount = coupon.discountValue.toInt().clamp(
          0,
          campaignFinalTotal,
        );

      case MemberCouponType.percent:
        couponDiscountAmount = (campaignFinalTotal * coupon.discountValue / 100)
            .round()
            .clamp(0, campaignFinalTotal);

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

        final int roomTotal = (priceParts['roomTotal'] ?? 0).toInt();

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

  int _calculateTotalPrice({Map<String, dynamic>? shop}) {
    final discountInfo = _calculateDiscountInfo(shop);

    return discountInfo['finalTotal'] ?? 0;
  }

  Widget _buildBookingSummary(Map<String, dynamic> shop) {
    final Map<String, dynamic> discountInfo = _calculateMemberCouponInfo(shop);

    final int totalPrice = (discountInfo['finalTotalAfterCoupon'] ?? 0).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookingSummaryHelper.buildSummary(
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

          discountUsedNights: (discountInfo['discountUsedNights'] ?? 0) as int,

          remainingDiscountNights:
              (discountInfo['remainingDiscountNights'] ?? 0).toInt(),

          couponName: (discountInfo['couponName'] ?? '').toString(),
          couponDiscountAmount: (discountInfo['couponDiscountAmount'] ?? 0)
              .toInt(),

          selectedTimeAddon: _selectedTimeAddon,
          selectedValueServices: _selectedValueServices,
          selectedCustomServices: _selectedCustomServices,
          selectedDailyTimedServices: _selectedDailyTimedServices,
          addonData: _addonData,
        ),
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
