// lib/features/booking/pages/booking_form_page.dart
// 📄 預約資料填寫頁（會員同步完整版🔥）

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _cashEnabled = true;
  bool _transferEnabled = true;

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

  @override
  void initState() {
    super.initState();
    _loadMemberData();
    _loadShopPaymentSettings();
  }

  @override
  void dispose() {
    _detailAddressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
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
    final DocumentSnapshot<Map<String, dynamic>> document =
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .get();

    final Map<String, dynamic>? data = document.data();

    if (data == null || !mounted) {
      return;
    }

    // 💰 訂金設定
    final bool depositEnabled = data['depositEnabled'] == true;
    final String depositType = (data['depositType'] ?? 'fixed').toString();
    final String depositBase = (data['depositBase'] ?? 'room').toString();

    final dynamic rawDepositValue = data['depositValue'];

    final int depositValue = rawDepositValue is int
        ? rawDepositValue
        : rawDepositValue is double
        ? rawDepositValue.toInt()
        : int.tryParse(rawDepositValue?.toString() ?? '') ?? 0;

    // 💳 綠界公開設定
    final dynamic rawPaymentSetting = data['paymentSetting'];

    final Map<String, dynamic> paymentSetting = rawPaymentSetting is Map
        ? Map<String, dynamic>.from(rawPaymentSetting)
        : <String, dynamic>{};

    final String reviewStatus = (paymentSetting['reviewStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final bool platformSuspended = paymentSetting['platformSuspended'] == true;

    final bool shopDisabled = paymentSetting['shopDisabled'] == true;

    // 🏪 店家的實際營運開關
    final dynamic rawOperationSettings = paymentSetting['operationSettings'];

    final Map<String, dynamic> operationSettings = rawOperationSettings is Map
        ? Map<String, dynamic>.from(rawOperationSettings)
        : <String, dynamic>{};

    final bool cashEnabled = operationSettings['cashPaymentEnabled'] ?? true;

    final bool transferEnabled =
        operationSettings['bankTransferEnabled'] ?? true;

    final bool ecpayEnabled = operationSettings['ecpayEnabled'] == true;

    // ✅ 平台核准的綠界付款方式
    final dynamic rawApprovedMethods = paymentSetting['enabledMethods'];

    final Map<String, dynamic> approvedMethods = rawApprovedMethods is Map
        ? Map<String, dynamic>.from(rawApprovedMethods)
        : <String, dynamic>{};

    final bool approvedCreditCard =
        approvedMethods['creditCard'] == true ||
        paymentSetting['creditCardEnabled'] == true;

    final bool approvedAtm =
        approvedMethods['atm'] == true || paymentSetting['atmEnabled'] == true;

    final bool approvedCvsCode =
        approvedMethods['cvsCode'] == true ||
        paymentSetting['cvsCodeEnabled'] == true ||
        paymentSetting['convenienceStoreCodeEnabled'] == true;

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
        operationSettings['creditCardEnabled'] == true;

    final bool atmEnabled =
        canUseEcpay && approvedAtm && operationSettings['atmEnabled'] == true;

    final bool cvsCodeEnabled =
        canUseEcpay &&
        approvedCvsCode &&
        operationSettings['cvsCodeEnabled'] == true;

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

      _cashEnabled = cashEnabled;
      _transferEnabled = transferEnabled;

      _creditCardEnabled = creditCardEnabled;
      _atmEnabled = atmEnabled;
      _cvsCodeEnabled = cvsCodeEnabled;

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
  }

  /// 🔥 會員資料完整帶入（重點）
  Future<void> _loadMemberData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data == null) return;

    if (!mounted) return;

    setState(() {
      /// 👤 基本資料
      widget.customerNameController.text = data['name'] ?? '';
      widget.customerPhoneController.text = data['phone'] ?? '';

      /// 📍 地址（目前先塞詳細地址）
      final address = data['address'] ?? '';

      /// 🔥 嘗試拆縣市 & 區
      for (final city in cityData.keys) {
        if (address.startsWith(city)) {
          _city = city;

          final districts = cityData[city]!;

          for (final d in districts) {
            if (address.contains(d)) {
              _district = d;
              break;
            }
          }

          break;
        }
      }

      /// 剩下當詳細地址
      /// 🔥 去掉縣市 + 區，只留詳細地址
      String detail = address;

      if (_city != null && detail.startsWith(_city!)) {
        detail = detail.substring(_city!.length);
      }

      if (_district != null && detail.startsWith(_district!)) {
        detail = detail.substring(_district!.length);
      }

      _detailAddressController.text = detail;

      /// 🚨 緊急聯絡人
      final emergency = data['emergencyContact'];

      if (emergency != null) {
        _emergencyNameController.text = emergency['name'] ?? '';
        _emergencyPhoneController.text = emergency['phone'] ?? '';
        _emergencyRelation = (emergency['relation'] ?? '').toString().isEmpty
            ? null
            : emergency['relation'].toString();

        _emergencyAddressController.text = emergency['address'] ?? '';
        _phone2Controller.text = emergency['phone2'] ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final depositBasePrice = _depositBase == 'room'
        ? widget.roomPrice
        : widget.totalPrice;

    final rawCalculatedDeposit = _depositEnabled
        ? (_depositRate > 0
              ? (depositBasePrice * _depositRate).round()
              : _depositAmount)
        : 0;

    /// 固定金額也做防呆，不能超過總金額
    final calculatedDeposit = rawCalculatedDeposit > widget.totalPrice
        ? widget.totalPrice
        : rawCalculatedDeposit;

    final remainingAmount = widget.totalPrice - calculatedDeposit;

    final currentPayAmount = _payAmountType == 'full'
        ? widget.totalPrice
        : calculatedDeposit;

    final depositBaseText = _depositBase == 'room' ? '只算房價' : '算總金額';

    return Scaffold(
      appBar: AppBar(title: const Text('填寫預約資料')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: widget.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Email：${user?.email ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: widget.customerNameController,
                decoration: const InputDecoration(
                  labelText: '聯絡人姓名 *',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: widget.customerPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '聯絡電話 *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                '地址 *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: _city,
                hint: const Text('選擇縣市'),
                items: cityData.keys.map<DropdownMenuItem<String>>((city) {
                  return DropdownMenuItem<String>(
                    value: city,
                    child: Text(city),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _city = value;
                    _district = null;
                  });
                },
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: _district,
                hint: const Text('選擇區域'),
                items: (_city == null ? <String>[] : cityData[_city]!)
                    .map<DropdownMenuItem<String>>((d) {
                      return DropdownMenuItem<String>(value: d, child: Text(d));
                    })
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _district = value;
                  });
                },
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _detailAddressController,
                decoration: const InputDecoration(
                  labelText: '詳細地址 *',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                '緊急聯絡人 *',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller: _emergencyNameController,
                decoration: const InputDecoration(
                  labelText: '聯絡人姓名',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _emergencyPhoneController,
                decoration: const InputDecoration(
                  labelText: '聯絡電話',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _emergencyRelation,
                decoration: const InputDecoration(
                  labelText: '與飼主關係',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '父母', child: Text('父母')),
                  DropdownMenuItem(value: '夫妻', child: Text('夫妻')),
                  DropdownMenuItem(value: '配偶', child: Text('配偶')),
                  DropdownMenuItem(value: '兄弟姊妹', child: Text('兄弟姊妹')),
                  DropdownMenuItem(value: '情侶', child: Text('情侶')),
                  DropdownMenuItem(value: '朋友', child: Text('朋友')),
                  DropdownMenuItem(value: '其他', child: Text('其他')),
                ],
                onChanged: (value) {
                  setState(() {
                    _emergencyRelation = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '緊急聯絡人地址 *',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Checkbox(
                    value: _sameAddress,
                    onChanged: (value) {
                      setState(() {
                        _sameAddress = value ?? false;

                        if (_sameAddress) {
                          _emergencyAddressController.text =
                              '${_city ?? ''}${_district ?? ''}${_detailAddressController.text}';
                        }
                      });
                    },
                  ),
                  const Text('同聯絡地址'),
                ],
              ),

              const SizedBox(height: 6),

              TextFormField(
                controller: _emergencyAddressController,
                decoration: const InputDecoration(
                  labelText: '請輸入緊急聯絡人地址',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: widget.noteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '訂單備註',
                  hintText: '例如：貓咪比較怕生、希望安排安靜一點的位置',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              /// 🔥 總金額顯示（新增）
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.discountAmount > 0) ...[
                      Text(
                        '原價：NT\$ ${widget.originalTotal}',
                        style: const TextStyle(
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),

                      const SizedBox(height: 4),

                      if (widget.discountCampaignName.trim().isNotEmpty)
                        Text(
                          '優惠活動：${widget.discountCampaignName}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      const SizedBox(height: 4),

                      Text(
                        '優惠折抵：-NT\$ ${widget.discountAmount}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),
                    ],

                    Text(
                      widget.discountAmount > 0
                          ? '折後總金額：NT\$ ${widget.totalPrice}'
                          : '總金額：NT\$ ${widget.totalPrice}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    /// 🔥 如果有訂金
                    if (_depositEnabled) ...[
                      Text(
                        '需支付訂金：NT\$ $calculatedDeposit',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        '計算方式：$depositBaseText',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),

                      Text(
                        '現場付款：NT\$ $remainingAmount',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],

                    /// 🔥 沒有訂金
                    if (!_depositEnabled)
                      const Text(
                        '付款方式依店家規定',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),

              /// 🔥 付款方式（先做UI）
              const SizedBox(height: 10),

              /// 🚫 所有付款方式都未開放時才顯示提醒
              if (!_cashEnabled &&
                  !_transferEnabled &&
                  !_creditCardEnabled &&
                  !_atmEnabled &&
                  !_cvsCodeEnabled)
                const Text('目前未開放付款方式', style: TextStyle(color: Colors.red)),

              if (_depositEnabled) ...[
                const Text(
                  '付款金額',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                RadioListTile(
                  value: 'deposit',
                  groupValue: _payAmountType,
                  onChanged: (v) {
                    setState(() {
                      _payAmountType = v.toString();
                    });
                  },
                  title: Text('先付訂金 NT\$ $calculatedDeposit'),
                ),

                RadioListTile(
                  value: 'full',
                  groupValue: _payAmountType,
                  onChanged: (v) {
                    setState(() {
                      _payAmountType = v.toString();
                    });
                  },
                  title: Text('一次付清 NT\$ ${widget.totalPrice}'),
                ),

                const SizedBox(height: 12),
              ],

              const Text('付款方式', style: TextStyle(fontWeight: FontWeight.bold)),

              if (_cashEnabled)
                RadioListTile(
                  value: 'cash',
                  groupValue: _paymentMethod,
                  onChanged: (v) {
                    setState(() {
                      _paymentMethod = v as String;
                    });
                  },
                  title: const Text('到店付款'),
                ),

              if (_transferEnabled)
                RadioListTile(
                  value: 'transfer',
                  groupValue: _paymentMethod,
                  onChanged: (v) {
                    setState(() {
                      _paymentMethod = v as String;
                    });
                  },
                  title: const Text('銀行轉帳'),
                ),

              /// 💳 綠界信用卡付款
              /// 功能：店家已通過平台審核並啟用信用卡時顯示。
              if (_creditCardEnabled)
                RadioListTile(
                  value: 'credit_card',
                  groupValue: _paymentMethod,
                  onChanged: (v) {
                    setState(() {
                      _paymentMethod = v as String;
                    });
                  },
                  title: const Text('信用卡'),
                  subtitle: const Text('透過綠界線上付款'),
                ),

              /// 🏧 綠界 ATM 虛擬帳號付款
              /// 功能：付款建立後，由綠界提供 ATM 轉帳帳號。
              if (_atmEnabled)
                RadioListTile(
                  value: 'atm',
                  groupValue: _paymentMethod,
                  onChanged: (v) {
                    setState(() {
                      _paymentMethod = v as String;
                    });
                  },
                  title: const Text('ATM 虛擬帳號'),
                  subtitle: const Text('透過綠界取得轉帳帳號'),
                ),

              /// 🏪 綠界超商代碼付款
              /// 功能：付款建立後，由綠界提供超商繳費代碼。
              if (_cvsCodeEnabled)
                RadioListTile(
                  value: 'cvs_code',
                  groupValue: _paymentMethod,
                  onChanged: (v) {
                    setState(() {
                      _paymentMethod = v as String;
                    });
                  },
                  title: const Text('超商代碼'),
                  subtitle: const Text('透過綠界取得繳費代碼'),
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          if (_isSubmitting) return;

                          /// 🔥 預約前強制完整資料
                          if (widget.customerNameController.text
                                  .trim()
                                  .isEmpty ||
                              widget.customerPhoneController.text
                                  .trim()
                                  .isEmpty ||
                              _city == null ||
                              _district == null ||
                              _detailAddressController.text.trim().isEmpty ||
                              _emergencyNameController.text.trim().isEmpty ||
                              _emergencyPhoneController.text.trim().isEmpty ||
                              (_emergencyRelation ?? '').trim().isEmpty ||
                              _emergencyAddressController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('送出預約前，請完整填寫會員資料')),
                            );

                            return;
                          }

                          if (_paymentMethod == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('請選擇付款方式')),
                            );

                            return;
                          }

                          final fullAddress =
                              '${_city ?? ''}${_district ?? ''}${_detailAddressController.text}';

                          setState(() {
                            _isSubmitting = true;
                          });

                          try {
                            await widget.onSubmitWithData(
                              fullAddress,
                              _emergencyNameController.text,
                              _emergencyPhoneController.text,
                              _emergencyRelation ?? '',
                              _emergencyAddressController.text,
                              _phone2Controller.text,
                              calculatedDeposit,
                              _paymentMethod ?? '',
                              _payAmountType,
                            );
                          } catch (_) {
                            if (mounted) {
                              setState(() {
                                _isSubmitting = false;
                              });
                            }

                            rethrow;
                          }
                        },
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('送出預約'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
