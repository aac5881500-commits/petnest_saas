// lib/features/shop/pages/shop_policy_view_page.dart
// 📜 前台條款頁（兩頁完整版🔥）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopPolicyViewPage extends StatefulWidget {
  const ShopPolicyViewPage({
    super.key,
    required this.shopId,
    required this.theme,
    this.readOnly = false,
    this.serviceType = PolicyApplicableService.accommodation,
  });

  final String shopId;
  final HomeThemeModel theme;
  final bool readOnly;
  final String serviceType;

  @override
  State<ShopPolicyViewPage> createState() => _ShopPolicyViewPageState();
}

class _ShopPolicyViewPageState extends State<ShopPolicyViewPage> {
  bool _loading = true;

  Map<String, dynamic> _sections = {};
  Map<String, bool> _enabled = {};
  List<String> _customPoliciesPage1 = [];
  List<String> _customPoliciesPage2 = [];
  int _version = 1;

  bool _isChecked = false;
  bool _scrolledToBottom = false;
  int _step = 0; // 0=第一頁 1=第二頁

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();

    if (widget.readOnly) {
      _scrolledToBottom = true;
    }
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;

      final max = _scrollController.position.maxScrollExtent;

      if (widget.readOnly) {
        return;
      }

      if (max <= 0) {
        setState(() {
          _scrolledToBottom = true;
        });
      }

