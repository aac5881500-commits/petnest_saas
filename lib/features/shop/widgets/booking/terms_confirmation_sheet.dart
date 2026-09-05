// 檔案名稱：lib/features/shop/widgets/booking/terms_confirmation_sheet.dart
// 功能說明：條款確認 Bottom Sheet（閱讀到底才可完成確認）

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';

Future<bool?> showTermsConfirmationSheet({
  required BuildContext context,
  required String shopId,
  required HomeThemeModel theme,
  required String serviceType,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: theme.backgroundColor,
    builder: (BuildContext context) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          child: _TermsConfirmationSheetBody(
            shopId: shopId,
            theme: theme,
            serviceType: serviceType,
          ),
        ),
      );
    },
  );
}

class _TermsConfirmationSheetBody extends StatefulWidget {
  const _TermsConfirmationSheetBody({
    required this.shopId,
    required this.theme,
    required this.serviceType,
  });

  final String shopId;
  final HomeThemeModel theme;
  final String serviceType;

  @override
  State<_TermsConfirmationSheetBody> createState() =>
      _TermsConfirmationSheetBodyState();
}

class _TermsConfirmationSheetBodyState
    extends State<_TermsConfirmationSheetBody> {
  bool _loading = true;
  bool _isChecked = false;
  bool _scrolledToBottom = false;
  int _step = 0;
  int _version = 1;

  Map<String, dynamic> _sections = <String, dynamic>{};
  Map<String, bool> _enabled = <String, bool>{};
  List<String> _customPoliciesPage1 = <String>[];
  List<String> _customPoliciesPage2 = <String>[];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final double max = _scrollController.position.maxScrollExtent;
    if (max <= 0 && !_scrolledToBottom) {
      setState(() => _scrolledToBottom = true);
    }
    if (_scrollController.position.pixels >= max - 20 && !_scrolledToBottom) {
      setState(() => _scrolledToBottom = true);
    }
  }

  Future<void> _load() async {
    final Map<String, dynamic>? policy = await ShopPolicyService.instance
        .getCheckinPolicy(widget.shopId);
    if (policy != null) {
      final Map<String, dynamic> filtered = ShopPolicyService.instance
          .filterPolicyForService(
            policy: policy,
            serviceType: widget.serviceType,
          );
      _sections = Map<String, dynamic>.from(filtered['sections'] ?? {});
      _enabled = Map<String, bool>.from(filtered['enabled'] ?? {});
      _customPoliciesPage1 = List<String>.from(
        filtered['customPoliciesPage1'] ?? <String>[],
      );
      _customPoliciesPage2 = List<String>.from(
        filtered['customPoliciesPage2'] ?? <String>[],
      );
      _version = (filtered['version'] as num?)?.toInt() ?? 1;
    }
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      if (_scrollController.position.maxScrollExtent <= 0) {
        setState(() => _scrolledToBottom = true);
      }
    });
  }

  Future<void> _complete() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    await ShopPolicyService.instance.acceptPolicy(
      shopId: widget.shopId,
      userId: user.uid,
      serviceType: widget.serviceType,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Widget _sectionCard(String title, String content) {
    if (content.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.theme.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: widget.theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              height: 1.5,
              fontSize: 14,
              color: widget.theme.textColor.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customList(List<String> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '其他條款',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: widget.theme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (String text) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '• ',
                  style: TextStyle(
                    color: widget.theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      height: 1.45,
                      color: widget.theme.textColor.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _pageOne() {
    return <Widget>[
      if (_enabled['checkinTime'] == true)
        _sectionCard('營業時間與環境參觀時間', _sections['checkinTime']?.toString() ?? ''),
      if (_enabled['checkOutFlow'] == true)
        _sectionCard('入住與退房安排', _sections['checkOutFlow']?.toString() ?? ''),
      if (_enabled['basicCondition'] == true)
        _sectionCard('貓咪入住基本條件', _sections['basicCondition']?.toString() ?? ''),
      if (_enabled['ownerNotice'] == true)
        _sectionCard(
          '貓咪入住前飼主應告知資訊',
          _sections['ownerNotice']?.toString() ?? '',
        ),
      if (_enabled['checkinNotice'] == true)
        _sectionCard('貓咪入住須知', _sections['checkinNotice']?.toString() ?? ''),
      if (_enabled['facility'] == true)
        _sectionCard('貓厝邊提供的基本設施', _sections['facility']?.toString() ?? ''),
      if (_enabled['specialCase'] == true)
        _sectionCard('特殊情況處理', _sections['specialCase']?.toString() ?? ''),
      if (_enabled['activity'] == true)
        _sectionCard('探索活動安排', _sections['activity']?.toString() ?? ''),
      if (_enabled['extraNotice'] == true)
        _sectionCard('額外注意事項', _sections['extraNotice']?.toString() ?? ''),
      _customList(_customPoliciesPage1),
    ];
  }

  List<Widget> _pageTwo() {
    return <Widget>[
      if (_enabled['cancelPolicy'] == true)
        _sectionCard('訂房取消政策', _sections['cancelPolicy']?.toString() ?? ''),
      _customList(_customPoliciesPage2),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool isDaycare =
        widget.serviceType == PolicyApplicableService.daycare;
    final String pageTitle = isDaycare
        ? (_step == 0 ? '安親須知' : '退款與注意事項')
        : (_step == 0 ? '入住須知' : '退款與注意事項');
    final bool canProceed = _step == 0 || (_isChecked && _scrolledToBottom);

    return Material(
      color: widget.theme.backgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.theme.cardBorderColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        pageTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: widget.theme.textColor,
                        ),
                      ),
                      Text(
                        '條款版本 v$_version',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.theme.textColor.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: widget.theme.primaryColor,
                    ),
                  )
                : Stack(
                    children: <Widget>[
                      SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _step == 0 ? _pageOne() : _pageTwo(),
                        ),
                      ),
                      if (!_scrolledToBottom)
                        Positioned(
                          bottom: 8,
                          left: 16,
                          right: 16,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: widget.theme.cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: widget.theme.primaryColor.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              child: Text(
                                '請滑到底閱讀完整條款',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: widget.theme.textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              color: widget.theme.cardColor,
              border: Border(
                top: BorderSide(color: widget.theme.cardBorderColor),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: <Widget>[
                if (_step == 1) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Checkbox(
                        value: _isChecked,
                        activeColor: widget.theme.primaryColor,
                        onChanged: _scrolledToBottom
                            ? (bool? value) {
                                setState(() => _isChecked = value ?? false);
                              }
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          isDaycare ? '我已閱讀並同意安親條款' : '我已閱讀並同意以上條款',
                          style: TextStyle(color: widget.theme.textColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.theme.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: widget.theme.cardBorderColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: canProceed
                        ? () {
                            if (_step == 0) {
                              setState(() {
                                _step = 1;
                                _isChecked = false;
                                _scrolledToBottom = false;
                              });
                              _scrollController.jumpTo(0);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!_scrollController.hasClients) {
                                  return;
                                }
                                if (_scrollController
                                        .position
                                        .maxScrollExtent <=
                                    0) {
                                  setState(() => _scrolledToBottom = true);
                                }
                              });
                              return;
                            }
                            _complete();
                          }
                        : null,
                    child: Text(
                      _step == 0 ? '下一步' : '完成確認',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
