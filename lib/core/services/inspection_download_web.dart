import 'package:universal_html/html.dart' as html;

Future<void> downloadInspection(
  String text, {
  String filename = 'petnest_inspection.json',
}) async {
  final url = html.Url.createObjectUrlFromBlob(
    html.Blob([text], 'application/json;charset=utf-8'),
  );
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}
