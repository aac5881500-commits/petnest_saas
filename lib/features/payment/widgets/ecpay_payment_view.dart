// lib/features/payment/widgets/ecpay_payment_view.dart
// 💳 綠界付款內容平台分流
// 功能：Web 使用 iframe，Android／iOS 使用原生 WebView。

export 'ecpay_payment_view_mobile.dart'
    if (dart.library.html) 'ecpay_payment_view_web.dart';
