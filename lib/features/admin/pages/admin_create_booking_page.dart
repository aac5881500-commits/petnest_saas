// lib/features/admin/pages/admin_create_booking_page.dart
// 🧾 後台手動新增訂單頁
// 功能：店家可搜尋會員，後續會接快速建立會員、建立寵物與建立訂單

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_calendar_dialog.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_helper.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_payload.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
import 'package:petnest_saas/features/admin/widgets/admin_quick_create_pet_dialog.dart';
import 'package:petnest_saas/features/admin/widgets/admin_quick_create_member_dialog.dart';
import 'package:petnest_saas/features/admin/widgets/admin_create_booking_addon_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_create_booking_confirm_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_member_search_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_selected_member_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_pet_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_date_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_room_type_section.dart';
import 'package:petnest_saas/core/services/shop_plan_service.dart';
import 'package:petnest_saas/core/services/shop_permission_service.dart';

class AdminCreateBookingPage extends StatefulWidget {
  const AdminCreateBookingPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<AdminCreateBookingPage> createState() => _AdminCreateBookingPageState();
}

class _AdminCreateBookingPageState extends State<AdminCreateBookingPage> {
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _keyword = '';
  Map<String, dynamic>? _selectedMember;
  int _step = 0;
  final Set<String> _selectedPetIds = <String>{};
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;

  DateTime _calendarMonth = DateTime.now();
  Future<FrontCalendarPayload>? _calendarFuture;

  String _rangeMessage = '';
  String _adminOrderSource = '電話預約';
  Map<String, dynamic>? _selectedRoomType;
  bool _applyLongStayDiscount = true;
  bool _addonLoading = true;
  Map<String, dynamic>? _addonData;

  Map<String, dynamic>? _selectedTimeAddon;
  List<Map<String, dynamic>> _selectedValueServices = [];
  final Set<String> _selectedAddonNames = <String>{};
  Map<String, List<String>> _selectedCustomServices = {};
  List<Map<String, dynamic>> _pets = [];

  @override
  void initState() {
    super.initState();
    _loadAddons();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAddons() async {
    final doc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('addons')
        .doc('main')
        .get();

    final data = doc.data();

    setState(() {
      _addonData = data;
      _addonLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF7),
      appBar: AppBar(
        title: const Text('手動新增訂單'),
        backgroundColor: const Color(0xFFFFFCF7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '第一步：選擇會員',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 8),

          const Text(
            '可輸入姓名或電話搜尋會員。沒有會員時，下一步會加入快速建立會員。',
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _keywordController,
            decoration: InputDecoration(
              hintText: '搜尋會員姓名 / 電話',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _keyword.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () async {
                        setState(() {
                          _keywordController.clear();
                          _keyword = '';
                          _selectedMember = null;
                          _selectedPetIds.clear();
                          _step = 0;
                        });
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _keyword = value.trim();
              });
            },
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _quickCreateMember,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('沒有會員？快速建立會員'),
            ),
          ),

          const SizedBox(height: 16),

          if (_selectedMember != null) _selectedMemberCard(),
          const SizedBox(height: 16),

          if (_step == 0) _memberSearchResult(),

          if (_step == 1) _petSection(),
          if (_step == 2) _dateSection(),
          if (_step == 3) _roomTypeSection(),
          if (_step == 4) _addonSection(),
          if (_step == 5) _confirmSection(),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedMember == null
                  ? null
                  : () {
                      if (_step == 0) {
                        setState(() {
                          _step = 1;
                        });
                        return;
                      }

                      if (_step == 1) {
                        if (_selectedPetIds.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請至少選擇一隻寵物')),
                          );
                          return;
                        }

                        setState(() {
                          _step = 2;
                          _selectedRoomType = null;
                        });
                        return;
                      }

                      if (_step == 2) {
                        if (_startDate == null || _endDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請先選擇日期')),
                          );
                          return;
                        }

                        setState(() {
                          _step = 3;
                        });
                        return;
                      }

                      if (_step == 3) {
                        if (_selectedRoomType == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請先選擇房型')),
                          );
                          return;
                        }

                        setState(() {
                          _step = 4;
                        });

                        return;
                      }

