// lib/features/shop/widgets/floating_contact_button.dart
// 📞 前台共用浮動聯絡按鈕
// 功能：讀取店家的浮動聯絡設定，自動顯示電話、LINE、Facebook
// 或 Instagram，支援三種按鈕尺寸、拖曳、邊界限制與左右吸附動畫，
// 並避免拖曳完成後誤觸聯絡方式，供 Classic、Modern
// 與未來模板共同使用。

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_customer_chat_page.dart';
import 'package:url_launcher/url_launcher.dart';

class FloatingContactButton extends StatefulWidget {
  const FloatingContactButton({
    super.key,
    required this.shop,
    required this.shopId,
  });

  /// 店家資料
  final Map<String, dynamic> shop;

  /// 目前店家 ID
  final String shopId;

  @override
  State<FloatingContactButton> createState() => _FloatingContactButtonState();
}

class _FloatingContactButtonState extends State<FloatingContactButton> {
  /// 按鈕與畫面邊緣的安全距離
  static const double _screenPadding = 12;

  /// 目前按鈕的左側位置
  double? _left;

  /// 目前按鈕的頂部位置
  double? _top;

  /// 是否正在拖曳
  bool _isDragging = false;

  /// 本次手勢是否真的有移動按鈕
  bool _didDrag = false;

