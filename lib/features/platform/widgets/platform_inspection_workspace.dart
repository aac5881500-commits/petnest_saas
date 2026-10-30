import 'dart:convert';
import 'package:flutter/material.dart';

const _ink = Color(0xFF20304A);
const _muted = Color(0xFF65738A);
const _line = Color(0xFFE2E8F0);
const _accent = Color(0xFF315DC4);

/// A display-only projection. Callbacks navigate/read/export; no business editor
/// or shop action is mounted inside this workspace.
class PlatformInspectionWorkspace extends StatelessWidget {
  const PlatformInspectionWorkspace({
    super.key,
    required this.unlocked,
    required this.busy,
    required this.records,
    required this.collections,
    required this.customerController,
    required this.searchController,
    required this.onSearch,
    required this.onUnlock,
    required this.onAllShops,
    required this.onRefresh,
    required this.onOpenPath,
    required this.onRecord,
    required this.onCustomer,
    required this.onExport,
    this.shopId,
    this.shopName,
    this.path = '',
    this.error,
    this.onNext,
    this.onBack,
    this.onRetry,
    this.onOwnerPreview,
  });
  final bool unlocked, busy;
  final List<Map<String, dynamic>> records;
  final List<String> collections;
  final String? shopId, shopName, error;
  final String path;
  final TextEditingController customerController, searchController;
  final ValueChanged<String> onSearch, onOpenPath;
  final ValueChanged<Map<String, dynamic>> onRecord, onCustomer;
  final VoidCallback onUnlock, onAllShops, onRefresh, onExport;
  final VoidCallback? onNext, onBack, onRetry;
  final ValueChanged<Map<String, dynamic>>? onOwnerPreview;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4F6FA),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final wide = bounds.maxWidth >= 1080;
          final pad = bounds.maxWidth < 600 ? 16.0 : 24.0;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1560),
              child: ListView(
                padding: EdgeInsets.all(pad),
                children: [
                  _header(context),
                  const SizedBox(height: 20),
                  if (error != null) ...[
                    _box(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.deepOrange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                unlocked ? '資料暫時無法讀取' : '驗證碼暫時無法寄送',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(error!),
                          if (onRetry != null)
                            TextButton.icon(
                              onPressed: busy ? null : onRetry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('重試'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!unlocked)
                    _locked(context)
                  else ...[
                    if (busy) const LinearProgressIndicator(minHeight: 3),
                    const SizedBox(height: 12),
                    if (wide && shopId != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 224,
                            child: _navigation(context, vertical: true),
                          ),
                          const SizedBox(width: 20),
                          Expanded(child: _content(context)),
                          const SizedBox(width: 20),
                          SizedBox(width: 270, child: _customer(context)),
                        ],
                      )
                    else ...[
                      if (shopId != null) ...[
                        _navigation(context, vertical: false),
                        const SizedBox(height: 16),
                        _customer(context, collapsible: true),
                        const SizedBox(height: 16),
                      ],
                      _content(context),
                    ],
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    '查核範圍：目前已儲存的店家資料與紀錄。此處為獨立唯讀資料檢視，尚未還原所有 APP 畫面；已刪除資料不在本次範圍。',
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    return _box(
      color: const Color(0xFF213651),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge('最高權限專用', Icons.verified_user_outlined, dark: true),
              _badge('唯讀查核', Icons.visibility_outlined, dark: true),
              _badge(
                unlocked ? '查核已解鎖' : '等待身分驗證',
                unlocked ? Icons.lock_open : Icons.lock_outline,
                dark: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            shopId == null ? '店家查核工作台' : (shopName ?? '店家資料查核'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            shopId == null ? '從店家開始，查閱客戶、交易與對話，保留每一筆資料的來源。' : '店家編號：$shopId',
            style: const TextStyle(color: Color(0xFFD9E3F3), height: 1.6),
          ),
          const SizedBox(height: 16),
          const Text(
            '查閱與匯出會留下紀錄・驗證後可跨店查閱・閒置 30 分鐘鎖定',
            style: TextStyle(
              color: Color(0xFFB9CBE2),
              fontSize: 12,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _locked(BuildContext context) {
    return _box(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFFEBF0FC),
                child: Icon(Icons.shield_outlined, size: 34, color: _accent),
              ),
              const SizedBox(height: 20),
              Text(
                '以 Email 驗證碼開啟查核',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '驗證碼會寄到最高權限帳號已驗證的 Email，無須再次登入。通過一次即可跨店唯讀查閱。',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, height: 1.8),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy ? null : onUnlock,
                icon: const Icon(Icons.lock_open),
                label: Text(busy ? '驗證中…' : '寄送驗證碼'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, (String, IconData)> get _sections => {
    'shops/$shopId': ('店家總覽', Icons.storefront_outlined),
    'shops/$shopId/members': ('客戶資料', Icons.people_outline),
    'shops/$shopId/room_types': ('房型與房間', Icons.meeting_room_outlined),
    'shops/$shopId/room_occupancies': ('房間使用紀錄', Icons.bed_outlined),
    'bookings': ('住宿與日托訂單', Icons.calendar_month_outlined),
    'shops/$shopId/store_orders': ('商品交易', Icons.receipt_long_outlined),
    'payments': ('付款紀錄', Icons.account_balance_wallet_outlined),
    'shops/$shopId/chat_threads': ('客戶 APP 對話', Icons.forum_outlined),
    'daily_care_records': ('照護紀錄', Icons.pets_outlined),
    'action_logs': ('操作紀錄', Icons.history_outlined),
    'reviews': ('客戶評價', Icons.star_outline),
    'shop_members': ('店家人員', Icons.badge_outlined),
    'shops/$shopId/store_products': ('商品資料', Icons.shopping_bag_outlined),
    'shops/$shopId/settings': ('店家設定', Icons.settings_outlined),
  };
  Widget _navigation(BuildContext context, {required bool vertical}) {
    final entries = _sections.entries;
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '查核分類',
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (vertical)
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _navItem(entry),
              )
          else
            DropdownButton<String>(
              isExpanded: true,
              value: _sections.containsKey(path) ? path : null,
              hint: Text(inspectionCollectionLabel(path)),
              items: [
                for (final entry in entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value.$1),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null) onOpenPath(value);
                    },
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: busy ? null : onAllShops,
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('切換店家'),
          ),
        ],
      ),
    );
  }

  Widget _navItem(MapEntry<String, (String, IconData)> entry) {
    final selected =
        path == entry.key ||
        path.startsWith('${entry.key}/') && entry.key != 'shops/$shopId';
    return TextButton.icon(
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        backgroundColor: selected ? const Color(0xFFEAF0FD) : null,
        foregroundColor: selected ? _accent : _muted,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      onPressed: busy ? null : () => onOpenPath(entry.key),
      icon: Icon(entry.value.$2, size: 18),
      label: Text(entry.value.$1),
    );
  }

  Widget _customer(BuildContext context, {bool collapsible = false}) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '指定客戶，一次彙整',
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '先在客戶卡片選取，或輸入已確認的客戶識別碼。',
          style: TextStyle(color: _muted, height: 1.6),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: customerController,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: '客戶 UID／店內會員 ID',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ? null : onExport,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('彙整客戶紀錄'),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '匯出內容',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          '交易、付款與相關對話\n來源路徑、時間與內容摘要\nJSON 原始資料／文字報告',
          style: TextStyle(color: _muted, height: 1.8, fontSize: 12),
        ),
        const Divider(height: 28),
        const Text(
          '資料達上限時，報告會標示未涵蓋範圍。附件保留原始連結。',
          style: TextStyle(color: _muted, height: 1.6, fontSize: 12),
        ),
      ],
    );
    if (!collapsible) return _box(child: body);
    return _box(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(Icons.folder_zip_outlined, color: _accent),
        title: const Text(
          '客戶紀錄彙整',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: ValueListenableBuilder<TextEditingValue>(
          valueListenable: customerController,
          builder: (context, value, _) => Text(
            value.text.isEmpty ? '選取客戶後下載報告' : '已選取：${value.text}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: body,
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final needle = searchController.text.trim().toLowerCase();
    final visible = records
        .where((r) => jsonEncode(r).toLowerCase().contains(needle))
        .toList();
    String title = shopId == null
        ? '選擇查核店家'
        : (_sections[path]?.$1 ?? inspectionCollectionLabel(path));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _box(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onBack != null)
                    IconButton(
                      onPressed: busy ? null : onBack,
                      tooltip: '返回上一層',
                      icon: const Icon(Icons.arrow_back),
                    ),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  _badge('本頁 ${records.length} 筆', Icons.list_alt_outlined),
                  IconButton(
                    onPressed: busy ? null : onRefresh,
                    tooltip: '重新讀取／第一頁',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (path.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(
                  path,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: searchController,
                onChanged: onSearch,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: shopId == null ? '搜尋本頁店名、編號或地區' : '搜尋本頁姓名、訂單或對話內容',
                  helperText: '僅搜尋已載入的本頁；更多紀錄請使用下一頁。',
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),

        if (collections.isNotEmpty) ...[
          const SizedBox(height: 16),
          _box(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '相關資料',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final collection in collections)
                      ActionChip(
                        avatar: const Icon(Icons.folder_open, size: 16),
                        label: Text(inspectionCollectionLabel(collection)),
                        onPressed: busy ? null : () => onOpenPath(collection),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (busy && records.isEmpty)
          _box(
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('正在讀取查核紀錄…')),
            ),
          )
        else if (visible.isEmpty)
          _box(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(
                    Icons.search_off_outlined,
                    size: 36,
                    color: _muted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    needle.isEmpty ? '此範圍尚無現存紀錄' : '本頁沒有符合的紀錄',
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '可切換分類、重新讀取或查看下一頁。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted),
                  ),
                ],
              ),
            ),
          ),
        for (final record in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _record(context, record),
          ),
        if (onNext != null)
          _box(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              children: [
                const Text(
                  '尚有更多紀錄・每頁最多 50 筆',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onNext,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('下一頁'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _record(BuildContext context, Map<String, dynamic> record) {
    final source = record['path'] as String;
    final data = Map<String, dynamic>.from(record['data'] as Map);
    final isShop = shopId == null;
    final isCustomer =
        source.contains('/members/') || source.contains('/chat_threads/');
    final isMessage = source.contains('/messages/');
    final title =
        '${data['name'] ?? data['displayName'] ?? data['customerName'] ?? data['bookingCode'] ?? data['orderCode'] ?? (isMessage ? data['text'] ?? data['content'] : null) ?? source.split('/').last}';
    const technicalFields = {
      'shopId',
      'ownerUid',
      'uid',
      'userId',
      'customerUid',
      'memberId',
      'activationCodeId',
      'senderId',
      'roomId',
    };
    const shopPriority = [
      'shopCode',
      'businessType',
      'city',
      'district',
      'address',
      'phone',
      'isPublic',
      'isOpen',
      'paidUntil',
      'trialUntil',
      'entitlementSource',
      'serviceTypes',
      'bookingEnabled',
      'daycareEnabled',
      'totalRooms',
    ];
    final fields = data.entries
        .where(
          (e) =>
              e.value != null &&
              e.value != '' &&
              !['name', 'displayName', 'text', 'content'].contains(e.key) &&
              !technicalFields.contains(e.key) &&
              inspectionFieldLabel(e.key) != e.key,
        )
        .toList();
    if (isShop) {
      fields.removeWhere(
        (e) => !{'city', 'district', 'isPublic', 'isOpen'}.contains(e.key),
      );
      fields.sort((a, b) {
        final ai = shopPriority.indexOf(a.key);
        final bi = shopPriority.indexOf(b.key);
        return (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
      });
    }
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEBF0FC),
                child: Icon(
                  isShop
                      ? Icons.storefront_outlined
                      : isMessage
                      ? Icons.chat_bubble_outline
                      : Icons.description_outlined,
                  color: _accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: isMessage ? 8 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source.split('/').last,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (data['status'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _badge(
                inspectionStatusLabel(data['status']),
                Icons.circle_outlined,
              ),
            ),
          if (data['lastMessage'] != null ||
              (isMessage && data['text'] != null)) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6FC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                '${data['lastMessage'] ?? data['text']}',
                style: const TextStyle(color: _ink, height: 1.7),
              ),
            ),
          ],
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, bounds) {
                final cols = bounds.maxWidth >= 460 ? 2 : 1;
                final width = (bounds.maxWidth - (cols - 1) * 16) / cols;
                return Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children: [
                    for (final entry in fields)
                      SizedBox(
                        width: width,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inspectionFieldLabel(entry.key),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              inspectionFieldValue(entry.key, entry.value),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _ink, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          const Divider(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isShop && onOwnerPreview != null)
                FilledButton.icon(
                  onPressed: busy ? null : () => onOwnerPreview!(record),
                  icon: const Icon(Icons.dashboard_outlined, size: 18),
                  label: const Text('店主後台（唯讀）'),
                ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => onRecord(record),
                icon: Icon(
                  isShop
                      ? Icons.visibility_outlined
                      : Icons.folder_open_outlined,
                  size: 18,
                ),
                label: Text(isShop ? '資料查核與下載' : '查看詳細內容'),
              ),
              if (!isShop && isCustomer && !isMessage)
                TextButton.icon(
                  onPressed: busy ? null : () => onCustomer(record),
                  icon: const Icon(Icons.person_search_outlined, size: 18),
                  label: const Text('選為彙整客戶'),
                ),
            ],
          ),
          if (!isShop)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                '進階核對：技術編號與原始資料',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    '${data.entries.where((e) => technicalFields.contains(e.key)).map((e) => '${inspectionFieldLabel(e.key)}：${inspectionValue(e.value)}').join('\n')}\n供爭議查核時核對原始內容；一般查閱請看上方中文摘要。\n資料來源：$source',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  alignment: Alignment.centerLeft,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFF7F8FC),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(data),
                    style: const TextStyle(fontSize: 12, height: 1.6),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

Widget _box({
  required Widget child,
  Color color = Colors.white,
  EdgeInsetsGeometry padding = const EdgeInsets.all(20),
}) => Container(
  padding: padding,
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: color == Colors.white ? _line : color),
  ),
  child: child,
);
Widget _badge(String text, IconData icon, {bool dark = false}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
  decoration: BoxDecoration(
    color: dark ? const Color(0xFF354C69) : const Color(0xFFEEF3FC),
    borderRadius: BorderRadius.circular(7),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: dark ? const Color(0xFFDCE9FC) : _accent),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: dark ? Colors.white : _accent,
          ),
        ),
      ),
    ],
  ),
);

