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

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/features/booking/pages/booking_success_page.dart';
import 'package:petnest_saas/core/widgets/app_drawer.dart';
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

class ShopBookingPage extends StatefulWidget {
  const ShopBookingPage({
    super.key,
    required this.shopId,
    this.preSelectedRoomType,
  });

  final String shopId;
  final Map<String, dynamic>? preSelectedRoomType;

  @override
  State<ShopBookingPage> createState() => _ShopBookingPageState();
}

class _ShopBookingPageState extends State<ShopBookingPage> {
  @override
  void initState() {
    super.initState();
    _loadMemberData();
    _loadAddons();
  }

  final _formKey = GlobalKey<FormState>();

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _noteController = TextEditingController();

  bool _submitting = false;
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

  DateTime _calendarMonth = DateTime.now();
  Future<FrontCalendarPayload>? _calendarFuture;

  @override
  void dispose() {
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
      appBar: AppBar(title: const Text('我要預約')),

      drawer: AppDrawer(shopId: widget.shopId),

      body: StreamBuilder<Map<String, dynamic>?>(
        stream: ShopService.instance.streamShop(widget.shopId),
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
                          color: const Color(0xFFFFF7E8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFD59A)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '預約前提醒',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6B3F00),
                              ),
                            ),

                            SizedBox(height: 10),

                            Text(
                              '訂房安全提醒',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8B5E00),
                              ),
                            ),

                            SizedBox(height: 6),

                            Text(
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

                      // 🔥 加在這裡
                      if (_selectedRoomType != null &&
                          _startDate != null &&
                          _endDate != null) ...[
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
                            : _calculateTotalPrice(shop: shop),
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
                            ) {
                              _submitBooking(
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

    setState(() {
      _submitting = true;
    });

    try {
      final discountInfo = _calculateDiscountInfo(shop);
      await BookingSubmitHelper.submitBooking(
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
        totalPrice: _calculateTotalPrice(shop: shop),

        originalTotal: discountInfo['originalTotal'] ?? 0,
        discountAmount: discountInfo['discountAmount'] ?? 0,
        discountPercent: discountInfo['discountPercent'] ?? 0,
        discountMinNights: discountInfo['discountMinNights'] ?? 0,
        discountBase: (discountInfo['discountBase'] ?? '').toString(),

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
      );

      if (!mounted) return;

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
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
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
      addonData: _addonData,
    );

    final roomTotal = priceParts['roomTotal'] ?? 0;
    final petTotal = priceParts['petTotal'] ?? 0;
    final originalTotal = priceParts['subtotal'] ?? 0;

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

  int _calculateTotalPrice({Map<String, dynamic>? shop}) {
    final discountInfo = _calculateDiscountInfo(shop);

    return discountInfo['finalTotal'] ?? 0;
  }

  Widget _buildBookingSummary(Map<String, dynamic> shop) {
    final discountInfo = _calculateDiscountInfo(shop);
    final totalPrice = discountInfo['finalTotal'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookingSummaryHelper.buildSummary(
          startDateText: _formatDate(_startDate!),
          endDateText: _formatDate(_endDate!),
          nights: _nights,
          selectedPetIds: _selectedPetIds,
          selectedRoomType: _selectedRoomType!,
          totalPrice: totalPrice,
          originalTotal: discountInfo['originalTotal'],
          discountAmount: discountInfo['discountAmount'] ?? 0,
          discountPercent: discountInfo['discountPercent'] ?? 0,
          discountMinNights: discountInfo['discountMinNights'] ?? 0,
          discountBase: (discountInfo['discountBase'] ?? '').toString(),
          selectedTimeAddon: _selectedTimeAddon,
          selectedValueServices: _selectedValueServices,
          selectedCustomServices: _selectedCustomServices,
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
      addonData: _addonData,
      selectedPetIds: _selectedPetIds,
      pets: _pets,
    );
  }
}