  /// 取得店家的浮動聯絡按鈕設定
  Map<String, dynamic> get _setting {
    final rawSetting = widget.shop['floatingContactButton'];

    return rawSetting is Map
        ? Map<String, dynamic>.from(rawSetting)
        : <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ShopChatService.isFloatingEnabled(widget.shop);
    if (!enabled) {
      return const SizedBox.shrink();
    }

    final String contactType = ShopChatService.resolvedFloatingType(
      widget.shop,
    );
    final bool isChat = contactType == ShopChatService.floatingTypePetnestChat;
    final contact = isChat ? null : _resolveContact(_setting);

    if (!isChat && contact == null) {
      return const SizedBox.shrink();
    }

    final String tooltip = _resolveLabel(contactType);

    /// 依照後台設定取得按鈕尺寸。
    ///
    /// 舊資料沒有 size 或資料錯誤時，
    /// 自動使用 medium。
    final buttonStyle = _resolveButtonStyle(_setting);

    final buttonSize = buttonStyle.buttonSize;
    final iconSize = buttonStyle.iconSize;

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    /// 按鈕最右側可移動位置。
    final maxLeft = (screenSize.width - buttonSize - _screenPadding)
        .clamp(_screenPadding, double.infinity)
        .toDouble();

    /// 按鈕最下方可移動位置。
    final maxTop =
        (screenSize.height -
                mediaQuery.padding.top -
                mediaQuery.padding.bottom -
                buttonSize -
                _screenPadding)
            .clamp(_screenPadding, double.infinity)
            .toDouble();

    /// 每次重新進入頁面時，預設靠右。
    final defaultLeft = maxLeft;

    /// 每次重新進入頁面時，預設位於畫面約 68% 高度。
    final defaultTop = (screenSize.height * 0.68)
        .clamp(_screenPadding, maxTop)
        .toDouble();

    /// 確保按鈕不會超出目前畫面範圍。
    final safeLeft = (_left ?? defaultLeft)
        .clamp(_screenPadding, maxLeft)
        .toDouble();

    final safeTop = (_top ?? defaultTop)
        .clamp(_screenPadding, maxTop)
        .toDouble();

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: safeLeft,
      top: safeTop,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        /// 開始拖曳時關閉吸附動畫。
        onPanStart: (_) {
          setState(() {
            _isDragging = true;
            _didDrag = false;
          });
        },

        /// 拖曳時持續更新按鈕位置。
        onPanUpdate: (details) {
          setState(() {
            if (details.delta.distance > 0) {
              _didDrag = true;
            }

            _left = (safeLeft + details.delta.dx)
                .clamp(_screenPadding, maxLeft)
                .toDouble();

            _top = (safeTop + details.delta.dy)
                .clamp(_screenPadding, maxTop)
                .toDouble();
          });
        },

        /// 放開後平滑吸附到左側或右側。
        onPanEnd: (_) {
          final currentLeft = _left ?? safeLeft;
          final currentTop = _top ?? safeTop;

          final buttonCenter = currentLeft + (buttonSize / 2);
          final screenCenter = screenSize.width / 2;

          setState(() {
            _isDragging = false;

            _left = buttonCenter < screenCenter ? _screenPadding : maxLeft;

            _top = currentTop.clamp(_screenPadding, maxTop).toDouble();
          });
        },

        /// 拖曳意外中斷時恢復吸附動畫。
        onPanCancel: () {
          setState(() {
            _isDragging = false;
          });
        },

        child: Tooltip(
          message: tooltip,
          child: Semantics(
            button: true,
            label: tooltip,
            child: Material(
              color: isChat
                  ? const Color(0xFFFF8A00)
                  : contact!.backgroundColor,
              elevation: 6,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  /// 本次手勢曾經拖曳過，就不開啟聯絡方式。
                  if (_didDrag) {
                    _didDrag = false;
                    return;
                  }

                  if (isChat) {
                    _openChat(context);
                    return;
                  }

                  _openContact(context, contact!);
                },
                child: SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: isChat
                      ? _ChatButtonFace(
                          shopId: widget.shopId,
                          iconSize: iconSize,
                        )
                      : Center(
                          child: FaIcon(
                            contact!.icon,
                            size: iconSize,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resolveLabel(String contactType) {
    final String custom = (_setting['label'] ?? '').toString().trim();
    if (custom.isNotEmpty) {
      return custom;
    }
    return ShopChatService.defaultLabelForType(contactType);
  }

  /// 根據後台設定取得按鈕與圖示尺寸。
  ///
  /// small：
  /// 按鈕 44 px、圖示 19 px
  ///
  /// medium：
  /// 按鈕 52 px、圖示 22 px
  ///
  /// large：
  /// 按鈕 58 px、圖示 25 px
  _FloatingButtonStyle _resolveButtonStyle(Map<String, dynamic> setting) {
    final sizeType = (setting['size'] ?? 'medium').toString().trim();

    switch (sizeType) {
      case 'small':
        return const _FloatingButtonStyle(buttonSize: 44, iconSize: 19);

      case 'large':
        return const _FloatingButtonStyle(buttonSize: 58, iconSize: 25);

      case 'medium':
      default:
        return const _FloatingButtonStyle(buttonSize: 52, iconSize: 22);
    }
  }

  /// 根據後台選擇的聯絡方式取得實際資料。
  ///
  /// 若選擇的聯絡方式後來被店家刪除，
  /// 自動改用第一個仍然有效的聯絡方式。
  _FloatingContactData? _resolveContact(Map<String, dynamic> setting) {
    final selectedType = (setting['type'] ?? '').toString().trim();

    final contacts = <_FloatingContactData>[
      _FloatingContactData(
        type: 'phone',
        value: (widget.shop['phone'] ?? '').toString().trim(),
        icon: FontAwesomeIcons.phone,
        backgroundColor: const Color(0xFFEF5350),
      ),
      _FloatingContactData(
        type: 'line',
        value: (widget.shop['lineUrl'] ?? '').toString().trim(),
        icon: FontAwesomeIcons.line,
        backgroundColor: const Color(0xFF06C755),
      ),
      _FloatingContactData(
        type: 'facebook',
        value: (widget.shop['fbUrl'] ?? '').toString().trim(),
        icon: FontAwesomeIcons.facebookF,
        backgroundColor: const Color(0xFF1877F2),
      ),
      _FloatingContactData(
        type: 'instagram',
        value: (widget.shop['igUrl'] ?? '').toString().trim(),
        icon: FontAwesomeIcons.instagram,
        backgroundColor: const Color(0xFFE1306C),
      ),
    ].where((contact) => contact.value.isNotEmpty).toList();

    if (contacts.isEmpty) {
      return null;
    }

    /// 優先使用後台選擇的聯絡方式。
    for (final contact in contacts) {
      if (contact.type == selectedType) {
        return contact;
      }
    }

    /// 原本選擇的聯絡資料已不存在時，
    /// 自動改用第一個仍然有效的聯絡方式。
    return contacts.first;
  }

  Future<void> _openChat(BuildContext context) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final bool? goLogin = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('登入會員後即可與店家聊天'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('登入'),
              ),
            ],
          );
        },
      );
      if (goLogin == true && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LoginPage(redirectShopId: widget.shopId),
          ),
        );
      }
      return;
    }

    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShopCustomerChatPage(
          shopId: widget.shopId,
          shopName: (widget.shop['name'] ?? '').toString(),
          shopLogoUrl: (widget.shop['logoUrl'] ?? '').toString(),
        ),
      ),
    );
  }

  /// 開啟店家聯絡方式。
  Future<void> _openContact(
    BuildContext context,
    _FloatingContactData contact,
  ) async {
    try {
      final Uri uri;

      if (contact.type == 'phone') {
        final cleanPhone = contact.value.replaceAll(RegExp(r'\s+'), '');

        uri = Uri(scheme: 'tel', path: cleanPhone);
      } else {
        uri = _normalizeExternalUri(contact.value);
      }

      final launched = await launchUrl(
        uri,
        mode: contact.type == 'phone'
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        _showOpenFailedMessage(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showOpenFailedMessage(context);
      }
    }
  }

  /// 相容店家只填 www 或沒有 https:// 的舊資料。
  Uri _normalizeExternalUri(String value) {
    final cleanValue = value.trim();

    final hasScheme =
        cleanValue.startsWith('http://') ||
        cleanValue.startsWith('https://') ||
        cleanValue.startsWith('line://') ||
        cleanValue.startsWith('fb://') ||
        cleanValue.startsWith('instagram://');

    if (hasScheme) {
      return Uri.parse(cleanValue);
    }

    return Uri.parse('https://$cleanValue');
  }

  /// 顯示無法開啟聯絡方式的提示。
  void _showOpenFailedMessage(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('目前無法開啟聯絡方式，請稍後再試')));
  }
}