                      if (_step == 4) {
                        setState(() {
                          _step = 5;
                        });

                        return;
                      }
                      if (_step == 5) {
                        _submitBooking();
                        return;
                      }
                    },
              child: const Text('下一步'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedMemberCard() {
    final member = _selectedMember;

    if (member == null) {
      return const SizedBox();
    }

    return AdminSelectedMemberCard(member: member);
  }

  Future<void> _quickCreateMember() async {
    final shopDoc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .get();

    final shop = shopDoc.data() as Map<String, dynamic>? ?? {};

    if (!ShopPermissionService.canCreateMember(shop)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ShopPermissionService.restrictedMessage())),
      );

      return;
    }
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AdminQuickCreateMemberDialog(defaultPhone: _keyword),
    );

    if (result == null) return;

    final phone = result['phone'] ?? '';

    final exists = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('members')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (exists.docs.isNotEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此手機號碼已存在會員')));

      return;
    }

    if (!mounted) return;

    setState(() {
      _selectedMember = {
        'userId': FirebaseFirestore.instance
            .collection('user_profiles')
            .doc()
            .id,
        'isTempAdminMember': true,
        'name': result['name'],
        'phone': result['phone'],
        'email': '',
        'address': result['address'],
        'emergencyContact': {
          'name': result['emergencyName'],
          'phone': result['emergencyPhone'],
          'relation': result['emergencyRelation'],
          'address': result['emergencyAddress'],
        },
      };

      _keywordController.text = result['phone'] ?? '';
      _keyword = result['phone'] ?? '';
    });

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已暫存會員，送出訂單後才會正式建立')));
  }

  Widget _memberSearchResult() {
    return AdminMemberSearchSection(
      shopId: widget.shopId,
      keyword: _keyword,
      onSelectMember: (userId, data) {
        setState(() {
          _selectedMember = {'userId': userId, ...data};

          _selectedPetIds.clear();
          _pets.clear();
          _step = 0;
        });
      },
    );
  }

  Future<void> _quickCreatePet() async {
    final member = _selectedMember;
    if (member == null) return;

    final userId = member['userId']?.toString() ?? '';
    if (userId.isEmpty) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const AdminQuickCreatePetDialog(),
    );

    if (result == null) return;

    final petId = FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(userId)
        .collection('pets')
        .doc()
        .id;

    if (member['isTempAdminMember'] != true) {
      await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(userId)
          .collection('pets')
          .doc(petId)
          .set({
            'name': result['name'],
            'type': result['type'],
            'breed': result['breed'],
            'gender': result['gender'],
            'age': result['age'],
            'isNeutered': result['isNeutered'],
            'vaccine': result['vaccine'],
            'litterType': result['litterType'],
            'note': result['note'],
            'shopId': widget.shopId,
            'createdFrom': 'admin',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    }

    if (!mounted) return;

    setState(() {
      _selectedPetIds.add(petId);
      _pets.add({
        'petId': petId,
        'name': result['name'],
        'type': result['type'],
        'breed': result['breed'],
        'gender': result['gender'],
        'age': result['age'],
        'isNeutered': result['isNeutered'],
        'vaccine': result['vaccine'],
        'litterType': result['litterType'],
        'note': result['note'],
      });
    });

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已建立寵物')));
  }

  Widget _petSection() {
    return AdminPetSection(
      shopId: widget.shopId,
      member: _selectedMember,
      selectedPetIds: _selectedPetIds,
      tempPets: _pets,
      onCreatePet: _quickCreatePet,
      onTogglePet: ({required petId, required petData, required selected}) {
        setState(() {
          if (selected) {
            _selectedPetIds.add(petId);

            final exists = _pets.any((p) => p['petId'] == petId);

            if (!exists) {
              _pets.add({'petId': petId, ...petData});
            }
          } else {
            _selectedPetIds.remove(petId);
            _pets.removeWhere((p) => p['petId'] == petId);
          }
        });
      },
    );
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
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

  Future<void> _openCalendarDialog(Map<String, dynamic> shop) async {
    final today = _dateOnly(DateTime.now());

    _tempStartDate = _startDate;
    _tempEndDate = _endDate;

    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDay = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);

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
                  maxDays: 365,
                  tempStartDate: _tempStartDate,
                  tempEndDate: _tempEndDate,
                  rangeMessage: _rangeMessage,
                  onMonthChanged: (newMonth) {
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

                    setInnerState(() {});
                  },
                  onDayTap: (date) async {
                    _handleCalendarTap(date);
                    setInnerState(() {});
                  },
                  onCancel: () {
                    Navigator.pop(context);
                  },
                  onConfirm: () {
                    if (_tempStartDate == null || _tempEndDate == null) {
                      setState(() {
                        _rangeMessage = '請選擇入住日與退房日';
                      });
                      setInnerState(() {});
                      return;
                    }

                    setState(() {
                      _startDate = _tempStartDate;
                      _endDate = _tempEndDate;
                      _rangeMessage = '';
                    });

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

  void _handleCalendarTap(DateTime date) {
    final tapped = _dateOnly(date);

    if (_tempStartDate == null ||
        (_tempStartDate != null && _tempEndDate != null)) {
      setState(() {
        _tempStartDate = tapped;
        _tempEndDate = null;
        _rangeMessage = '';
      });
      return;
    }

    if (!tapped.isAfter(_tempStartDate!)) {
      setState(() {
        _tempStartDate = tapped;
        _tempEndDate = null;
        _rangeMessage = '';
      });
      return;
    }

    setState(() {
      _tempEndDate = tapped;
      _rangeMessage = '';
    });
  }

  Widget _dateSection() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(widget.shopId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final shop = snapshot.data;
        if (shop == null) {
          return const Text('找不到店家資料');
        }

        return AdminBookingDateSection(
          startDate: _startDate,
          endDate: _endDate,
          formatDate: _formatDate,
          onOpenCalendar: () {
            _openCalendarDialog(shop);
          },
        );
      },
    );
  }

  Widget _roomTypeSection() {
    return AdminBookingRoomTypeSection(
      shopId: widget.shopId,
      startDate: _startDate,
      endDate: _endDate,
      selectedPetIds: _selectedPetIds.toList(),
      selectedRoomType: _selectedRoomType,
      onSelectRoomType: (roomType) {
        setState(() {
          _selectedRoomType = roomType;
        });
      },
    );
  }

  Widget _addonSection() {
    return AdminCreateBookingAddonSection(
      addonLoading: _addonLoading,
      addonData: _addonData,
      pets: _pets,
      selectedTimeAddon: _selectedTimeAddon,
      selectedAddonNames: _selectedAddonNames,
      selectedCustomServices: _selectedCustomServices,
      onSelectTimeAddon: (item) {
        final label = item['label']?.toString() ?? '';
        final price = item['price'] ?? 0;

        setState(() {
          _selectedTimeAddon = {
            ...item,
            'name': label,
            'type': 'time',
            'count': 1,
            'total': price,
          };
        });
      },
      onToggleValueService: (item, selected) {
        final name = item['name']?.toString() ?? '';
        final price = item['price'] ?? 0;

        setState(() {
          if (selected) {
            _selectedAddonNames.add(name);
            _selectedValueServices.add({
              ...item,
              'type': 'value',
              'count': 1,
              'total': price,
            });
          } else {
            _selectedAddonNames.remove(name);
            _selectedValueServices.removeWhere((e) => e['name'] == name);
          }
        });
      },
      onToggleCustomPet:
          ({required serviceName, required petId, required selected}) {
            setState(() {
              _selectedCustomServices.putIfAbsent(serviceName, () => []);

              if (selected) {
                if (!_selectedCustomServices[serviceName]!.contains(petId)) {
                  _selectedCustomServices[serviceName]!.add(petId);
                }
              } else {
                _selectedCustomServices[serviceName]!.remove(petId);
              }
            });
          },
    );
  }

  List<Map<String, dynamic>> _buildAdminAddons() {
    final addons = <Map<String, dynamic>>[];

    if (_selectedTimeAddon != null) {
      addons.add({..._selectedTimeAddon!});
    }

    addons.addAll(
      _selectedValueServices.map((item) {
        final price = item['price'] ?? 0;

        return {
          'name': item['name'],
          'type': 'value',
          'price': price,
          'count': 1,
          'total': item['total'] ?? price,
        };
      }),
    );

    _selectedCustomServices.forEach((serviceName, petIds) {
      if (petIds.isEmpty) return;

      final service = List<Map<String, dynamic>>.from(
        _addonData?['customServices'] ?? [],
      ).firstWhere((item) => item['name'] == serviceName, orElse: () => {});

      final price = service['price'] ?? 0;

      addons.add({
        'name': serviceName,
        'type': 'custom',
        'price': price,
        'count': petIds.length,
        'total': price * petIds.length,
        'petNames': petIds.map((petId) {
          final pet = _pets.firstWhere(
            (p) => p['petId'] == petId,
            orElse: () => {},
          );

          return pet['name'] ?? petId;
        }).toList(),
      });
    });

    return addons;
  }

  Map<String, dynamic> _calculateAdminDiscountInfo({
    required Map<String, dynamic> shop,
    required Map<String, dynamic> roomType,
    required int nights,
  }) {
    final basePrice = (roomType['price'] ?? 0) as int;

    final extraPetPrice = (roomType['extraPrice'] ?? 0) as int;
    final extraPetCount = _selectedPetIds.length > 1
        ? _selectedPetIds.length - 1
        : 0;

    final roomTotal = basePrice * nights;
    final petTotal = extraPetPrice * extraPetCount * nights;

    final timeTotal = (_selectedTimeAddon?['total'] ?? 0) as int;

    final valueTotal = _selectedValueServices.fold<int>(
      0,
      (sum, item) => sum + ((item['total'] ?? 0) as int),
    );

    final customTotal = _selectedCustomServices.entries.fold<int>(0, (
      sum,
      entry,
    ) {
      final service = List<Map<String, dynamic>>.from(
        _addonData?['customServices'] ?? [],
      ).firstWhere((item) => item['name'] == entry.key, orElse: () => {});

      final price = (service['price'] ?? 0) as int;
      return sum + (price * entry.value.length);
    });

    final originalTotal =
        roomTotal + petTotal + timeTotal + valueTotal + customTotal;

    if (!_applyLongStayDiscount || nights <= 0) {
      return {
        'originalTotal': originalTotal,
        'discountAmount': 0,
        'discountPercent': 0,
        'discountMinNights': 0,
        'discountBase': '',
        'finalTotal': originalTotal,
      };
    }

    final discountSetting = shop['discountSetting'] as Map<String, dynamic>?;

    if (discountSetting == null || discountSetting['enabled'] != true) {
      return {
        'originalTotal': originalTotal,
        'discountAmount': 0,
        'discountPercent': 0,
        'discountMinNights': 0,
        'discountBase': '',
        'finalTotal': originalTotal,
      };
    }

    final rules = discountSetting['rules'];

    if (rules is! List || rules.isEmpty) {
      return {
        'originalTotal': originalTotal,
        'discountAmount': 0,
        'discountPercent': 0,
        'discountMinNights': 0,
        'discountBase': '',
        'finalTotal': originalTotal,
      };
    }

    Map<String, dynamic>? matchedRule;

    for (final rule in rules) {
      if (rule is! Map) continue;

      final minNights = ((rule['minNights'] ?? 0) as num).toInt();

      if (nights >= minNights) {
        if (matchedRule == null ||
            minNights > ((matchedRule['minNights'] ?? 0) as num).toInt()) {
          matchedRule = Map<String, dynamic>.from(rule);
        }
      }
    }

    if (matchedRule == null) {
      return {
        'originalTotal': originalTotal,
        'discountAmount': 0,
        'discountPercent': 0,
        'discountMinNights': 0,
        'discountBase': '',
        'finalTotal': originalTotal,
      };
    }

    final discountPercent = ((matchedRule['discountPercent'] ?? 0) as num)
        .toInt();

    if (discountPercent <= 0) {
      return {
        'originalTotal': originalTotal,
        'discountAmount': 0,
        'discountPercent': 0,
        'discountMinNights': 0,
        'discountBase': '',
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
      'discountAmount': discountAmount,
      'discountPercent': discountPercent,
      'discountMinNights': ((matchedRule['minNights'] ?? 0) as num).toInt(),
      'discountBase': discountBase,
      'finalTotal': originalTotal - discountAmount,
    };
  }

  int _calculateAdminTotalPrice({
    required Map<String, dynamic> roomType,
    required int nights,
  }) {
    final basePrice = (roomType['price'] ?? 0) as int;

    final extraPetPrice = (roomType['extraPrice'] ?? 0) as int;
    final extraPetCount = _selectedPetIds.length > 1
        ? _selectedPetIds.length - 1
        : 0;
    final extraPetTotal = extraPetPrice * extraPetCount * nights;

    final timeTotal = (_selectedTimeAddon?['total'] ?? 0) as int;

    final valueTotal = _selectedValueServices.fold<int>(
      0,
      (sum, item) => sum + ((item['total'] ?? 0) as int),
    );

    final customTotal = _selectedCustomServices.entries.fold<int>(0, (
      sum,
      entry,
    ) {
      final service = List<Map<String, dynamic>>.from(
        _addonData?['customServices'] ?? [],
      ).firstWhere((item) => item['name'] == entry.key, orElse: () => {});

      final price = (service['price'] ?? 0) as int;
      return sum + (price * entry.value.length);
    });

    return (basePrice * nights) +
        extraPetTotal +
        timeTotal +
        valueTotal +
        customTotal;
  }

  Future<void> _submitBooking() async {
    final member = _selectedMember;
    final roomType = _selectedRoomType;
    final shopDoc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .get();

    final shop = shopDoc.data() as Map<String, dynamic>? ?? {};
    if (!ShopPermissionService.canCreateOrder(shop)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ShopPermissionService.restrictedMessage())),
      );

      return;
    }

    final dailyLimit = ShopPlanService.manualBookingDailyLimit(shop);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final todayAdminBookings = await FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: widget.shopId)
        .where('source', isEqualTo: 'admin')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
        )
        .where('createdAt', isLessThan: Timestamp.fromDate(tomorrowStart))
        .get();

    if (todayAdminBookings.docs.length >= dailyLimit) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('免費版每日最多手動新增 $dailyLimit 筆訂單，升級方案即可解除限制')),
      );
      return;
    }

    if (member == null ||
        roomType == null ||
        _startDate == null ||
        _endDate == null) {
      return;
    }

    try {
      String finalUserId = member['userId'] ?? '';

      if (member['isTempAdminMember'] == true) {
        final memberRef = FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(finalUserId);

        final batch = FirebaseFirestore.instance.batch();
        batch.set(memberRef, {
          'name': member['name'],
          'phone': member['phone'],
          'email': '',
          'address': member['address'],
          'emergencyContact': member['emergencyContact'],
          'shopIds': [widget.shopId],
          'createdFrom': 'admin',
          'source': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final shopMemberRef = FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('members')
            .doc(finalUserId);

        batch.set(shopMemberRef, {
          'userId': finalUserId,
          'name': member['name'] ?? '',
          'phone': member['phone'] ?? '',
          'email': member['email'] ?? '',
          'address': member['address'] ?? '',
          'emergencyContact': member['emergencyContact'] ?? {},
          'createdFrom': 'admin',
          'source': 'admin',
          'shopId': widget.shopId,
          'petCount': _pets.length,
          'bookingCount': 0,
          'tags': <String>[],
          'blacklisted': false,
          'blacklistReason': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        for (final pet in _pets) {
          final petId = pet['petId']?.toString() ?? '';

          if (petId.isEmpty) continue;

          final petData = {
            'petId': petId,
            'name': pet['name'] ?? '',
            'type': pet['type'] ?? '',
            'breed': pet['breed'] ?? '',
            'gender': pet['gender'] ?? '',
            'age': pet['age'] ?? '',
            'isNeutered': pet['isNeutered'] ?? false,
            'vaccine': pet['vaccine'] ?? '',
            'litterType': pet['litterType'] ?? '',
            'note': pet['note'] ?? '',
            'shopId': widget.shopId,
            'createdFrom': 'admin',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          final petRef = memberRef.collection('pets').doc(petId);
          batch.set(petRef, petData);

          final memberPetRef = shopMemberRef.collection('pets').doc(petId);
          batch.set(memberPetRef, petData);
        }

        await batch.commit();
      }
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('members')
          .doc(finalUserId)
          .set({
            'userId': finalUserId,
            'name': member['name'] ?? '',
            'phone': member['phone'] ?? '',
            'email': member['email'] ?? '',
            'address': member['address'] ?? '',
            'emergencyContact': member['emergencyContact'] ?? {},
            'createdFrom': member['createdFrom'] ?? 'admin',
            'shopId': widget.shopId,
            'petCount': _selectedPetIds.length,
            'tags': <String>[],
            'blacklisted': false,
            'blacklistReason': '',
            'updatedAt': FieldValue.serverTimestamp(),
            'lastBookingAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      final nights = _endDate!.difference(_startDate!).inDays;

      final discountInfo = _calculateAdminDiscountInfo(
        shop: shop,
        roomType: roomType,
        nights: nights,
      );

      await BookingService.instance.createAdminBooking(
        shopId: widget.shopId,
        userId: finalUserId,
        customerName: member['name'] ?? '',
        customerPhone: member['phone'] ?? '',
        address: member['address'] ?? '',
        emergencyName: member['emergencyContact']?['name'] ?? '',
        emergencyPhone: member['emergencyContact']?['phone'] ?? '',
        emergencyRelation: member['emergencyContact']?['relation'] ?? '',
        emergencyAddress: member['emergencyContact']?['address'] ?? '',
        emergencyPhone2: member['emergencyContact']?['phone2'] ?? '',
        petIds: _selectedPetIds.toList(),

        serviceType: '住宿',

        startDate: _startDate!,
        endDate: _endDate!,
        nights: nights,

        roomId: roomType['roomTypeId'] ?? roomType['id'] ?? '',
        roomName: roomType['name'] ?? '',
        roomTypeName: roomType['name'] ?? '',

        basePrice: (roomType['price'] ?? 0) as int,
        extraPetPrice: (roomType['extraPrice'] ?? 0) as int,
        extraPetCount: _selectedPetIds.length > 1
            ? _selectedPetIds.length - 1
            : 0,
        extraPetTotal:
            ((roomType['extraPrice'] ?? 0) as int) *
            (_selectedPetIds.length > 1 ? _selectedPetIds.length - 1 : 0) *
            nights,
        roomSubtotal: (roomType['price'] ?? 0) * nights,

        roomImages: roomType['images'] ?? [],

        totalPrice: (discountInfo['finalTotal'] ?? 0) as int,
        originalTotal: (discountInfo['originalTotal'] ?? 0) as int,
        applyLongStayDiscount: _applyLongStayDiscount,
        discountAmount: (discountInfo['discountAmount'] ?? 0) as int,
        discountPercent: (discountInfo['discountPercent'] ?? 0) as int,
        discountMinNights: (discountInfo['discountMinNights'] ?? 0) as int,
        discountBase: (discountInfo['discountBase'] ?? '').toString(),
        pets: _pets,
        addons: _buildAdminAddons(),
        note:
            '手動新增訂單｜$_adminOrderSource'
            '${_noteController.text.trim().isEmpty ? '' : '｜${_noteController.text.trim()}'}',
      );

      final bookingCountSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('shopId', isEqualTo: widget.shopId)
          .where('userId', isEqualTo: finalUserId)
          .get();

      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('members')
          .doc(finalUserId)
          .set({
            'bookingCount': bookingCountSnap.docs.length,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('訂單建立成功')));

      Navigator.pop(context);
    } catch (e, stackTrace) {
      debugPrint('====================');
      debugPrint('建立訂單失敗');
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());
      debugPrint('====================');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('建立失敗：$e')));
    }
  }

  Widget _confirmSection() {
    final nights = _startDate != null && _endDate != null
        ? _endDate!.difference(_startDate!).inDays
        : 0;

    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(widget.shopId),
      builder: (context, snapshot) {
        final shop = snapshot.data ?? {};

        final discountInfo = _selectedRoomType != null && nights > 0
            ? _calculateAdminDiscountInfo(
                shop: shop,
                roomType: _selectedRoomType!,
                nights: nights,
              )
            : null;

        return AdminCreateBookingConfirmSection(
          member: _selectedMember,
          roomType: _selectedRoomType,
          startDate: _startDate,
          endDate: _endDate,
          selectedPetIds: _selectedPetIds,
          selectedTimeAddon: _selectedTimeAddon,
          selectedValueServices: _selectedValueServices,
          selectedCustomServices: _selectedCustomServices,
          addonData: _addonData,
          adminOrderSource: _adminOrderSource,
          applyLongStayDiscount: _applyLongStayDiscount,
          onApplyLongStayDiscountChanged: (value) {
            setState(() {
              _applyLongStayDiscount = value;
            });
          },
          discountInfo: discountInfo,
          noteController: _noteController,
          formatDate: _formatDate,
          onOrderSourceChanged: (value) {
            setState(() {
              _adminOrderSource = value;
            });
          },
        );
      },
    );
  }
}
