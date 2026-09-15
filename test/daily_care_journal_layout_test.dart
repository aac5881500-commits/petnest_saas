// 檔案名稱：test/daily_care_journal_layout_test.dart
// 功能說明：舊店家缺欄套用預設編排；welcomeText 不讀不寫

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_journal_layout.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/daily_care_stay_info.dart';

void main() {
  test('舊資料沒有 journalCards 時套用預設半寬與色彩', () {
    final DailyCareSettingModel setting = DailyCareSettingModel.fromMap(
      <String, dynamic>{'enabled': true, 'welcomeText': '舊歡迎'},
    );
    final Map<String, DailyCareJournalCardLayout> cards =
        setting.resolvedJournalCards;
    expect(cards[DailyCareJournalCardKeys.environment]!.isHalf, isTrue);
    expect(
      cards[DailyCareJournalCardKeys.environment]!.colorKey,
      DailyCareJournalCardStyle.colorMint,
    );
    expect(cards[DailyCareJournalCardKeys.relax]!.isHalf, isFalse);
    expect(setting.journalDisplay.showShopName, isTrue);
    expect(setting.journalDisplay.showTemperature, isTrue);
    expect(setting.toMap().containsKey('welcomeText'), isFalse);
  });

  test('舊 welcomeText 讀取不失敗且不會寫回 toMap', () {
    final DailyCareSettingModel parsed = DailyCareSettingModel.fromMap(
      <String, dynamic>{'welcomeText': '請放心'},
    );
    expect(parsed.toMap().containsKey('welcomeText'), isFalse);
  });

  test('寵物名稱最多兩隻並顯示其餘隻數', () {
    expect(
      DailyCareStayInfo.formatPetNames(const <DailyCareStayPet>[
        DailyCareStayPet(name: '小米', photoUrl: ''),
      ]),
      '小米',
    );
    expect(
      DailyCareStayInfo.formatPetNames(const <DailyCareStayPet>[
        DailyCareStayPet(name: '小米', photoUrl: ''),
        DailyCareStayPet(name: '奶茶', photoUrl: ''),
        DailyCareStayPet(name: '歐蕾', photoUrl: ''),
        DailyCareStayPet(name: '黑糖', photoUrl: ''),
      ]),
      '小米、奶茶 等 4 隻',
    );
  });

  test('可隱藏卡片並寫回 Firestore 純 map', () {
    final DailyCareSettingModel setting = const DailyCareSettingModel().copyWith(
          journalDisplay: const DailyCareJournalDisplayFlags(
            showShopName: false,
            showTemperature: false,
            showRoomOrOffer: false,
          ),
          journalCards: DailyCareJournalCardLayout.mapFrom(<String, dynamic>{
            'food': <String, dynamic>{
              'visible': false,
              'width': 'full',
              'colorKey': 'orange',
              'order': 0,
            },
          }),
        );
    final Map<String, dynamic> map = setting.toMap();
    expect(map['journalDisplay'], isA<Map>());
    expect(map['journalCards'], isA<Map>());
    final DailyCareSettingModel parsed = DailyCareSettingModel.fromMap(map);
    expect(parsed.journalDisplay.showShopName, isFalse);
    expect(parsed.journalDisplay.showTemperature, isFalse);
    expect(
      (map['journalDisplay'] as Map)['showRoomOrOffer'],
      isTrue,
    );
    expect(parsed.resolvedJournalCards[DailyCareJournalCardKeys.food]!.visible, isFalse);
    expect(
      parsed.resolvedJournalCards[DailyCareJournalCardKeys.food]!.colorKey,
      DailyCareJournalCardStyle.colorOrange,
    );
  });
}
