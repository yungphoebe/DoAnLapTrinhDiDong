import 'dart:io';

Future<void> deleteCapture(String path) async {
  await File(path).delete();
}
