/// Local editing references only; applying never publishes a policy.
class ShopPolicyTemplates {
  static const name = '標準貓旅館詳細版';
  static const description = '包含接送安排、健康告知、自備用品、照護方式、活動安排及異常處理，可依店家實際情況調整。';
  static const Map<String, String> sections = {
    "checkinTime":
        "本店營業時間為【營業時間】，環境參觀採事先預約，以便安排接待並維持住宿貓咪的安寧。請先與本店確認參觀日期、人數及時段，勿未經預約直接進入住宿區。\n\n參觀期間請配合現場清潔與動線安排，未經同意請勿開啟房門、觸摸或餵食其他貓咪。同行兒童應由成人陪同，避免奔跑、喧嘩或拍打房門。\n\n如遇清潔、照護或其他無法接待的情況，本店將與您協調其他可安排時段。",
    "checkOutFlow":
        "入住辦理時段為【入住時段】，退房接回時段為【退房時段】。請依預約確認的時間辦理接送，並預留時間核對資料、交接用品及說明照護需求。\n\n貓咪應使用牢固、可確實關閉的外出籠接送。交接時請核對貓咪、聯絡方式、入住期間、飲食安排及隨身物品。\n\n如由他人代接，請提前提供代接人姓名及聯絡方式，並配合身分核對。需要提早送達、延後接回或延長住宿時，請先確認房況、可安排時段與費用，不以原訂單自動續住。\n\n無法準時接回時，請主動聯繫本店。逾時處理及費用須事前說明並確認，不於接回時臨時增加未約定收費。",
    "basicCondition":
        "預約時請提供貓咪年齡、性別、結紮狀況、疫苗與驅蟲紀錄，以及近期健康情形。本店將依已公告的入住條件與實際照護能力確認是否適合接待。\n\n本店接受的年齡、疫苗及驅蟲條件為：【本店入住健康條件】。如因年齡或健康因素無法符合，請在預約前提出，由本店依個別情況討論是否可安排，不以付款完成代替適住確認。\n\n貓咪如有疑似傳染性疾病、寄生蟲感染、近期手術、懷孕、明顯不適，或需要特殊醫療照護，請事先告知。需要注射、侵入性處置或其他專業醫療行為者，應另行安排具備適當能力的照護場所。",
    "ownerNotice":
        "請如實提供已知疾病、過往病史、近期就醫、用藥、過敏、特殊飲食與活動限制，並說明是否有緊張、逃脫、攻擊、自傷、拒食、噴尿或其他需要注意的行為。\n\n請提供日常餵食份量、餵食時間、飲水與排泄習慣，以及貓咪熟悉的安撫方式。相關資料如在預約後發生變動，請於入住前主動更新。\n\n住宿期間請保持聯絡方式暢通，並提供能協助處理事項的緊急聯絡人。特殊照護事項應於入住前逐項確認，包含本店是否接受、可提供的方式及額外費用，不以備註留言視為店家已同意提供服務。",
    "checkinNotice":
        "請準備足夠住宿期間使用的慣用食物，並標示貓咪姓名、每餐份量、餵食方式與保存需求。食物需要冷藏、冷凍或其他處理時，請先確認本店能否配合。\n\n攜帶藥品時，請保留清楚標示，提供使用方式、劑量與時間，並事先確認本店是否接受代餵或相關照護；未經確認的藥品或照護需求，不視為已納入住宿服務。\n\n請勿攜帶來源不明、已變質或無法辨識內容的食物與用品。入住時將共同確認交接內容；如現場發現貓咪狀況與事先提供資料明顯不同，應先討論適合的照護安排及後續處理。",
    "facility":
        "本店提供的房內設備、貓砂與日常用品為：【實際設備與用品清單】。房型大小、設備及包含的服務，以預約前提供並經確認的內容為準。\n\n如貓咪有慣用的貓砂、砂盆、食具或寢具，請先確認是否適合攜帶及使用。自備用品應標示姓名，並避免提供容易破損、掉落零件或可能造成誤食的物品。\n\n如有加購用品或額外服務，應先說明項目、數量及費用，經確認後提供。攝影機、照片回報或其他服務，僅在本店確實提供並已說明的範圍內適用。",
    "specialCase":
        "住宿期間如發現食慾、精神、排泄、呼吸或其他狀況異常，本店將採取適當處理並聯繫飼主或緊急聯絡人，說明觀察情形與已採取的措施。\n\n有緊急就醫必要時，將優先依事前確認的就醫安排處理；若情況緊急、指定醫院無法接診或暫時聯繫不上飼主，將以貓咪安全為優先，協助送往適當的獸醫診療機構，並持續嘗試聯繫及提供就醫資訊。\n\n醫療、交通及其他必要費用應保留明細，費用負擔與責任依事件原因、雙方約定及適用規定處理，不以本條排除本店應負的責任。\n\n貓咪如持續嚴重不適應，或其狀況超出本店可提供的照護能力，將與飼主討論接回或其他適當安排，不擅自將貓咪交付未經確認的人員。",
    "activity":
        "本店的活動方式為：【實際活動安排】。活動安排會考量貓咪個性、適應程度、身體狀況、環境與其他住宿貓咪的安全。\n\n未經飼主事先同意，不安排與其他家庭的貓咪共同活動。同一家庭多隻貓咪是否共住或共同活動，也應先確認彼此相處情形與本店可安排方式。\n\n如貓咪出現緊張、躲藏、衝撞、攻擊或其他不適應反應，將調整或暫停活動並告知飼主。",
    "extraNotice":
        "請於入住前確認住宿期間、房型、貓咪數量、費用、付款方式及照護需求。增加服務、變更飲食、延長住宿或調整接送安排，須經雙方確認後辦理。\n\n自備用品請標示姓名，交接時共同核對。請避免攜帶貴重、易碎、難以清潔或可能危及貓咪安全的物品；如有特殊清潔或保存需求，請提前說明。\n\n如有疑問或需反映住宿情況，請透過訂單留言或本店已提供的聯絡方式提出，方便確認內容與保留溝通紀錄。\n\n已成立預約的服務與費用，如需調整，應另行溝通確認，不以更新本頁條款直接變更既有約定。",
    "cancelPolicy":
        "取消、改期與提前退宿，請透過【取消或改期申請方式】提出，並提供預約資料及申請事項。\n\n服務開始前取消：本店依【入住前取消的期限、金額及退款計算方式】辦理。\n\n入住後提前退宿：已提供服務的費用依【已提供住宿費用的計算方式】計算，剩餘款項依【提前退宿的退款規則】處理。\n\n解約手續費：【是否收取；如收取請列明金額或計算方式】。\n\n退款經確認後，於【退款辦理期限】透過【退款管道】辦理，並提供處理明細。\n\n因本店因素無法提供服務時：【店家無法履約的處理及退款方式】。\n\n因天災或其他無法履約情況：【天災等無法履約時的改期、取消及退款方式】。",
  };
  static const parameters = <ShopPolicyParameter>[
    ShopPolicyParameter(
      'checkinTime',
      '【營業時間】',
      '營業與參觀時間',
      '填寫實際營業時間，以及參觀是否需要預約。',
      '例如：週一至週日 10:00–19:00，參觀請事先預約',
      multiline: false,
    ),
    ShopPolicyParameter(
      'checkOutFlow',
      '【入住時段】',
      '可辦理入住的時間',
      '填寫顧客可以送貓入住的時段。',
      '例如：14:00–18:00，其他時間請先聯絡',
      multiline: false,
    ),
    ShopPolicyParameter(
      'checkOutFlow',
      '【退房時段】',
      '可辦理退房的時間',
      '填寫接回時間與最晚退房時間；有超時處理方式也請說明。',
      '請填實際接回時段、最晚退房時間及超時處理方式。',
    ),
    ShopPolicyParameter(
      'basicCondition',
      '【本店入住健康條件】',
      '入住健康條件',
      '填寫店家實際要求的健康、疫苗、驅蟲或其他入住條件。',
      '請依實際接待條件填寫，勿直接採用其他店家的限制。',
    ),
    ShopPolicyParameter(
      'facility',
      '【實際設備與用品清單】',
      '提供的設備與用品',
      '只列出實際提供的設備與用品，沒有提供的服務不要寫入。',
      '請逐項列出本店實際提供的設備、用品，以及需自備的物品。',
    ),
    ShopPolicyParameter(
      'activity',
      '【實際活動安排】',
      '住宿期間的活動安排',
      '說明是否安排活動、採個別或其他方式，以及是否依適應狀況調整。',
      '請依實際安排說明活動方式與調整條件，勿承諾未提供的服務。',
    ),
    ShopPolicyParameter(
      'cancelPolicy',
      '【取消或改期申請方式】',
      '取消與改期的聯絡方式',
      '填寫顧客應透過哪個管道提出申請，以及需要提供的資料。',
      '例如：透過訂單留言提出，提供預約編號及希望取消或改期的日期。',
    ),
    ShopPolicyParameter(
      'cancelPolicy',
      '【入住前取消的期限、金額及退款計算方式】',
      '入住前取消與退款規則',
      '清楚寫出申請時間如何影響退款，以及金額或比例的計算方式。',
      '請列明各取消期限與對應的實際退款金額或計算方式，不使用未確認的比例。',
    ),
    ShopPolicyParameter(
      'cancelPolicy',
      '【已提供住宿費用的計算方式】',
      '已入住費用的計算方式',
      '說明提前退宿時，已提供住宿服務的費用如何計算。',
      '請列明已提供服務的計費單位、費率依據與計算方式。',
    ),
    ShopPolicyParameter(
      'cancelPolicy',
      '【提前退宿的退款規則】',
      '提前退宿的剩餘款項處理',
      '說明尚未使用住宿費用如何處理、退款如何計算。',
      '請說明未使用住宿費用的退款條件與計算方式。',
    ),
    ShopPolicyParameter(
      'cancelPolicy',
      '【是否收取；如收取請列明金額或計算方式】',
      '解約手續費',
      '請明確填寫不收取，或填寫實際收取的金額、計算方式及適用條件。',
      '例如：不收取；如會收取，請另填實際金額、算法與適用條件。',
    ),
    ShopPolicyParameter(
      'cancelPolicy',
      '【退款辦理期限】',
      '退款處理時間',
      '填寫確認退款後，預計於多少工作天內辦理。',
      '例如：確認退款後 X 個工作天內辦理，請填入實際天數。',
      multiline: false,
    ),
    ShopPolicyParameter(
      'cancelPolicy',
      '【退款管道】',
      '退款方式',
      '填寫店家實際可以使用的退款方式。',
      '例如：銀行轉帳；所需資料於確認退款時告知。',
      multiline: false,
    ),
    ShopPolicyParameter(
      'cancelPolicy',
      '【店家無法履約的處理及退款方式】',
      '店家無法提供服務的處理方式',
      '說明因店家因素無法提供服務時，如何通知、處理已付款項及退款。',
      '請說明通知方式、已付款項的處理及實際退款方式。',
    ),
    ShopPolicyParameter(
      'cancelPolicy',
      '【天災等無法履約時的改期、取消及退款方式】',
      '天災等特殊情況的處理方式',
      '說明無法提供或使用服務時，如何協調改期、取消及退款。',
      '請填寫實際協調方式，以及改期、取消和退款處理。',
    ),
  ];

