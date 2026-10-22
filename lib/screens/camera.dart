import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _paused = false;
  bool _muted = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SizedBox(
          height: math.max(constraints.maxHeight, 740),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/workout.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(.15, 0),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xB3000000),
                      Color(0x47000000),
                      Color(0xE6111111),
                    ],
                    stops: [0, .4, .88],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Quay lại',
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0x77242424),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Barbell Squat',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x99242424),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 14,
                                  color: GymColors.purple,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  '00:42',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SỐ LẦN',
                                style: TextStyle(
                                  color: Color(0xFFD4D4D4),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                ),
                              ),
                              const Text(
                                '08',
                                style: TextStyle(
                                  fontSize: 72,
                                  height: 1.12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                '/ 12 lần',
                                style: TextStyle(
                                  color: Color(0xFFB0B0B0),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xB32B2533),
                              border: Border.all(
                                color: const Color(0x665B476E),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: GymColors.purple,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'BẢN DEMO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFFDCC1F5),
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Semantics(
                              label: 'Minh họa khung xương tĩnh của động tác squat',
                              child: const CustomPaint(
                                painter: _SkeletonPainter(),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 40,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xAA171D1D),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0x554CF0DA),
                                  ),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'GÓC ĐẦU GỐI',
                                      style: TextStyle(
                                        fontSize: 8,
                                        letterSpacing: .7,
                                        color: Color(0xFFB4C1BD),
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      '92°',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF58F1DC),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_paused)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 13,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xE6111111),
                                    border: Border.all(color: GymColors.border),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    'Đã tạm dừng',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            const Positioned(
                              bottom: 14,
                              left: 0,
                              right: 0,
                              child: Text(
                                'Ảnh & chỉ số minh họa • Camera chưa được kết nối',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFFAAAAAA),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _FeedbackBanner(
                        icon: Icons.warning_amber_rounded,
                        label: 'Giữ thẳng lưng • Hông ngả sau',
                        color: const Color(0xFFFF555E),
                        background: const Color(0xD94D2026),
                      ),
                      const SizedBox(height: 9),
                      _FeedbackBanner(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Đạt độ sâu tối đa',
                        color: GymColors.green,
                        background: const Color(0xD91D3A29),
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: _muted ? 'Bật âm thanh' : 'Tắt âm thanh',
                            onPressed: () {
                              setState(() => _muted = !_muted);
                              showMessage(
                                context,
                                _muted ? 'Đã tắt âm thanh hướng dẫn mẫu.' : 'Đã bật âm thanh. Bản demo chưa có lời hướng dẫn.',
                              );
                            },
                            style: IconButton.styleFrom(
                              minimumSize: const Size(52, 52),
                              backgroundColor: const Color(0xFF2A2A2A),
                              foregroundColor: Colors.white,
                            ),
                            icon: Icon(
                              _muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PrimaryButton(
                              label: _paused ? 'Tiếp tục' : 'Tạm dừng',
                              icon: _paused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              onPressed: () =>
                                  setState(() => _paused = !_paused),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _finish,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF474D),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            child: const Text(
                              'KẾT THÚC',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _finish() async {
    setState(() => _paused = true);
    final leave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: GymColors.green,
                size: 44,
              ),
              const SizedBox(height: 16),
              const Text(
                'Hoàn thành buổi tập mẫu',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                '8 lần Squat • 42 giây',
                style: TextStyle(
                  color: GymColors.purple,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kết quả minh họa, chưa được ghi vào lịch sử tập luyện.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GymColors.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Về trang chủ',
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: background,
      border: Border.all(color: color.withValues(alpha: .3)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SkeletonPainter extends CustomPainter {
  const _SkeletonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(size.width * .48, size.height * .07),
      Offset(size.width * .43, size.height * .23),
      Offset(size.width * .60, size.height * .25),
      Offset(size.width * .27, size.height * .37),
      Offset(size.width * .75, size.height * .39),
      Offset(size.width * .24, size.height * .21),
      Offset(size.width * .78, size.height * .20),
      Offset(size.width * .39, size.height * .49),
      Offset(size.width * .58, size.height * .50),
      Offset(size.width * .22, size.height * .63),
      Offset(size.width * .73, size.height * .64),
      Offset(size.width * .27, size.height * .88),
      Offset(size.width * .68, size.height * .89),
    ];
    const bones = [
      (0, 1),
      (0, 2),
      (1, 2),
      (1, 3),
      (3, 5),
      (2, 4),
      (4, 6),
      (1, 7),
      (2, 8),
      (7, 8),
      (7, 9),
      (9, 11),
      (8, 10),
      (10, 12),
    ];
    final paint = Paint()
      ..color = const Color(0xFF50F4E7)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = const Color(0x8850F4E7)
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    for (final (a, b) in bones) {
      canvas.drawLine(points[a], points[b], glow);
      canvas.drawLine(points[a], points[b], paint);
    }
    for (final point in points) {
      canvas.drawCircle(point, 5, Paint()..color = const Color(0xAA143D38));
      canvas.drawCircle(point, 3, paint);
    }
    final arcPaint = Paint()
      ..color = const Color(0xFFE4EA46)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: points[10], radius: 20),
      math.pi * .96,
      math.pi * .58,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_SkeletonPainter oldDelegate) => false;
}