String inspectionCollectionLabel(String path) =>
    const {
      'shops': '店家',
      'members': '客戶資料',
      'bookings': '住宿與日托訂單',
      'payments': '付款紀錄',
      'chat_threads': '客戶對話',
      'messages': '對話訊息',
      'store_orders': '商品交易',
      'settings': '店家設定',
      'rooms': '房間',
      'room_types': '房型',
      'room_occupancies': '房間使用紀錄',
      'shop_members': '店家人員',
      'reviews': '客戶評價',
      'pets': '寵物資料',
      'daily_care_records': '照護紀錄',
      'action_logs': '操作紀錄',
      'announcements': '公告',
      'policies': '店家條款',
      'custom_forms': '自訂表單',
      'service_modules': '服務模組',
      'store_products': '商品',
      'member_points': '會員點數',
      'member_point_logs': '點數明細',
      'member_coupons': '優惠券',
    }[path.split('/').last] ??
    path.split('/').last;

String inspectionFieldLabel(String key) =>
    const {
      'shopCode': '店家編號',
      'shopId': '店家識別碼',
      'ownerUid': '店主帳號識別碼',
      'profileLocked': '基本資料已鎖定',
      'lockedFields': '已鎖定的欄位',
      'activationCode': '啟用碼',
      'activationCodeId': '啟用碼紀錄編號',
      'activationFreeDays': '啟用贈送天數',
      'businessType': '營業類型',
      'lockedModule': '綁定服務模組',
      'licenseNumber': '登記證號',
      'taxId': '統一編號',
      'description': '店家介紹',
      'paidUntil': '方案有效期限',
      'paidUntilDate': '方案到期日',
      'trialUntil': '試用到期日',
      'paidServiceUntil': '付費服務到期日',
      'giftUntil': '贈送服務到期日',
      'entitlementSource': '使用資格來源',
      'acceptedShopOwnerPolicyVersion': '已同意的店主條款版本',
      'acceptedShopOwnerPolicyAt': '同意店主條款時間',
      'lineUrl': 'LINE 連結',
      'igUrl': 'Instagram 連結',
      'coverUrl': '封面圖片連結',
      'businessHours': '營業時間',
      'closedDays': '公休日',
      'serviceTypes': '服務項目',
      'bookingEnabled': '開放住宿預約',
      'daycareEnabled': '開放日托預約',
      'totalRooms': '房間總數',
      'depositEnabled': '收取訂金',
      'depositAmount': '訂金金額',
      'bankName': '銀行名稱',
      'accountName': '收款戶名',
      'accountNumber': '收款帳號',
      'paymentMethods': '可用付款方式',
      'cleaningRooms': '清潔中房間數',
      'maintenanceRooms': '維修中房間數',
      'maxAdvanceBookingDays': '可提前預約天數',
      'defaultPricePerNight': '每晚預設價格',
      'blockedDates': '不開放預約日期',
      'specialPrices': '特殊日期價格',
      'planStartedAt': '方案開始時間',
      'addressSetupCompleted': '地址設定完成',
      'phoneSetupCompleted': '電話設定完成',
      'showTaxId': '顯示統一編號',
      'cash': '現金',
      'transfer': '銀行轉帳',
      'text': '訊息內容',
      'content': '內容',
      'role': '帳號身分',
      'petName': '寵物名字',
      'roomId': '房間識別碼',
      'quantity': '數量',
      'price': '價格',
      'note': '備註',
      'notes': '備註',
      'city': '縣市',
      'district': '行政區',
      'address': '地址',
      'phone': '電話',
      'email': '電子郵件',
      'status': '狀態',
      'paymentStatus': '付款狀態',
      'tags': '標籤',
      'bookingCode': '訂單編號',
      'orderCode': '交易編號',
      'userId': '客戶帳號識別碼',
      'uid': '帳號識別碼',
      'memberId': '店內會員編號',
      'customerUid': '客戶帳號識別碼',
      'customerName': '客戶姓名',
      'createdAt': '建立時間',
      'updatedAt': '更新時間',
      'paidAt': '付款時間',
      'lastMessageAt': '最近訊息時間',
      'lastMessage': '最近訊息',
      'totalAmount': '總金額',
      'amount': '金額',
      'total': '總計',
      'paymentMethod': '付款方式',
      'checkInDate': '入住日期',
      'checkOutDate': '退房日期',
      'senderType': '發送方',
      'senderId': '發送者識別碼',
      'type': '類型',
      'enabledModules': '已啟用模組',
      'isPublic': '公開狀態',
      'isOpen': '營業狀態',
      'name': '名稱',
      'displayName': '顯示名稱',
    }[key] ??
    key;

