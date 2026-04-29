// lib/features/shop/pages/shop_policy_page.dart
// 📜 入住條款編輯頁（後台｜模板版🔥＋一鍵套用）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopPolicyPage extends StatefulWidget {
  const ShopPolicyPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<ShopPolicyPage> createState() => _ShopPolicyPageState();
}

class _ShopPolicyPageState extends State<ShopPolicyPage> {
  /// 🔥 模板欄位
  final Map<String, TextEditingController> _controllers = {

  /// 🔵 第一頁（入住須知）
  'checkinTime': TextEditingController(), // 營業時間與環境參觀時間
  'checkOutFlow': TextEditingController(), // 入住與退房安排
  'basicCondition': TextEditingController(), // 貓咪入住基本條件
  'ownerNotice': TextEditingController(), // 飼主須知
  'checkinNotice': TextEditingController(), // 入住須知
  'facility': TextEditingController(), // 基本設施
  'specialCase': TextEditingController(), // 特殊情況
  'activity': TextEditingController(), // 活動安排
  'extraNotice': TextEditingController(), // 額外注意事項

  /// 🔴 第二頁（退款）
  'cancelPolicy': TextEditingController(), // 訂房取消政策
};

  /// 🔥 開關
  Map<String, bool> _enabled = {

  /// 第一頁
  'checkinTime': true,
  'checkOutFlow': true,
  'basicCondition': true,
  'ownerNotice': true,
  'checkinNotice': true,
  'facility': true,
  'specialCase': true,
  'activity': true,
  'extraNotice': true,

  /// 第二頁
  'cancelPolicy': true,
};

  /// 🔥 額外條款
  /// 🔵 第一頁額外條款
List<TextEditingController> _customControllersPage1 = [];

/// 🔴 第二頁額外條款
List<TextEditingController> _customControllersPage2 = [];

  bool _loading = true;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final c in _customControllersPage1) {
      c.dispose();
}
for (final c in _customControllersPage2) {
  c.dispose();
}
    super.dispose();
  }

  /// 🔥 讀取
  Future<void> _loadPolicy() async {
    final data =
        await ShopService.instance.getCheckinPolicy(widget.shopId);

    if (data != null) {
      final sections = data['sections'] ?? {};
      final enabled = data['enabled'] ?? {};
      /// 🔥 回填模板欄位
sections.forEach((key, value) {
  if (_controllers.containsKey(key)) {
    _controllers[key]!.text = value ?? '';
  }
});

/// 🔥 回填開關
_enabled = Map<String, bool>.from(enabled);
      final custom1 = data['customPoliciesPage1'] ?? [];
final custom2 = data['customPoliciesPage2'] ?? [];



_customControllersPage1 =
    custom1.map<TextEditingController>((e) {
  return TextEditingController(text: e);
}).toList();

_customControllersPage2 =
    custom2.map<TextEditingController>((e) {
  return TextEditingController(text: e);
}).toList();

      _version = data['version'] ?? 1;
    }

    setState(() {
      _loading = false;
    });
  }

  /// 🔥 儲存
  Future<void> _save() async {
    final sections = <String, dynamic>{};

    _controllers.forEach((key, ctrl) {
      sections[key] = ctrl.text.trim();
    });

    final customPoliciesPage1 = _customControllersPage1
    .map((e) => e.text.trim())
    .where((e) => e.isNotEmpty)
    .toList();

final customPoliciesPage2 = _customControllersPage2
    .map((e) => e.text.trim())
    .where((e) => e.isNotEmpty)
    .toList();

    await ShopService.instance.updateCheckinPolicy(
  shopId: widget.shopId,
  sections: sections,
  enabled: _enabled,
  customPoliciesPage1: customPoliciesPage1,
  customPoliciesPage2: customPoliciesPage2,
);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已更新條款（版本已升級）')),
    );

    _loadPolicy();
  }

  /// 🔥 ⭐ 一鍵模板
