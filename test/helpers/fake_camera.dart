import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';

class FakeCamera extends CameraPlatform {
  bool denied = false;
  bool noCamera = false;
  int opened = 0;
  int released = 0;
  bool? audioEnabled;
  Completer<void>? opening;
  Completer<XFile>? picture;
  Future<XFile> Function()? capture;
  int captures = 0;
  final errors = StreamController<CameraErrorEvent>.broadcast();

  @override
  Future<List<CameraDescription>> availableCameras() async => noCamera
      ? []
      : [
          const CameraDescription(
            name: 'webcam',
            lensDirection: CameraLensDirection.front,
            sensorOrientation: 0,
          ),
        ];

  @override
  Future<int> createCamera(
    CameraDescription description,
    ResolutionPreset? preset, {
    bool enableAudio = false,
  }) async {
    audioEnabled = enableAudio;
    if (denied) throw CameraException('CameraAccessDenied', 'denied');
    opened++;
    return opened;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    await opening?.future;
  }

  @override
  Future<XFile> takePicture(int cameraId) {
    captures++;
    return capture?.call() ?? picture!.future;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          640,
          480,
          ExposureMode.auto,
          false,
          FocusMode.auto,
          false,
        ),
      );

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => errors.stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  Widget buildPreview(int cameraId) =>
      const ColoredBox(color: Color(0xff333333));

  @override
  Future<void> dispose(int cameraId) async {
    if (cameraId > 0) released++;
  }
}
