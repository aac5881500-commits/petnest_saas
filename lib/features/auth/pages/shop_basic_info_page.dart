// lib/features/auth/pages/shop_basic_info_page.dart
// 👤 店家基本資料（完整版🔥）
// ✅ 縣市區域下拉
// ✅ IG / FB
// ✅ LINE 移動
// ✅ 移除介紹

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopBasicInfoPage extends StatefulWidget {
  const ShopBasicInfoPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<ShopBasicInfoPage> createState() =>
      _ShopBasicInfoPageState();
}

class _ShopBasicInfoPageState extends State<ShopBasicInfoPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();

  final _lineUrlController = TextEditingController();
  final _igUrlController = TextEditingController();
  final _fbUrlController = TextEditingController();

  final _businessHoursController = TextEditingController();
  final _licenseController = TextEditingController();
  final _taxIdController = TextEditingController();

  bool _showTaxId = true;
  bool _loading = true;
  bool _saving = false;

  String _businessType = 'cat';

  /// 🔥 台灣縣市 + 區域
 final Map<String, List<String>> taiwanMap = {
  '台北市': ['中正區','大同區','中山區','松山區','大安區','萬華區','信義區','士林區','北投區','內湖區','南港區','文山區'],
  '新北市': ['板橋區','新莊區','中和區','永和區','土城區','樹林區','三重區','蘆洲區','五股區','泰山區','林口區','淡水區','汐止區','瑞芳區','三峽區','鶯歌區','深坑區','石碇區','坪林區','三芝區','石門區','八里區','平溪區','雙溪區','貢寮區','金山區','萬里區','烏來區'],
  '桃園市': ['桃園區','中壢區','平鎮區','八德區','楊梅區','蘆竹區','龜山區','龍潭區','大溪區','大園區','觀音區','新屋區','復興區'],
  '台中市': ['中區','東區','南區','西區','北區','西屯區','南屯區','北屯區','豐原區','東勢區','大甲區','清水區','沙鹿區','梧棲區','后里區','神岡區','潭子區','大雅區','新社區','石岡區','外埔區','大安區','烏日區','大肚區','龍井區','霧峰區','太平區','大里區','和平區'],
  '台南市': ['中西區','東區','南區','北區','安平區','安南區','永康區','歸仁區','新化區','左鎮區','玉井區','楠西區','南化區','仁德區','關廟區','龍崎區','官田區','麻豆區','佳里區','西港區','七股區','將軍區','學甲區','北門區','新營區','後壁區','白河區','東山區','六甲區','下營區','柳營區','鹽水區','善化區','大內區','山上區','新市區','安定區'],
  '高雄市': ['楠梓區','左營區','鼓山區','三民區','鹽埕區','前金區','新興區','苓雅區','前鎮區','旗津區','小港區','鳳山區','林園區','大寮區','大樹區','大社區','仁武區','鳥松區','岡山區','橋頭區','燕巢區','田寮區','阿蓮區','路竹區','湖內區','茄萣區','永安區','彌陀區','梓官區','旗山區','美濃區','六龜區','甲仙區','杉林區','內門區','茂林區','桃源區','那瑪夏區'],
  '新竹縣': ['竹北市','竹東鎮','新埔鎮','關西鎮','湖口鄉','新豐鄉','芎林鄉','橫山鄉','北埔鄉','寶山鄉','峨眉鄉','尖石鄉','五峰鄉'],
  '新竹市': ['東區','北區','香山區'],
  '苗栗縣': ['苗栗市','頭份市','苑裡鎮','通霄鎮','竹南鎮','後龍鎮','卓蘭鎮','大湖鄉','公館鄉','銅鑼鄉','南庄鄉','頭屋鄉','三義鄉','西湖鄉','造橋鄉','三灣鄉','獅潭鄉','泰安鄉'],
  '彰化縣': ['彰化市','鹿港鎮','和美鎮','線西鄉','伸港鄉','福興鄉','秀水鄉','花壇鄉','芬園鄉','員林市','溪湖鎮','田中鎮','大村鄉','埔鹽鄉','埔心鄉','永靖鄉','社頭鄉','二水鄉','北斗鎮','二林鎮','田尾鄉','埤頭鄉','芳苑鄉','大城鄉','竹塘鄉','溪州鄉'],
  '南投縣': ['南投市','埔里鎮','草屯鎮','竹山鎮','集集鎮','名間鄉','鹿谷鄉','中寮鄉','魚池鄉','國姓鄉','水里鄉','信義鄉','仁愛鄉'],
  '雲林縣': ['斗六市','斗南鎮','虎尾鎮','西螺鎮','土庫鎮','北港鎮','古坑鄉','大埤鄉','莿桐鄉','林內鄉','二崙鄉','崙背鄉','麥寮鄉','東勢鄉','褒忠鄉','台西鄉','元長鄉','四湖鄉','口湖鄉','水林鄉'],
  '嘉義縣': ['太保市','朴子市','布袋鎮','大林鎮','民雄鄉','溪口鄉','新港鄉','六腳鄉','東石鄉','義竹鄉','鹿草鄉','水上鄉','中埔鄉','竹崎鄉','梅山鄉','番路鄉','大埔鄉','阿里山鄉'],
  '嘉義市': ['東區','西區'],
  '屏東縣': ['屏東市','潮州鎮','東港鎮','恆春鎮','萬丹鄉','長治鄉','麟洛鄉','九如鄉','里港鄉','鹽埔鄉','高樹鄉','萬巒鄉','內埔鄉','竹田鄉','新埤鄉','枋寮鄉','新園鄉','崁頂鄉','林邊鄉','南州鄉','佳冬鄉','琉球鄉','車城鄉','滿州鄉','枋山鄉','三地門鄉','霧台鄉','瑪家鄉','泰武鄉','來義鄉','春日鄉','獅子鄉','牡丹鄉'],
  '宜蘭縣': ['宜蘭市','羅東鎮','蘇澳鎮','頭城鎮','礁溪鄉','壯圍鄉','員山鄉','冬山鄉','五結鄉','三星鄉','大同鄉','南澳鄉'],
  '花蓮縣': ['花蓮市','鳳林鎮','玉里鎮','新城鄉','吉安鄉','壽豐鄉','光復鄉','豐濱鄉','瑞穗鄉','富里鄉','秀林鄉','萬榮鄉','卓溪鄉'],
  '台東縣': ['台東市','成功鎮','關山鎮','長濱鄉','池上鄉','東河鄉','鹿野鄉','卑南鄉','大武鄉','綠島鄉','太麻里鄉','海端鄉','延平鄉','金峰鄉','達仁鄉','蘭嶼鄉'],
  '澎湖縣': ['馬公市','湖西鄉','白沙鄉','西嶼鄉','望安鄉','七美鄉'],
  '金門縣': ['金城鎮','金湖鎮','金沙鎮','金寧鄉','烈嶼鄉','烏坵鄉'],
  '連江縣': ['南竿鄉','北竿鄉','莒光鄉','東引鄉'],
};

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    final shop =
        await ShopService.instance.getShop(widget.shopId);

    _nameController.text = shop?['name'] ?? '';
    _phoneController.text = shop?['phone'] ?? '';
    _addressController.text = shop?['address'] ?? '';
    _cityController.text = shop?['city'] ?? '';
    _districtController.text = shop?['district'] ?? '';

    _lineUrlController.text = shop?['lineUrl'] ?? '';
    _igUrlController.text = shop?['igUrl'] ?? '';
    _fbUrlController.text = shop?['fbUrl'] ?? '';

    _businessHoursController.text =
        shop?['businessHours'] ?? '';
    _licenseController.text =
        shop?['licenseNumber'] ?? '';
    _taxIdController.text = shop?['taxId'] ?? '';
    _showTaxId = shop?['showTaxId'] ?? true;

    _businessType = shop?['businessType'] ?? 'cat';

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    await ShopService.instance.updateShopBasicInfo(
      shopId: widget.shopId,
      name: _nameController.text,
      businessType: _businessType,
      phone: _phoneController.text,
      address: _addressController.text,
      city: _cityController.text,
      district: _districtController.text,

      lineUrl: _lineUrlController.text,
      igUrl: _igUrlController.text,
      fbUrl: _fbUrlController.text,

      businessHours: _businessHoursController.text,
      licenseNumber: _licenseController.text,
      taxId: _taxIdController.text,
      showTaxId: _showTaxId,
    );

    setState(() => _saving = false);

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已儲存')));
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _lineUrlController.dispose();
    _igUrlController.dispose();
    _fbUrlController.dispose();
    _businessHoursController.dispose();
    _licenseController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final districts =
        taiwanMap[_cityController.text] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('店家基本資料')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: _input('店名'),
                    validator: (v) => v!.isEmpty ? '必填' : null,
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField(
                    value: _businessType,
                    decoration: _input('類型'),
                    items: const [
                      DropdownMenuItem(value: 'cat', child: Text('貓')),
                    ],
                    onChanged: (v) =>
                        setState(() => _businessType = v!),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneController,
                    decoration: _input('電話'),
                  ),

                  const SizedBox(height: 16),

                  /// 🔥 縣市
                  DropdownButtonFormField(
                    value: _cityController.text.isEmpty
                        ? null
                        : _cityController.text,
                    decoration: _input('縣市'),
                    items: taiwanMap.keys
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _cityController.text = v!;
                        _districtController.clear();
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  /// 🔥 區域
                  DropdownButtonFormField(
                    value: _districtController.text.isEmpty
                        ? null
                        : _districtController.text,
                    decoration: _input('區域'),
                    items: districts
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _districtController.text = v!),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _addressController,
                    decoration: _input('地址'),
                  ),

                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _businessHoursController,
                    decoration: _input('營業時間'),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _licenseController,
                    decoration: _input('特寵字號'),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _taxIdController,
                    decoration: _input('統編'),
                  ),

                  SwitchListTile(
                    value: _showTaxId,
                    title: const Text('顯示統編'),
                    onChanged: (v) =>
                        setState(() => _showTaxId = v),
                  ),

                  const SizedBox(height: 16),

                  /// 🔥 LINE / IG / FB
                  TextFormField(
                    controller: _lineUrlController,
                    decoration: _input('LINE'),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _igUrlController,
                    decoration: _input('IG'),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _fbUrlController,
                    decoration: _input('FB'),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '儲存中' : '儲存'),
                  ),
                ],
              ),
            ),
    );
  }
}