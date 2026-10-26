import 'package:flutter/material.dart';

import 'camera.dart';
import '../models/workout.dart';

class PoseCameraScreen extends StatelessWidget {
  const PoseCameraScreen({super.key, this.exercise});

  final Exercise? exercise;

  @override
  Widget build(BuildContext context) {
    return CameraScreen(exercise: exercise);
  }
}
