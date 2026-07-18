import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [bytes] to a temporary file named [filename] and opens the system
/// share sheet (WhatsApp, Gmail, Google Drive, …). Used to send report PDFs to
/// the CA and to export the sales backup off the device.
Future<void> shareBytes(
  List<int> bytes, {
  required String filename,
  String? subject,
  String? text,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, filename));
  await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
  await Share.shareXFiles(
    [XFile(file.path)],
    subject: subject,
    text: text,
  );
}
