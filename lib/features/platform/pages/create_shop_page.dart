// 檔案名稱：lib/features/platform/pages/create_shop_page.dart
// 功能說明：平台建立店家頁

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/shop_commercial_service.dart';
import 'package:petnest_saas/features/platform/pages/platform_shop_owner_policy_page.dart';
import 'package:petnest_saas/core/services/platform_policy_manage_service.dart';
import 'package:petnest_saas/features/platform/widgets/create_shop_opening_view.dart';

enum ShopCreateExit { created, recheckActivation }

class CreateShopPage extends StatefulWidget {
  const CreateShopPage({super.key, required this.activationCode});

  final String activationCode;

  @override
  State<CreateShopPage> createState() => _CreateShopPageState();
}

class _CreateShopPageState extends State<CreateShopPage> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();

  bool _loading = false;
  bool _awaitingPolicy = false;
  String? _createRequestId;

  final Map<String, List<String>> taiwanMap = {
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
      '三重區',
      '中和區',
      '永和區',
      '新莊區',
      '新店區',
      '土城區',
      '蘆洲區',
      '樹林區',
      '汐止區',
      '鶯歌區',
      '三峽區',
      '淡水區',
      '瑞芳區',
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
      '楊梅區',
      '蘆竹區',
      '大溪區',
      '龍潭區',
      '龜山區',
      '大園區',
      '觀音區',
      '新屋區',
      '復興區',
    ],
    '新竹市': ['東區', '北區', '香山區'],
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
      '和平區',
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
    '嘉義市': ['東區', '西區'],
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
      '東沙群島',
      '南沙群島',
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
  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        content: Text(message),
      ),
    );
  }

  Future<void> _createShop() async {
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();
    final district = _districtController.text.trim();

    final activationCode = widget.activationCode.trim();

    if (name.isEmpty) {
      _showMessage('請輸入店名');
      return;
    }

    if (city.isEmpty) {
      _showMessage('請選擇城市');
      return;
    }

    if (district.isEmpty) {
      _showMessage('請選擇區域');
      return;
    }
    if (activationCode.isEmpty) {
      if (!mounted) return;
      Navigator.pop(context, ShopCreateExit.recheckActivation);
      return;
    }

    try {
      setState(() {
        _loading = true;
      });

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final policy = await PlatformPolicyManageService.instance.getPolicy(
        PlatformShopOwnerPolicyPage.policyKey,
      );

      final currentPolicyVersion = policy?['version'] is int
          ? policy!['version']
          : 1;

      _createRequestId ??= 'shop${DateTime.now().microsecondsSinceEpoch}';
      final shopId = await ShopCommercialService.instance.createShop(
        name: name,
        city: city,
        district: district,
        acceptedShopOwnerPolicyVersion: currentPolicyVersion,
        activationCode: activationCode,
        requestId: _createRequestId!,
      );
      _createRequestId = null;
      if (!mounted) return;
      if (shopId.isEmpty) {
        throw Exception('沒有取得店家編號');
      }

      if (!mounted) return;

      Navigator.pop(context, ShopCreateExit.created);
    } catch (error, stackTrace) {
      debugPrint('建立店家失敗: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      final String message = _createFailureMessage(error);
      if (message.contains('激活碼')) {
        await _askToRecheckActivation(message);
      } else {
        _showMessage(message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _createFailureMessage(Object error) {
    if (error is ShopCommercialException) return error.message;
    final String text = error.toString();
    const String prefix = 'Exception: ';
    if (text.startsWith(prefix)) return text.substring(prefix.length);
    return '建立店家失敗，請稍後再試';
  }

  Future<void> _askToRecheckActivation(String message) async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('激活碼無法使用'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('留在此頁'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('返回驗證'),
            ),
          ],
        );
      },
    );
    if (leave == true && mounted) {
      Navigator.pop(context, ShopCreateExit.recheckActivation);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  void _openPolicyThenCreate() {
    if (_loading || _awaitingPolicy) return;
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();
    final district = _districtController.text.trim();
    final String? missing = name.isEmpty
        ? '請輸入店名'
        : city.isEmpty
        ? '請選擇城市'
        : district.isEmpty
        ? '請選擇區域'
        : null;
    if (missing != null) {
      _showMessage(missing);
      return;
    }
    if (widget.activationCode.trim().isEmpty) {
      Navigator.pop(context, ShopCreateExit.recheckActivation);
      return;
    }
    setState(() => _awaitingPolicy = true);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlatformShopOwnerPolicyPage(
          onAgree: () {
            Navigator.pop(context);
            _createShop();
          },
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _awaitingPolicy = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final city = _cityController.text;
    return CreateShopOpeningView(
      nameController: _nameController,
      city: city,
      district: _districtController.text,
      cities: taiwanMap.keys.toList(),
      districts: city.isEmpty ? const <String>[] : taiwanMap[city] ?? const [],
      onCityChanged: (value) {
        setState(() {
          _cityController.text = value ?? '';
          _districtController.clear();
        });
      },
      onDistrictChanged: (value) {
        setState(() {
          _districtController.text = value ?? '';
        });
      },
      loading: _loading,
      activationReady: widget.activationCode.trim().isNotEmpty,
      onSubmit: _openPolicyThenCreate,
      onBack: () => Navigator.maybePop(context),
    );
  }
}
