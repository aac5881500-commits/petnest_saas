/// Profile recording choices, not vaccination advice or a diagnostic checklist.
/// Vaccine names: https://animal.moa.gov.tw/public/upload/News/250717013416722857DYCJP.pdf
/// https://www.nvri.gov.tw/Module/DisplayPageContent.aspx?pid=O4rPcoRqTpw%3D
/// Breed examples: https://kids.moa.gov.tw/view.php?category=A20&func=knowledge&id=20&subfunc=kids_knowledge
class PetHabitField {
  const PetHabitField(this.key, this.label, this.options);
  final String key, label;
  final List<String> options;
}

class PetProfileCatalog {
  PetProfileCatalog._();
  static List<String> missingRequired({
    required String? species,
    required String name,
    required String? gender,
    required String? age,
    required String? neuter,
    required String? medical,
    required String? litter,
  }) => [
    if (!['cat', 'dog'].contains(species)) '寵物種類',
    if (name.trim().isEmpty) '寵物名字',
    if (!['公', '母', '公貓', '母貓', '公狗', '母狗'].contains(gender)) '性別',
    if ((age ?? '').isEmpty) '年齡',
    if ((neuter ?? '').isEmpty) '結紮狀況',
    if ((medical ?? '').trim().isEmpty) '醫療狀況',
    if (species == 'cat' && (litter ?? '').trim().isEmpty) '貓砂種類',
  ];
  static const catBreeds = [
    '米克斯（混種貓）',
    '英國短毛貓',
    '美國短毛貓',
    '布偶貓',
    '波斯貓',
    '金吉拉貓',
    '緬因貓',
    '挪威森林貓',
    '西伯利亞貓',
    '俄羅斯藍貓',
    '暹羅貓',
    '孟加拉貓',
    '阿比西尼亞貓',
    '異國短毛貓',
    '蘇格蘭摺耳貓',
    '蘇格蘭立耳貓',
    '曼赤肯貓',
    '斯芬克斯貓',
    '土耳其安哥拉貓',
    '伯曼貓',
    '緬甸貓',
    '索馬利貓',
    '德文捲毛貓',
    '柯尼斯捲毛貓',
    '美國捲耳貓',
    '塞爾凱克捲毛貓',
  ];
  static const dogBreeds = [
    '米克斯（混種犬）',
    '台灣犬',
    '柴犬',
    '貴賓犬',
    '馬爾濟斯',
    '博美犬',
    '吉娃娃',
    '臘腸犬',
    '約克夏',
    '西施犬',
    '雪納瑞',
    '比熊犬',
    '法國鬥牛犬',
    '英國鬥牛犬',
    '巴哥犬',
    '柯基犬',
    '米格魯',
    '黃金獵犬',
    '拉布拉多犬',
    '哈士奇',
    '薩摩耶犬',
    '邊境牧羊犬',
    '喜樂蒂牧羊犬',
    '德國牧羊犬',
    '澳洲牧羊犬',
    '秋田犬',
    '鬆獅犬',
    '大麥町',
    '傑克羅素㹴',
    '波士頓㹴',
    '西高地白㹴',
    '可卡犬',
    '蝴蝶犬',
    '騎士查理王小獵犬',
    '杜賓犬',
    '羅威納犬',
    '伯恩山犬',
    '阿拉斯加雪橇犬',
    '大白熊犬',
    '紐芬蘭犬',
  ];
  static const catVaccines = [
    '貓三合一',
    '貓四合一',
    '貓五合一',
    '貓白血病疫苗',
    '狂犬病疫苗',
    '未接種',
    '不確定',
  ];
  static const dogVaccines = [
    '犬五合一',
    '犬七合一',
    '犬八合一',
    '犬十合一',
    '狂犬病疫苗',
    '犬舍咳疫苗',
    '犬萊姆病疫苗',
    '犬鉤端螺旋體疫苗',
    '未接種',
    '不確定',
  ];
  static const catMedical = [
    '無',
    '慢性腎臟病',
    '泌尿道疾病／尿結石',
    '心臟病',
    '肥厚型心肌病',
    '糖尿病',
    '甲狀腺機能亢進',
    '氣喘／呼吸道疾病',
    '貓上呼吸道感染',
    '貓白血病（FeLV）',
    '貓免疫缺陷病毒（FIV／貓愛滋）',
    '貓傳染性腹膜炎（FIP）',
    '貓泛白血球減少症（貓瘟）',
    '腸胃疾病',
    '胰臟炎',
    '肝臟疾病',
    '皮膚疾病',
    '黴菌感染',
    '過敏',
    '口腔／牙齒疾病',
    '關節炎／行動不便',
    '神經疾病／癲癇',
    '眼睛疾病',
    '腫瘤',
    '寄生蟲感染',
    '術後照護',
    '不確定',
  ];
  static const dogMedical = [
    '無',
    '心臟病',
    '二尖瓣疾病',
    '慢性腎臟病',
    '泌尿道疾病／尿結石',
    '糖尿病',
    '甲狀腺機能低下',
    '庫欣氏症',
    '氣管塌陷',
    '呼吸道疾病／犬舍咳',
    '犬瘟熱',
    '犬小病毒感染',
    '皮膚疾病',
    '異位性皮膚炎',
    '過敏',
    '耳道疾病',
    '腸胃疾病',
    '胰臟炎',
    '肝臟疾病',
    '髕骨異位',
    '髖關節疾病',
    '椎間盤疾病',
    '關節炎／行動不便',
    '癲癇／神經疾病',
    '眼睛疾病',
    '口腔／牙齒疾病',
    '心絲蟲感染',
    '艾利希體感染',
    '焦蟲感染',
    '寄生蟲感染',
    '腫瘤',
    '術後照護',
    '不確定',
  ];
  static const litters = ['豆腐砂', '礦砂', '木屑砂', '紙砂', '水晶砂', '混合貓砂', '不使用貓砂'];
  static List<String> breeds(String? species) => species == 'cat'
      ? catBreeds
      : species == 'dog'
      ? dogBreeds
      : [];
  static List<String> vaccines(String? species) => species == 'cat'
      ? catVaccines
      : species == 'dog'
      ? dogVaccines
      : [];
  static List<String> medical(String? species) => species == 'cat'
      ? catMedical
      : species == 'dog'
      ? dogMedical
      : [];
  static const commonHabits = [
    PetHabitField('feedingMethod', '飲食類型', [
      '乾飼料',
      '濕食／罐頭',
      '鮮食',
      '乾濕混合',
      '處方飲食',
    ]),
    PetHabitField('feedingSchedule', '餵食方式', ['定時定量', '自由採食', '少量多餐']),
  ];
  static const catHabits = [
    PetHabitField('catToilet', '貓咪如廁習慣', [
      '正常使用貓砂盆',
      '需要獨立貓砂盆',
      '偶爾在砂盆外如廁',
      '有噴尿習慣',
      '需協助如廁',
    ]),
    PetHabitField('catInteraction', '貓咪互動習慣', [
      '親人、願意互動',
      '慢熟，需要適應時間',
      '怕生，偏好安靜',
      '不喜歡被抱',
      '請避免主動觸摸',
    ]),
    PetHabitField('catRest', '貓咪休息習慣', [
      '喜歡躲藏空間',
      '習慣自己的睡墊／毯子',
      '喜歡高處休息',
      '需要安靜獨處',
    ]),
  ];
  static const dogHabits = [
    PetHabitField('dogToilet', '狗狗如廁方式', [
      '使用尿墊',
      '戶外如廁',
      '室內固定地點',
      '室內外皆可',
      '需協助如廁／尿布',
    ]),
    PetHabitField('dogWalk', '散步需求', [
      '不需外出散步',
      '每日 1 次',
      '每日 2 次',
      '每日 3 次以上',
      '僅短程如廁',
    ]),
    PetHabitField('dogSocial', '與其他狗相處', [
      '可與其他狗互動',
      '需要慢慢介紹',
      '偏好單獨活動',
      '會害怕其他狗',
      '可能對其他狗吠叫或有攻擊行為',
    ]),
    PetHabitField('dogHandling', '牽繩與照護習慣', [
      '可配戴胸背／牽繩',
      '使用項圈與牽繩',
      '容易暴衝，需留意',
      '容易緊張，需慢慢接近',
      '穿脫裝備需協助',
    ]),
    PetHabitField('dogRest', '狗狗休息習慣', [
      '習慣睡自己的床墊',
      '習慣籠內休息',
      '需要陪伴才能安定',
      '可能有分離焦慮／吠叫',
    ]),
  ];
  static List<PetHabitField> habits(String? species) => [
    if (species == 'cat' || species == 'dog') ...commonHabits,
    if (species == 'cat') ...catHabits,
    if (species == 'dog') ...dogHabits,
  ];
  static Map<String, String> cleanHabits(Object? raw, String? species) {
    if (raw is! Map) return {};
    return {
      for (final f in habits(species))
        if (raw[f.key] is String && (raw[f.key] as String).trim().isNotEmpty)
          f.key: (raw[f.key] as String).trim(),
    };
  }

  static List<MapEntry<String, String>> habitRows(
    Object? raw,
    String? species,
  ) {
    final values = cleanHabits(raw, species);
    return [
      for (final f in habits(species))
        if (values.containsKey(f.key)) MapEntry(f.label, values[f.key]!),
    ];
  }
}
