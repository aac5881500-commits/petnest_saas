// lib/features/shop/widgets/contact_floating_button.dart
// 💬 前台共用聯絡店家懸浮按鈕
// 功能：
// - Classic / Modern 首頁共用
// - 支援拖曳與左右邊緣吸附
// - 記住每間店的按鈕位置
// - 支援 LINE、Facebook、Instagram、電話
// - 預留未來站內聊天室

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactFloatingButton extends StatefulWidget {
  const ContactFloatingButton({
    super.key,
    required this.shopId,
    required this.shop,
    required this.primaryColor,
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final Color primaryColor;

  @override
  State<ContactFloatingButton> createState() => _ContactFloatingButtonState();
}

class _ContactFloatingButtonState extends State<ContactFloatingButton> {
  static const double _buttonSize = 58;
  static const double _screenPadding = 12;

  double? _left;
  double? _top;

  bool _positionLoaded = false;

  String get _positionXKey => 'contact_floating_button_${widget.shopId}_x';

  String get _positionYKey => 'contact_floating_button_${widget.shopId}_y';

  Map<String, dynamic> get _settings {
    final rawSettings = widget.shop['floatingContactButton'];

    if (rawSettings is Map) {
      return Map<String, dynamic>.from(rawSettings);
    }

    return <String, dynamic>{};
  }

  bool get _enabled => _settings['enabled'] == true;

  String get _actionType {
    return (_settings['type'] ?? 'line').toString();
  }

  String get _label {
    final value = (_settings['label'] ?? '聯絡店家').toString().trim();
    return value.isEmpty ? '聯絡店家' : value;
  }

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();

    final savedX = prefs.getDouble(_positionXKey);
    final savedY = prefs.getDouble(_positionYKey);

    if (!mounted) return;

    setState(() {
      _left = savedX;
      _top = savedY;
      _positionLoaded = true;
    });
  }

  Future<void> _savePosition() async {
    if (_left == null || _top == null) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble(_positionXKey, _left!);
    await prefs.setDouble(_positionYKey, _top!);
  }

  Future<void> _handleTap() async {
    switch (_actionType) {
      case 'phone':
        await _openPhone();
        break;

      case 'facebook':
        await _openExternalUrl(
          (widget.shop['fbUrl'] ?? '').toString(),
          '尚未設定 Facebook 連結',
        );
        break;

      case 'instagram':
        await _openExternalUrl(
          (widget.shop['igUrl'] ?? '').toString(),
          '尚未設定 Instagram 連結',
        );
        break;

      case 'chat':
        _showMessage('店家聊天室功能尚未開放');
        break;

      case 'line':
      default:
        await _openExternalUrl(
          (widget.shop['lineUrl'] ?? '').toString(),
          '尚未設定 LINE 連結',
        );
        break;
    }
  }

  Future<void> _openPhone() async {
    final phone = (widget.shop['phone'] ?? '').toString().trim();

    if (phone.isEmpty) {
      _showMessage('尚未設定店家電話');
      return;
    }

    final uri = Uri.parse('tel:$phone');

    final opened = await launchUrl(uri);

    if (!opened && mounted) {
      _showMessage('無法開啟電話功能');
    }
  }

  Future<void> _openExternalUrl(String rawUrl, String emptyMessage) async {
    final url = rawUrl.trim();

    if (url.isEmpty) {
      _showMessage(emptyMessage);
      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null) {
      _showMessage('聯絡連結格式不正確');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      _showMessage('無法開啟聯絡連結');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildActionIcon() {
    switch (_actionType) {
      case 'phone':
        return const Icon(Icons.phone_rounded, color: Colors.white, size: 25);

      case 'facebook':
        return const FaIcon(
          FontAwesomeIcons.facebookF,
          color: Colors.white,
          size: 23,
        );

      case 'instagram':
        return const FaIcon(
          FontAwesomeIcons.instagram,
          color: Colors.white,
          size: 25,
        );

      case 'chat':
        return const Icon(
          Icons.chat_bubble_rounded,
          color: Colors.white,
          size: 25,
        );

      case 'line':
      default:
        return const FaIcon(
          FontAwesomeIcons.line,
          color: Colors.white,
          size: 27,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled || !_positionLoaded) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxLeft = (constraints.maxWidth - _buttonSize - _screenPadding)
            .clamp(_screenPadding, double.infinity)
            .toDouble();

        final maxTop = (constraints.maxHeight - _buttonSize - _screenPadding)
            .clamp(_screenPadding, double.infinity)
            .toDouble();

        final defaultLeft = maxLeft;
        final defaultTop = (constraints.maxHeight * 0.68)
            .clamp(_screenPadding, maxTop)
            .toDouble();

        final safeLeft = (_left ?? defaultLeft)
            .clamp(_screenPadding, maxLeft)
            .toDouble();

        final safeTop = (_top ?? defaultTop)
            .clamp(_screenPadding, maxTop)
            .toDouble();

        _left = safeLeft;
        _top = safeTop;

        return Stack(
          children: [
            Positioned(
              left: safeLeft,
              top: safeTop,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleTap,
                onPanUpdate: (details) {
                  setState(() {
                    _left = ((_left ?? safeLeft) + details.delta.dx)
                        .clamp(_screenPadding, maxLeft)
                        .toDouble();

                    _top = ((_top ?? safeTop) + details.delta.dy)
                        .clamp(_screenPadding, maxTop)
                        .toDouble();
                  });
                },
                onPanEnd: (_) {
                  final currentCenter = (_left ?? safeLeft) + (_buttonSize / 2);

                  final screenCenter = constraints.maxWidth / 2;

                  setState(() {
                    _left = currentCenter < screenCenter
                        ? _screenPadding
                        : maxLeft;
                  });

                  _savePosition();
                },
                child: Semantics(
                  button: true,
                  label: _label,
                  child: Container(
                    width: _buttonSize,
                    height: _buttonSize,
                    decoration: BoxDecoration(
                      color: widget.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(child: _buildActionIcon()),
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
