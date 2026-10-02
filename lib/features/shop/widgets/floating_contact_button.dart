// 檔案名稱：lib/features/shop/widgets/floating_contact_button.dart
// 功能說明：讀取店家的浮動聯絡設定，自動顯示電話、LINE、Facebook
// 📞 前台共用浮動聯絡按鈕
// 或 Instagram，支援三種按鈕尺寸、拖曳、邊界限制與左右吸附動畫，
// 並避免拖曳完成後誤觸聯絡方式，供 Classic、Modern
// 與未來模板共同使用。

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_customer_chat_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/floating_action_bounds.dart';
import 'package:url_launcher/url_launcher.dart';

class FloatingContactButton extends StatefulWidget {
  const FloatingContactButton({
    super.key,
    required this.shop,
    required this.shopId,
    this.isPreview = false,
    this.bottomReserve = 0,
    this.bottomBarHeight,
    this.headerHeight = 0,
    this.peerRect,
    this.ownRect,
  });

  /// 店家資料
  final Map<String, dynamic> shop;

  /// 目前店家 ID
  final String shopId;

  /// 外觀預覽只提示，不開啟電話或放大按鈕。
  final bool isPreview;

  /// 底部導覽與店家選單佔用的高度，按鈕會停在這段空間上方。
  /// 新版前台改走 [bottomBarHeight]；此欄位只留給經典版。
  final double bottomReserve;

  /// 傳入時改用共用浮動安全範圍。null 表示經典版沿用原本計算。
  final double? bottomBarHeight;

  final double headerHeight;
  final ValueNotifier<Rect?>? peerRect;
  final ValueNotifier<Rect?>? ownRect;

  static const Key buttonKey = ValueKey<String>('floating-contact-button');

  @override
  State<FloatingContactButton> createState() => _FloatingContactButtonState();
}

class _FloatingContactButtonState extends State<FloatingContactButton> {
  /// 按鈕與畫面邊緣的安全距離
  static const double _screenPadding = 12;

  /// 撥打電話按鈕固定直徑。其他聯絡方式也不可超過這個上限。
  static const double _phoneButtonSize = 52;
  static const double _maxButtonSize = 56;

  /// 目前按鈕的左側位置
  double? _left;

  /// 目前按鈕的頂部位置
  double? _top;

  /// 本次手勢是否真的有移動按鈕
  bool _didDrag = false;

  final GlobalKey _layerKey = GlobalKey(debugLabel: 'contact-layer');
  double? _nx;
  double? _ny;
  double? _dragX;
  double? _dragY;
  Offset _grab = Offset.zero;
  double _travel = 0;
  bool _dragging = false;
  Rect? _published;

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
    final bool isPhone = contact?.type == 'phone';
    final double buttonSize = _visualButtonSize(
      buttonStyle.buttonSize,
      phone: isPhone,
    );
    final double iconSize = isPhone ? 22 : buttonStyle.iconSize;

