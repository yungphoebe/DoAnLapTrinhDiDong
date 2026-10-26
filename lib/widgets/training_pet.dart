import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui.dart';

class TrainingPet extends StatefulWidget {
  const TrainingPet(
      {super.key,
      required this.message,
      required this.trained,
      required this.onStart,
      required this.onSettings,
      this.roast = false,
      this.progressKnown = true});

  final String message;
  final bool trained, roast, progressKnown;
  final VoidCallback onStart, onSettings;

  @override
  State<TrainingPet> createState() => _TrainingPetState();
}

class _TrainingPetState extends State<TrainingPet> {
  bool _speaking = true;
  bool _greeting = true;
  Timer? _greetingTimer;

  @override
  void initState() {
    super.initState();
    _greetingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _greeting = false);
    });
  }

  PetMood get _mood {
    if (!_speaking) return PetMood.idle;
    if (!widget.progressKnown) return PetMood.greeting;
    if (widget.trained) return PetMood.celebrating;
    if (_greeting) return PetMood.greeting;
    return widget.roast ? PetMood.teasing : PetMood.reminding;
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(TrainingPet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.trained && widget.trained) _speaking = true;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(288, math.max(0, constraints.maxWidth - 24)),
                maxHeight: math.max(0, constraints.maxHeight - 24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_speaking)
                    Flexible(
                      child: Material(
                        color: const Color(0xFFFFF8EE),
                        elevation: 8,
                        shadowColor: Colors.black54,
                        borderRadius: BorderRadius.circular(22),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 10, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Expanded(
                                    child: Text('GYM BUDDY',
                                        style: TextStyle(
                                            color: Color(0xFF7325C4),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            letterSpacing: 1))),
                                IconButton(
                                  tooltip: 'Thu gọn lời nhắc',
                                  onPressed: () =>
                                      setState(() => _speaking = false),
                                  icon: const Icon(Icons.close,
                                      size: 18, color: Color(0xFF63576D)),
                                ),
                              ]),
                              Semantics(
                                  liveRegion: true,
                                  child: Text(widget.message,
                                      style: const TextStyle(
                                          color: Color(0xFF30213D),
                                          fontSize: 14,
                                          height: 1.4))),
                              const SizedBox(height: 8),
                              Wrap(spacing: 4, runSpacing: 4, children: [
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: GymColors.purple,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(48, 48)),
                                  onPressed: () {
                                    setState(() => _speaking = false);
                                    widget.onStart();
                                  },
                                  child: Text(widget.trained
                                      ? 'Xem buổi tập'
                                      : 'Tập ngay'),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF7325C4)),
                                  onPressed: widget.onSettings,
                                  child: const Text('Chỉnh giọng bot'),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_speaking)
                    Padding(
                      padding: const EdgeInsets.only(right: 48),
                      child: ClipPath(
                        clipper: _BubbleTail(),
                        child: const SizedBox(
                            width: 16,
                            height: 10,
                            child: ColoredBox(color: Color(0xFFFFF8EE))),
                      ),
                    ),
                  Tooltip(
                    message: 'Trò chuyện với GYM BUDDY',
                    child: Semantics(
                      button: true,
                      expanded: _speaking,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(40),
                        onTap: () => setState(() => _speaking = !_speaking),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey((_speaking, widget.trained)),
                          tween: Tween(begin: 0.8, end: 1),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 500),
                          curve: Curves.easeOutBack,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: GymMascot(mood: _mood),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _BubbleTail extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(size.width, 0)
    ..lineTo(size.width / 2, size.height)
    ..close();
  @override
  bool shouldReclip(_BubbleTail oldClipper) => false;
}

enum PetMood { idle, greeting, reminding, teasing, celebrating }

class GymMascot extends StatefulWidget {
  const GymMascot({super.key, required this.mood});
  final PetMood mood;

  @override
  State<GymMascot> createState() => _GymMascotState();
}

class _GymMascotState extends State<GymMascot> with WidgetsBindingObserver {
  Timer? _frames;
  int _frame = 0;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePlayback();
  }

  @override
  void didUpdateWidget(GymMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) _frame = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updatePlayback();
  }

  void _updatePlayback() {
    _frames?.cancel();
    if (!_foreground ||
        !TickerMode.valuesOf(context).enabled ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _frames = Timer.periodic(const Duration(milliseconds: 220), (_) {
      if (mounted) setState(() => _frame = (_frame + 1) % 4);
    });
  }

  @override
  void dispose() {
    _frames?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 112,
        height: 112,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 448,
            maxWidth: 448,
            minHeight: 560,
            maxHeight: 560,
            child: Transform.translate(
              key: const Key('fox-sprite-frame'),
              offset: Offset(-112.0 * _frame, -112.0 * widget.mood.index),
              child: Image.asset('assets/images/gym_fox_sprites.png',
                  width: 448,
                  height: 560,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true),
            ),
          ),
        ),
      );
}
