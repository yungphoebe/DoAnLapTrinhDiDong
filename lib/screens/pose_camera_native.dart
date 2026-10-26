import 'dart:io';

import 'package:flutter/material.dart';

import 'camera.dart';
import 'pose_camera_mobile.dart';
import '../models/workout.dart';

class PoseCameraScreen extends StatelessWidget {
  const PoseCameraScreen({super.key, this.exercise});

  final Exercise? exercise;

  @override
  Widget build(BuildContext context) {
    // ML Kit pose detection exists only on Android/iOS; Windows keeps LM Studio.
    if (Platform.isAndroid || Platform.isIOS) {
      return MobilePoseCameraScreen(exercise: exercise);
    }
    return CameraScreen(exercise: exercise);
  }
}