    if (widget.bottomBarHeight != null) {
      return _buildShared(
        buttonSize: buttonSize,
        iconSize: iconSize,
        tooltip: tooltip,
        isChat: isChat,
        contact: contact,
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    /// 按鈕最右側可移動位置。
    final maxLeft = (screenSize.width - buttonSize - _screenPadding)
        .clamp(_screenPadding, double.infinity)
        .toDouble();

    final double reservedBottom = widget.bottomReserve > 0
        ? widget.bottomReserve
        : mediaQuery.padding.bottom;

    /// 按鈕最下方可移動位置。
    final maxTop =
        (screenSize.height -
                mediaQuery.padding.top -
                buttonSize -
                _screenPadding -
                reservedBottom)
            .clamp(_screenPadding, double.infinity)
            .toDouble();

    /// 每次重新進入頁面時，預設靠右。
    final defaultLeft = maxLeft;

    /// 有底部導覽時貼在導覽列上方，否則維持原本約 68% 高度。
    final defaultTop = reservedBottom > 0
        ? maxTop
        : (screenSize.height * 0.68).clamp(_screenPadding, maxTop).toDouble();

    /// 確保按鈕不會超出目前畫面範圍。
    final safeLeft = (_left ?? defaultLeft)
        .clamp(_screenPadding, maxLeft)
        .toDouble();

    final safeTop = (_top ?? defaultTop)
        .clamp(_screenPadding, maxTop)
        .toDouble();

    return Stack(
      children: <Widget>[
        Positioned(
          left: safeLeft,
          top: safeTop,
          width: buttonSize,
          height: buttonSize,
          child: _buildFace(
            buttonSize: buttonSize,
            iconSize: iconSize,
            tooltip: tooltip,
            isChat: isChat,
            contact: contact,
            safeLeft: safeLeft,
            safeTop: safeTop,
            maxLeft: maxLeft,
            maxTop: maxTop,
            screenWidth: screenSize.width,
          ),
        ),
      ],
    );
  }

  Widget _buildShared({
    required double buttonSize,
    required double iconSize,
    required String tooltip,
    required bool isChat,
    required _FloatingContactData? contact,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double bar = widget.bottomBarHeight ?? 0;
        final FloatingActionBounds bounds = FloatingActionBounds.resolve(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          padding: MediaQuery.paddingOf(context),
          headerHeight: widget.headerHeight,
          showBottomBar: bar > 0,
          bottomBarHeight: bar,
          buttonSize: Size.square(buttonSize),
        );
        final Offset pos = _sharedPosition(bounds, bar > 0);
        _publishContact(Rect.fromLTWH(pos.dx, pos.dy, buttonSize, buttonSize));
        return Stack(
          key: _layerKey,
          fit: StackFit.expand,
          children: <Widget>[
            Positioned(
              left: pos.dx,
              top: pos.dy,
              width: buttonSize,
              height: buttonSize,
              child: _buildFace(
                buttonSize: buttonSize,
                iconSize: iconSize,
                tooltip: tooltip,
                isChat: isChat,
                contact: contact,
                safeLeft: pos.dx,
                safeTop: pos.dy,
                maxLeft: bounds.maxX,
                maxTop: bounds.maxY,
                screenWidth: constraints.maxWidth,
                bounds: bounds,
              ),
            ),
          ],
        );
      },
    );
  }

  Offset _sharedPosition(FloatingActionBounds bounds, bool barShown) {
    if (_dragging && _dragX != null && _dragY != null) {
      return Offset(_dragX!, _dragY!);
    }
    if (_nx == null || _ny == null) {
      final double y = barShown
          ? bounds.maxY
          : (bounds.minY + (bounds.maxY - bounds.minY) * 0.68)
                .clamp(bounds.minY, bounds.maxY)
                .toDouble();
      return Offset(bounds.maxX, y);
    }
    return Offset(bounds.denormX(_nx!), bounds.denormY(_ny!));
  }