String inspectionValue(Object? value) {
  if (value == null) return '—';
  if (value is bool) return value ? '是' : '否';
  if (value is List) {
    return value.isEmpty ? '無項目' : value.map(inspectionValue).join('、');
  }
  if (value is Map) {
    return value.entries
        .map(
          (entry) =>
              '${inspectionFieldLabel('${entry.key}')}：${inspectionFieldValue('${entry.key}', entry.value)}',
        )
        .join('\n');
  }
  final text = '$value';
  if (RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(text)) {
    final date = DateTime.tryParse(text);
    if (date != null) {
      final tw = date.toUtc().add(const Duration(hours: 8));
      String two(int n) => '$n'.padLeft(2, '0');
      return '${tw.year}/${two(tw.month)}/${two(tw.day)} ${two(tw.hour)}:${two(tw.minute)}（台灣）';
    }
  }
  return text;
}

String inspectionStatusLabel(Object? status) {
  final raw = '$status';
  final label = const {
    'active': '啟用',
    'suspended': '停權',
    'pending': '待處理',
    'paid': '已付款',
    'unpaid': '未付款',
    'refunded': '已退款',
    'cancelled': '已取消',
    'completed': '已完成',
    'confirmed': '已確認',
    'archived': '已封存',
  }[raw];
  return label ?? raw;
}