/// 🔥 ⭐ 一鍵模板（完整對應新版欄位）
void _applyTemplate() {
  setState(() {

    /// =========================
    /// 🔵 第一頁：入住須知
    /// =========================

    /// 🔹 營業時間與環境參觀時間
    _controllers['checkinTime']!.text = '''
* 營業時間：全館採預約制，每日早上11:00至晚上20:00。
* 環境參觀：參觀也需事先預約，請透過LINE或電話預約，確保每位訪客都能得到妥善接待。
''';

    /// 🔹 入住與退房安排
    _controllers['checkOutFlow']!.text = '''
* 辦理時間：每日11:00至20:00皆可辦理入住或退房，需事先預約以便我們做好準備。
           辦理退房限貓主人或指定接送人辦理，皆須提供身分證明文件供核對。
* 營業時間外辦理入住/退房：每超過1小時酌收200元額外費用。

★ 營業時間外入住/退房收費基準 ★
09:00 – 09:59 入住/退房：加收400元。
10:00 – 10:59 入住/退房：加收200元。
20:01 – 21:00 入住/退房：加收200元。
21:01 – 22:00 入住/退房：加收400元。
* 若需營業時間外辦理入住/退房：最遲需於24小時提前確認，是否有小管家可以協助。當天臨時通知，恕無法配合營業時間外入住/退房。
* 超過以上時間欲辦理退房，則請於隔天辦理，並加收一天住宿費用，如原入住房型滿房，將依現場狀況調整，並以實際入住房型收費。
* 逾期未退宿：若住宿期滿後未前來辦理退宿，我們將視為同意續住，費用依原房型定價計費。如仍無法聯繫飼主並接回愛貓，將依動物保護法與相關棄養寵物法理規定處理與通報，並收取延長住宿及其衍生之費用。
''';

    /// 🔹 貓咪入住基本條件
    _controllers['basicCondition']!.text = '''
* 以下情況將無法辦理入住，建議尋求動物醫院協助：
    。 6個月以下幼貓以及14歲以上高齡貓。
    。 最近7天內剛施打預防針的貓咪。
    。 需要特殊醫療協助（如擠尿）的貓咪。
    。 發情中、懷孕中、哺乳中及產後兩個月內貓咪。
    。 剛從動物醫院出院14天內或動物收容所離開14天以內。
    。 已知患有高度傳染疾病、皮膚病相關疾病或其他心肺肝腎重大疾病貓旅客(如：愛滋病、白血病、腎貓、糖尿病、耳疥蟲、黴菌、心臟病…等)
* 貓咪入住時請詳盡告知貓咪狀況，若未確實告知之疾病健康史，或接種疫苗而產生相關傳染疾病，造成貓咪或其他本館內貓咪傷亡，將由貓飼主全權負責。
* 貓咪入住時如遇須緊急就診之情況，貓飼主同意本館立即就近送醫，並願意支付就醫後之所有衍生費用。
''';

    /// 🔹 飼主需告知
    _controllers['ownerNotice']!.text = '''
* 疫苗施打紀錄：包含三合一、狂犬病或其他基礎預防針之施打日期、間隔、是否完成全程施打等。
* 健康狀況：包含過往病史、用藥、過敏、懷孕、手術史、慢性病、食物忌口等。
* 行為特性：如攻擊性、怕生、過度緊張、噴尿、逃脫習性、抓門等行為。
* 感染風險：如曾接觸疑似疾病、脫毛異常、上吐下瀉、呼吸異常等。
* 住宿風險了解：飼主了解寵物外出或住宿期間，因環境變化、壓力或不可預期因素，可能誘發潛在疾病，故寵物於寄宿期間或返家後若出現疾病、情緒反應或其他身體狀況，在店家無故意或重大過失情形下，飼主不得歸責於店家()。
* 未如實告知所生後果：店家得無條件解除契約。若因飼主未提前告知導致寵物、他人或店家財物受損，飼主並應負擔全部相關損害責任。

* 注意:法規遵循：動物保護處人員依法可不定時稽查住宿貓咪的晶片，如經認定未植入晶片，飼主將面臨3000元至15000元不等的罰款，敬請配合並事先確認愛貓已植入晶片。
''';

    /// 🔹 入住須知
    _controllers['checkinNotice']!.text = '''
* 預留時間：辦理入住時，請預留30-60分鐘讓我們與您確認愛貓的照護資料，並希望您能多花幾分鐘與愛貓道別，以減少牠的緊張感。
* 住宿費用與文件：入住時需結清100%住宿費用，並簽訂「寄宿入住契約書」。請攜帶飼主的身分證正本及寵物健康手冊，供我們留檔後即時歸還。
* 飲食準備：請飼主自備貓咪常用食物，以確保腸胃適應性(如果是吃罐頭也沒問題)。如無法攜帶食物，我們也有準備2款乾飼料。
* 熟悉物品：可攜帶貓咪熟悉的毯子、睡窩或有飼主氣味的衣物，幫助貓咪快速適應新環境。
* 健康用品：如有特殊需求，可攜帶必要的補充劑、化毛膏或藥品，並提供詳細使用說明，我們提供額外客製化服務。
* 玩具與安撫物品：也可帶上愛貓習慣的貓抓板或玩具，能提升貓咪在住宿期間的舒適度。
''';

    /// 🔹 基本設施
    _controllers['facility']!.text = '''
* 24小時監控：每間貓房皆配有獨立的24小時連線監視器，入住當天小管家將協助您進行設定。
             由於房間並未進行隔音設計，為避免突然聲音對貓咪造成不安，監視器的通話功能未開放，敬請諒解。
* 免費提供貓砂：礦砂、豆腐砂。如遇缺貨，將以同等價位貓砂替代，確保貓咪舒適。為使貓咪更快適應，建議自備少量貓砂增加對環境的安全感。
* 砂盆配置：提供幾種形式的砂盆供飼主選擇使用。1-2隻貓提供1個砂盆；3-5隻貓提供2個砂盆，以滿足愛貓的如廁需求。
* 多種餐具選擇：我們為貓咪提供陶瓷碗，以及木製餐碗架，讓貓咪在進食時更加舒適。此外，我們還提供自動飲水機，確保貓咪隨時能飲用新鮮的水源。
''';

    /// 🔹 特殊情況
    _controllers['specialCase']!.text = '''
* 未結紮公貓：如未結紮的公貓在住宿期間出現發情占地盤噴尿的情況，我們將拍照通知飼主，並酌收每晚清潔費800元。
             此外，該貓將取消戶外探索時間，以避免其他貓咪受到影響。
* 強制分房：為保護貓咪安全，如同房貓咪出現攻擊或交配行為，影響其他房間貓咪的情緒或安全，我們將以安全優先為考量，得未經飼主同意強制分房，並收取額外住房費用。
''';

    /// 🔹 活動安排
    _controllers['activity']!.text = '''
* 每日放風時間：每房貓咪每日享有15分鐘探索活動時間，將是否探索館內的選擇權交給貓咪本身，不免強貓咪走出房間。
               我們將依館內入住狀況提供額外陪伴或探索時間的選配服務(每10分鐘150元)。
* 單一家庭放風：戶外放風採單一家庭方式，確保不同家庭的貓咪不會互相接觸，以保障貓咪們的安全與健康。
* 活動時間調整：基於安全考量，如貓咪在探索活動期間情緒過嗨或行為間接影響其他貓的安全，店家將有權酌情減少或暫停活動時間，並將貓咪帶回住宿房內。
''';

    /// 🔹 額外注意事項
    _controllers['extraNotice']!.text = '''
* 驅蟲建議：入住前7天內請為貓咪進行體外驅蟲，確保其他貓咪及旅館環境的衛生安全。
           如確認貓咪身上有跳蚤、壁蝨等高度傳染力疾病，將連繫飼主當日接回，並酌收「環境消毒費6000元/日」，若無法立即接回，將視房間使用狀況隔離貓旅客，衍伸住宿費用由貓飼主全額負擔且不得有議。
* 疫苗規定：入住貓咪需提供2年內的核心疫苗接種證明，未接種完整疫苗的貓咪將無法享有探索活動時間。
* 疫苗防護說明：貓咪注射預防針（如三合一或五合一疫苗）僅能預防致死率極高的疾病，但並不代表貓咪完全不會感冒或生病。因此，飼主需留意貓咪的健康狀況，並在入住時告知任何可能的健康問題。
* 法規遵循：動物保護處人員依法可不定時稽查住宿貓咪的晶片，如經認定未植入晶片，飼主將面臨3000元至15000元不等的罰款，敬請配合並事先確認愛貓已植入晶片。
''';

_customControllersPage1 = [
  TextEditingController(text: '特殊情況依現場調整'),
];

    /// =========================
    /// 🔴 第二頁：取消政策（先留空位）
    /// =========================
    _controllers['cancelPolicy']!.text = '''
★ 訂房後，須於3天內(含)支付當筆訂單房價總額的50%(非國定假日)及100%(國定假日)作為訂金，才算完成訂房，尾款於入住時結清，提前退宿不予退款。

           ▲於住宿日7日內(含)取消或未告知取消訂房，恕不退還訂金。
           ▲於住宿日08-10日內取消訂房，退回訂金50%。
           ▲於住宿日11-13日內取消訂房，退回訂金70%。
           ▲於住宿日14日內(含14日)內可免費取消訂房。
          ( 日期計算範例：4/20住宿，前3日係指4/17 – 4/19 )
★登記住宿日當天若遇颱風、地震等天災害或不可抗拒之因素時，以店家所在地臺北市政府公告狀況，之影響作為接收延期或取消訂房之判斷標準，請於入住日起3日內(含當日)與我們聯絡。

★ 訂金支付後，表示已詳閱並同意以上之訂房須知。

★ 國定假日定義，包含清明、端午、中秋、國慶日及元旦等連續3日以上(含)之假期，住宿日其中1天涵蓋國定假期即適用國定假日規範及定價。

★ 凡有無故退訂紀錄或不前來住宿卻未提前到知者，後續預定住宿須事先給付100%全額費用或有權不接受預訂。

★ 退費以轉帳放式，需請飼主負擔手續費15元(從退款中扣除)。

★ 農曆春節(過年)住宿不適用以上規定，相關規定將另行公告。
''';

    /// 🔹 額外條款
    _customControllersPage2 = [
  TextEditingController(text: '本館保有最終解釋權'),
];
    /// 🔥 全部開啟
    _enabled.updateAll((key, value) => true);
  });
}

  /// 🔥 UI
  Widget _buildSection(String title, String key) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
                Switch(
                  value: _enabled[key] ?? true,
                  onChanged: (v) {
                    setState(() {
                      _enabled[key] = v;
                    });
                  },
                ),
              ],
            ),
            TextField(
              controller: _controllers[key],
              maxLines: null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('入住規則設定'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [

Container(
  margin: const EdgeInsets.only(bottom: 16),
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.orange.shade50,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.orange),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: const [
      Text(
        '⚠️ 條款使用說明',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.orange,
        ),
      ),
      SizedBox(height: 8),
      Text(
  '本系統提供之條款模板僅供參考，實際內容請店家自行確認與修改。\n'
  '本平台不保證條款之法律正確性與完整性，所有責任由使用本條款之店家自行負責。\n'
  '本平台僅提供條款編輯與展示工具，不介入店家與消費者之間之交易或糾紛。\n'
  '若發生任何爭議，應由店家與消費者自行協商處理，本平台不負相關責任。',
  style: TextStyle(fontSize: 13),
),
    ],
  ),
),

                  /// 🔥 版本
                  Row(
                    children: [
                      const Text('目前版本：'),
                      Text(
                        'v$_version',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  /// 🔥 ⭐模板按鈕
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _applyTemplate,
                      child: const Text('一鍵套用預設模板'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView(
                      children: [
                        /// 🔵 第一頁
const Text('📄 入住須知（前台第1頁）',
    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

_buildSection('營業時間與環境參觀時間', 'checkinTime'),
_buildSection('入住與退房安排', 'checkOutFlow'),
_buildSection('貓咪入住基本條件', 'basicCondition'),
_buildSection('貓咪入住前飼主應告知資訊', 'ownerNotice'),
_buildSection('貓咪入住須知', 'checkinNotice'),
_buildSection('本店提供的基本設施', 'facility'),
_buildSection('特殊情況處理', 'specialCase'),
_buildSection('探索活動安排', 'activity'),
_buildSection('額外注意事項', 'extraNotice'),

const SizedBox(height: 20),

/// 🔴 第二頁
const Text('📄 訂房與退款（前台第2頁）',
    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

_buildSection('訂房取消政策', 'cancelPolicy'),

const SizedBox(height: 20),

const Text('第二頁額外條款',
    style: TextStyle(fontSize: 18)),

..._customControllersPage2.asMap().entries.map((entry) {
  final index = entry.key;
  final ctrl = entry.value;

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: '條款 ${index + 1}',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () {
            setState(() {
              _customControllersPage2.removeAt(index);
            });
          },
        ),
      ),
    ),
  );
}),

ElevatedButton(
  onPressed: () {
    setState(() {
      _customControllersPage2.add(TextEditingController());
    });
  },
  child: const Text('新增第二頁條款'),
),

                        const SizedBox(height: 20),

                        const Text('額外條款',
                            style: TextStyle(fontSize: 18)),

                        ..._customControllersPage1.asMap().entries.map((entry) {
                          final index = entry.key;
                          final ctrl = entry.value;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TextField(
                              controller: ctrl,
                              decoration: InputDecoration(
                                labelText: '條款 ${index + 1}',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    setState(() {
                                     _customControllersPage1.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            ),
                          );
                        }),

                        ElevatedButton(
                          onPressed: () {
  setState(() {
    _customControllersPage1.add(TextEditingController());
  });
},
                          child: const Text('新增條款'),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('儲存並升級版本'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}