      if (_scrollController.position.pixels >= max - 20) {
        if (!widget.readOnly && !_scrolledToBottom) {
          setState(() {
            _scrolledToBottom = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await ShopService.instance.getCheckinPolicy(widget.shopId);

    if (data != null) {
      final filtered = ShopPolicyService.instance.filterPolicyForService(
        policy: data,
        serviceType: widget.serviceType,
      );
      _sections = Map<String, dynamic>.from(filtered['sections'] ?? {});
      _enabled = Map<String, bool>.from(filtered['enabled'] ?? {});
      _customPoliciesPage1 = List<String>.from(
        filtered['customPoliciesPage1'] ?? [],
      );
      _customPoliciesPage2 = List<String>.from(
        filtered['customPoliciesPage2'] ?? [],
      );
      _version = filtered['version'] ?? 1;
    }

    setState(() {
      _loading = false;
    });

    /// 🔥 自動判斷是否需要滑動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final max = _scrollController.position.maxScrollExtent;

      if (max <= 0) {
        setState(() {
          _scrolledToBottom = true;
        });
      }
    });
  }

  Future<void> _accept() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await ShopService.instance.acceptPolicy(
      shopId: widget.shopId,
      userId: user.uid,
      serviceType: widget.serviceType,
    );

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  /// 🔹 卡片 UI
  Widget _buildCard(String title, String content) {
    if (content.trim().isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.theme.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: widget.theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              height: 1.5,
              color: widget.theme.textColor.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => widget.readOnly,
      child: Scaffold(
        backgroundColor: widget.theme.backgroundColor,
        appBar: AppBar(
          backgroundColor: widget.theme.backgroundColor,
          foregroundColor: widget.theme.textColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.serviceType == PolicyApplicableService.daycare
                    ? (_step == 0 ? '安親須知' : '退款與注意事項')
                    : (_step == 0 ? '入住須知' : '退款與注意事項'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
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

        body: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: widget.theme.primaryColor,
                ),
              )
            : Column(
                children: [
                  /// 🔥 條款內容
                  Expanded(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// =========================
                              /// 🔵 第一頁
                              /// =========================
                              if (_step == 0) ...[
                                if (_enabled['checkinTime'] == true)
                                  _buildCard(
                                    '營業時間與環境參觀時間',
                                    _sections['checkinTime'] ?? '',
                                  ),

                                if (_enabled['checkOutFlow'] == true)
                                  _buildCard(
                                    '入住與退房安排',
                                    _sections['checkOutFlow'] ?? '',
                                  ),

                                if (_enabled['basicCondition'] == true)
                                  _buildCard(
                                    '貓咪入住基本條件',
                                    _sections['basicCondition'] ?? '',
                                  ),

                                if (_enabled['ownerNotice'] == true)
                                  _buildCard(
                                    '貓咪入住前飼主應告知資訊',
                                    _sections['ownerNotice'] ?? '',
                                  ),

                                if (_enabled['checkinNotice'] == true)
                                  _buildCard(
                                    '貓咪入住須知',
                                    _sections['checkinNotice'] ?? '',
                                  ),

                                if (_enabled['facility'] == true)
                                  _buildCard(
                                    '貓厝邊提供的基本設施',
                                    _sections['facility'] ?? '',
                                  ),

                                if (_enabled['specialCase'] == true)
                                  _buildCard(
                                    '特殊情況處理',
                                    _sections['specialCase'] ?? '',
                                  ),

                                if (_enabled['activity'] == true)
                                  _buildCard(
                                    '探索活動安排',
                                    _sections['activity'] ?? '',
                                  ),

                                if (_enabled['extraNotice'] == true)
                                  _buildCard(
                                    '額外注意事項',
                                    _sections['extraNotice'] ?? '',
                                  ),
                                if (_customPoliciesPage1.isNotEmpty)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 12),
                                      Text(
                                        '其他條款',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: widget.theme.textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ..._customPoliciesPage1.map(
                                        (e) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '• ',
                                                style: TextStyle(
                                                  color:
                                                      widget.theme.primaryColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  e,
                                                  style: TextStyle(
                                                    height: 1.45,
                                                    color: widget
                                                        .theme
                                                        .textColor
                                                        .withValues(
                                                          alpha: 0.75,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],

                              /// =========================
                              /// 🔴 第二頁
                              /// =========================
                              if (_step == 1) ...[
                                if (_enabled['cancelPolicy'] == true)
                                  _buildCard(
                                    '訂房取消政策',
                                    _sections['cancelPolicy'] ?? '',
                                  ),

                                if (_customPoliciesPage2.isNotEmpty)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 12),
                                      Text(
                                        '其他條款',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: widget.theme.textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ..._customPoliciesPage2.map(
                                        (e) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '• ',
                                                style: TextStyle(
                                                  color:
                                                      widget.theme.primaryColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  e,
                                                  style: TextStyle(
                                                    height: 1.45,
                                                    color: widget
                                                        .theme
                                                        .textColor
                                                        .withValues(
                                                          alpha: 0.75,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ],
                          ),
                        ),

                        /// 🔥 滑到底提示
                        if (!widget.readOnly && !_scrolledToBottom)
                          Positioned(
                            bottom: 10,
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: widget.theme.primaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '請滑到底閱讀完整條款',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: widget.theme.textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  /// 🔥 底部操作
                  SafeArea(
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.theme.cardColor,
                        border: Border(
                          top: BorderSide(color: widget.theme.cardBorderColor),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (!widget.readOnly) ...[
                              Row(
                                children: [
                                  Checkbox(
                                    value: _isChecked,
                                    activeColor: widget.theme.primaryColor,
                                    checkColor: Colors.white,
                                    side: BorderSide(
                                      color: widget.theme.cardBorderColor,
                                    ),
                                    onChanged: (v) {
                                      setState(() {
                                        _isChecked = v ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      widget.serviceType ==
                                              PolicyApplicableService.daycare
                                          ? '我已閱讀並同意安親條款'
                                          : '我已閱讀並同意以上條款',
                                      style: TextStyle(
                                        color: widget.theme.textColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: widget
                                      .theme
                                      .primaryColor
                                      .withValues(alpha: 0.28),
                                  disabledForegroundColor: widget
                                      .theme
                                      .textColor
                                      .withValues(alpha: 0.45),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: widget.readOnly
                                    ? () {
                                        if (_step == 0) {
                                          setState(() {
                                            _step = 1;
                                          });
                                          _scrollController.jumpTo(0);
                                        } else {
                                          Navigator.pop(context);
                                        }
                                      }
                                    : (_step == 1 &&
                                          (!_isChecked || !_scrolledToBottom))
                                    ? null // 🔥 禁用按鈕
                                    : () {
                                        if (_step == 0) {
                                          setState(() {
                                            _step = 1;
                                            _isChecked = false;
                                            _scrolledToBottom = false;
                                          });

                                          _scrollController.jumpTo(0);

                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                if (!_scrollController
                                                    .hasClients)
                                                  return;

                                                final max = _scrollController
                                                    .position
                                                    .maxScrollExtent;

                                                if (max <= 0) {
                                                  setState(() {
                                                    _scrolledToBottom = true;
                                                  });
                                                }
                                              });
                                        } else {
                                          _accept();
                                        }
                                      },
                                child: Text(
                                  widget.readOnly
                                      ? (_step == 0 ? '下一步' : '關閉')
                                      : (_step == 0 ? '下一步' : '我已閱讀並同意'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
