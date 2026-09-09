// 檔案名稱：lib/core/widgets/booking_payment_proof_button.dart
// 功能說明：住宿／安親共用：查看付款回傳照片（相容舊欄位，失敗顯示空狀態）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_payment_methods.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class BookingPaymentProof {
  BookingPaymentProof._();

  static const List<String> urlKeys = <String>[
    'transferImageUrl',
    'transferScreenshotUrl',
    'transferProofUrl',
    'paymentProofUrl',
    'paymentImageUrl',
    'depositImageUrl',
    'depositProofUrl',
  ];

  static const List<String> listKeys = <String>[
    'transferImageUrls',
    'paymentProofUrls',
  ];

  static List<String> urls(Map<String, dynamic> data) {
    final List<String> out = <String>[];
    void add(String value) {
      final String text = value.trim();
      if (text.isEmpty || out.contains(text)) {
        return;
      }
      out.add(text);
    }

    for (final String key in urlKeys) {
      add(SafeParse.parseString(data[key]));
    }
    for (final String key in listKeys) {
      final dynamic raw = data[key];
      if (raw is List) {
        for (final dynamic item in raw) {
          add(item?.toString() ?? '');
        }
      }
    }
    return out;
  }

  static bool shouldShow(Map<String, dynamic> data) {
    return ShopPaymentMethods.isManualBankTransferPayment(
      data['paymentMethod'],
    );
  }
}

class BookingPaymentProofButton extends StatelessWidget {
  const BookingPaymentProofButton({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    if (!BookingPaymentProof.shouldShow(data)) {
      return const SizedBox.shrink();
    }
    final List<String> urls = BookingPaymentProof.urls(data);
    return OutlinedButton.icon(
      onPressed: () => _open(context, urls),
      icon: const Icon(Icons.photo_outlined, size: 18),
      label: const Text('查看付款回傳照片'),
    );
  }

  Future<void> _open(BuildContext context, List<String> urls) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
                  child: Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          '付款回傳照片',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: '關閉',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: urls.isEmpty
                      ? const Center(child: Text('尚無付款回傳照片'))
                      : PageView.builder(
                          itemCount: urls.length,
                          itemBuilder: (BuildContext context, int index) {
                            return InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 4,
                              child: Image.network(
                                urls[index],
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (
                                      BuildContext context,
                                      Object error,
                                      StackTrace? stack,
                                    ) {
                                      return const Center(
                                        child: Text('無法載入付款回傳照片'),
                                      );
                                    },
                              ),
                            );
                          },
                        ),
                ),
                if (urls.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '共 ${urls.length} 張，左右滑動切換',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