  static bool hasParameters(String text) =>
      parameters.any((p) => text.contains(p.marker));

  static List<ShopPolicyParameter> missing(
    Map<String, String> draft,
    Map<String, bool> enabled,
  ) => [
    for (final entry in draft.entries)
      if (enabled[entry.key] != false)
        for (final parameter in parameters)
          if (entry.value.contains(parameter.marker))
            parameter.inSection(entry.key),
  ];

  /// Substitute only exact markers still present in the current text.
  static Map<String, String> fill(
    Map<String, String> draft,
    Map<String, bool> enabled,
    Map<String, String> values,
  ) {
    final result = Map<String, String>.from(draft);
    final pattern = RegExp(
      parameters.map((p) => RegExp.escape(p.marker)).join('|'),
    );
    for (final entry in draft.entries) {
      if (enabled[entry.key] == false) continue;
      result[entry.key] = entry.value.replaceAllMapped(pattern, (match) {
        final marker = match[0]!;
        final value = values['${entry.key}:$marker']?.trim() ?? '';
        return value.isEmpty ? marker : value;
      });
    }
    return result;
  }
}

class ShopPolicyParameter {
  const ShopPolicyParameter(
    this.sectionKey,
    this.marker,
    this.name,
    this.description,
    this.example, {
    this.multiline = true,
  });
  final String sectionKey, marker, name, description, example;
  final bool multiline;
  String get id => '$sectionKey:$marker';
  ShopPolicyParameter inSection(String key) => ShopPolicyParameter(
    key,
    marker,
    name,
    description,
    example,
    multiline: multiline,
  );
}
