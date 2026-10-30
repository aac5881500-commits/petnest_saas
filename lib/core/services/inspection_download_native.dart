import 'package:share_plus/share_plus.dart';

Future<void> downloadInspection(
  String text, {
  String filename = 'petnest_inspection.json',
}) async {
  await Share.share(text, subject: 'PetNest 客戶查核紀錄');
}
