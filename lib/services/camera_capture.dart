import 'dart:typed_data';

import 'package:camera/camera.dart';

import 'camera_capture_stub.dart'
    if (dart.library.io) 'camera_capture_io.dart'
    if (dart.library.js_interop) 'camera_capture_web.dart'
    as storage;

Future<Uint8List> captureCameraFrame(CameraController controller) async {
  final image = await controller.takePicture();
  try {
    return await image.readAsBytes();
  } finally {
    await storage.deleteCapture(image.path);
  }
}