/// 浮動聯絡按鈕尺寸資料
class _FloatingButtonStyle {
  const _FloatingButtonStyle({
    required this.buttonSize,
    required this.iconSize,
  });

  /// 圓形按鈕直徑
  final double buttonSize;

  /// 聯絡方式圖示大小
  final double iconSize;
}

class _ChatButtonFace extends StatefulWidget {
  const _ChatButtonFace({required this.shopId, required this.iconSize});

  final String shopId;
  final double iconSize;

  @override
  State<_ChatButtonFace> createState() => _ChatButtonFaceState();
}

class _ChatButtonFaceState extends State<_ChatButtonFace> {
  late final Stream<int> _unreadStream;

  @override
  void initState() {
    super.initState();
    final User? user = FirebaseAuth.instance.currentUser;
    _unreadStream = user == null
        ? Stream<int>.value(0)
        : ShopChatService.instance.watchCustomerUnread(
            shopId: widget.shopId,
            customerUid: user.uid,
            source: 'FloatingChatButton',
          );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadStream,
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        final String badge = ShopChatService.badgeLabel(snapshot.data ?? 0);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: <Widget>[
            Icon(
              Icons.chat_bubble_outline,
              size: widget.iconSize,
              color: Colors.white,
            ),
            if (badge.isNotEmpty)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  child: Text(
                    badge,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 浮動聯絡方式資料
class _FloatingContactData {
  const _FloatingContactData({
    required this.type,
    required this.value,
    required this.icon,
    required this.backgroundColor,
  });

  final String type;
  final String value;
  final FaIconData icon;
  final Color backgroundColor;
}
