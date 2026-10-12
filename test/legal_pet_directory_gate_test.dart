// 檔案名稱：test/legal_pet_directory_gate_test.dart
// 功能說明：業者名單的舊請求、舊版 API、空結果與同步標題。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/legal_pet/directory_load_gate.dart';

void main() {
  test('較慢的舊請求不能覆蓋新搜尋', () {
    final gate = DirectoryLoadGate();
    final first = gate.issue();
    final second = gate.issue();
    expect(gate.isCurrent(first), isFalse);
    expect(gate.isCurrent(second), isTrue);
  });

  test('新查詢重設分頁與選取，舊請求不寫回結果', () {
    final lists = DirectoryListController()
      ..pageIndex = 2
      ..cursors = ['', 'a', 'b']
      ..selectedId = 'old';
    final first = lists.issue();
    lists.beginRequest(resetPage: true);
    final second = lists.issue();
    expect(lists.pageIndex, 0);
    expect(lists.cursors, ['']);
    expect(lists.selectedId, isNull);
    expect(lists.isCurrent(first), isFalse);
    expect(lists.isCurrent(second), isTrue);
  });

  test('舊版 API 有搜尋或篩選時不接受名單', () {
    final searched = decideDirectoryResponse(apiVersion: 0, constrained: true);
    expect(searched.acceptItems, isFalse);
    expect(searched.stale, isTrue);
    expect(
      staleDirectoryBackendMessage,
      '後端版本尚未更新，請部署業者資料庫相關 Functions',
    );
    final browsing = decideDirectoryResponse(
      apiVersion: 1,
      constrained: false,
    );
    expect(browsing.acceptItems, isTrue);
    expect(browsing.stale, isTrue);
    final current = decideDirectoryResponse(apiVersion: 3, constrained: true);
    expect(current.acceptItems, isTrue);
    expect(current.stale, isFalse);
  });

  test('缺少同步欄位時不顯示尚未同步，空結果不沿用舊標題', () {
    expect(
      directorySyncHeadline(
        phase: 'unknown',
        successText: '',
        hasItems: true,
      ),
      '政府資料已載入',
    );
    expect(
      directorySyncHeadline(phase: 'never', successText: '', hasItems: false),
      '尚未同步政府資料',
    );
    expect(
      directorySyncHeadline(
        phase: 'never',
        successText: '2026/10/06 21:59',
        hasItems: false,
      ),
      '最後成功同步：2026/10/06 21:59',
    );
    expect(
      directorySyncHeadline(phase: 'never', successText: '', hasItems: false),
      '尚未同步政府資料',
    );
    expect(
      directorySyncHeadline(
        phase: 'failed',
        successText: '2026/10/06 21:59',
        hasItems: false,
      ),
      '最後成功同步：2026/10/06 21:59　同步失敗',
    );
  });
}