/// Translate only known enumerated fields; preserve names, message text and IDs.
String inspectionFieldValue(String key, Object? value) {
  if (value is bool) {
    const labels = {
      'isPublic': ['未公開', '公開中'],
      'isOpen': ['休息中', '營業中'],
      'bookingEnabled': ['未開放', '開放預約'],
      'daycareEnabled': ['未開放', '開放預約'],
      'profileLocked': ['尚未鎖定', '已鎖定'],
      'depositEnabled': ['不收訂金', '收取訂金'],
    };
    if (labels.containsKey(key)) return labels[key]![value ? 1 : 0];
  }
  if (key == 'lockedFields' && value is List) {
    return value.map((item) => inspectionFieldLabel('$item')).join('、');
  }
  if (const {'status', 'paymentStatus'}.contains(key)) {
    return inspectionStatusLabel(value);
  }
  if (const {
    'businessType',
    'lockedModule',
    'enabledModules',
    'serviceTypes',
    'entitlementSource',
    'paymentMethod',
    'senderType',
    'role',
  }.contains(key)) {
    const labels = {
      'cat_hotel': '貓咪旅館',
      'dog_hotel': '狗狗旅館',
      'pet_hotel': '寵物旅館',
      'grooming': '寵物美容',
      'hospital': '動物醫院',
      'pet_store': '寵物賣場',
      'overnight': '住宿',
      'daycare': '日托',
      'trial': '試用方案',
      'paid': '付費方案',
      'gift': '贈送方案',
      'activation_code': '啟用碼',
      'cash': '現金',
      'transfer': '銀行轉帳',
      'credit_card': '信用卡',
      'owner': '店主',
      'staff': '員工',
      'customer': '客戶',
      'member': '會員',
      'admin': '管理員',
      'system': '系統',
      'shop': '店家',
    };
    if (value is List) {
      return value
          .map((item) => labels['$item'] ?? inspectionValue(item))
          .join('、');
    }
    return labels['$value'] ?? inspectionValue(value);
  }
  return inspectionValue(value);
}
