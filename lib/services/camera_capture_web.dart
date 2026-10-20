import 'package:web/web.dart' as web;

Future<void> deleteCapture(String path) async {
  web.URL.revokeObjectURL(path);
}