  void _publishContact(Rect? rect) {
    if (_published == rect) {
      return;
    }
    _published = rect;
    final ValueNotifier<Rect?>? own = widget.ownRect;
    if (own == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || own.value == rect) {
        return;
      }
      own.value = rect;
    });
  }

  /// 設定值再大也維持小型圓鈕，避免被父層撐成全螢幕。
  double _visualButtonSize(double requested, {required bool phone}) {
    if (phone) {
      return _phoneButtonSize;
    }
    if (requested > _maxButtonSize) {
      return _maxButtonSize;
    }
    return requested;
  }

  Widget _buildFace({
    required double buttonSize,
    required double iconSize,
    required String tooltip,
    required bool isChat,
    required _FloatingContactData? contact,
    required double safeLeft,
    required double safeTop,
    required double maxLeft,
    required double maxTop,
    required double screenWidth,
    FloatingActionBounds? bounds,
  }) {
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        if (bounds == null) {
          return;
        }
        final RenderBox? layer =
            _layerKey.currentContext?.findRenderObject() as RenderBox?;
        if (layer == null) {
          return;
        }
        final Offset local = layer.globalToLocal(event.position);
        _grab = local - Offset(safeLeft, safeTop);
        _travel = 0;
        _dragging = true;
        _didDrag = false;
        _dragX = safeLeft;
        _dragY = safeTop;
      },
      onPointerMove: (PointerMoveEvent event) {
        if (bounds == null) {
          return;
        }
        final RenderBox? layer =
            _layerKey.currentContext?.findRenderObject() as RenderBox?;
        if (layer == null) {
          return;
        }
        _travel += event.delta.distance;
        if (_travel < FloatingActionBounds.dragSlop) {
          return;
        }
        final Offset local = layer.globalToLocal(event.position);
        final Offset next = bounds.clampPoint(local - _grab);
        setState(() {
          _didDrag = true;
          _dragX = next.dx;
          _dragY = next.dy;
        });
      },
      onPointerUp: (_) {
        if (bounds == null) {
          return;
        }
        _finishContactDrag(bounds, safeLeft, safeTop, buttonSize);
      },
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,

      /// 開始拖曳時關閉吸附動畫。
      onPanStart: (DragStartDetails details) {
        if (bounds != null) {
          return;
        }
        setState(() {
          _didDrag = false;
        });
      },

      /// 拖曳時持續更新按鈕位置。
      onPanUpdate: (DragUpdateDetails details) {
        if (bounds != null) {
          return;
        }
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

      /// 放開後吸附到左側或右側。
      onPanEnd: (_) {
        if (bounds != null) {
          return;
        }
        final currentLeft = _left ?? safeLeft;
        final currentTop = _top ?? safeTop;

        final buttonCenter = currentLeft + (buttonSize / 2);
        final screenCenter = screenWidth / 2;

        setState(() {
          _left = buttonCenter < screenCenter ? _screenPadding : maxLeft;

          _top = currentTop.clamp(_screenPadding, maxTop).toDouble();
        });
      },

      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: Material(
            key: FloatingContactButton.buttonKey,
            color: isChat ? const Color(0xFFFF8A00) : contact!.backgroundColor,
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

                if (widget.isPreview) {
                  _showPreviewMessage(
                    context,
                    isChat
                        ? '預覽模式不會開啟聊天'
                        : contact?.type == 'phone'
                        ? '預覽模式不會撥打電話'
                        : '預覽模式不會開啟聯絡方式',
                  );
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
                    ? _ChatButtonFace(shopId: widget.shopId, iconSize: iconSize)
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

  void _finishContactDrag(
    FloatingActionBounds bounds,
    double originX,
    double originY,
    double buttonSize,
  ) {
    final bool dragged = _travel >= FloatingActionBounds.dragSlop;
    final Offset current = Offset(_dragX ?? originX, _dragY ?? originY);
    final Offset placed = dragged
        ? bounds.placeOnRelease(
            current,
            Size.square(buttonSize),
            peer: widget.peerRect?.value,
            preferLeft: false,
          )
        : Offset(originX, originY);
    setState(() {
      _dragging = false;
      _dragX = null;
      _dragY = null;
      _didDrag = dragged;
      if (dragged) {
        _nx = bounds.normX(placed.dx);
        _ny = bounds.normY(placed.dy);
      }
    });
  }

  void _showPreviewMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
  /// 按鈕 56 px、圖示 24 px。撥打電話固定 52 px。
  _FloatingButtonStyle _resolveButtonStyle(Map<String, dynamic> setting) {
    final sizeType = (setting['size'] ?? 'medium').toString().trim();

    switch (sizeType) {
      case 'small':
        return const _FloatingButtonStyle(buttonSize: 44, iconSize: 19);

      case 'large':
        return const _FloatingButtonStyle(buttonSize: 56, iconSize: 24);

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
