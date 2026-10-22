import 'package:flutter/material.dart';

import '../notifications/controller.dart';

import '../ui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage('assets/images/avatar.jpg'),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Xin chào, Jang',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF301E40),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 16,
                    color: GymColors.purple,
                  ),
                  SizedBox(width: 3),
                  Text(
                    '12 Ngày',
                    style: TextStyle(
                      fontSize: 11,
                      color: GymColors.purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Thông báo',
              style: IconButton.styleFrom(
                backgroundColor: GymColors.surface,
                minimumSize: const Size(36, 36),
                padding: const EdgeInsets.all(8),
              ),
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
              icon: AnimatedBuilder(
                animation: NotificationController.instance,
                builder: (context, _) => Badge(
                  isLabelVisible: NotificationController.instance.unread > 0,
                  label: Text('${NotificationController.instance.unread}'),
                  child: const Icon(Icons.notifications_none_rounded, size: 19),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GymCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TỔNG QUAN HÔM NAY',
                style: TextStyle(
                  fontSize: 11,
                  color: GymColors.muted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.directions_run_rounded,
                              size: 17,
                              color: GymColors.purple,
                            ),
                            SizedBox(width: 5),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '320',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Chuyển động',
                          style: TextStyle(
                            color: GymColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '4.2',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: ' km',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: GymColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Quãng đường',
                          style: TextStyle(
                            color: GymColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: .65,
                            strokeWidth: 6,
                            strokeCap: StrokeCap.round,
                            color: GymColors.purple,
                            backgroundColor: Color(0xFF38303F),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '65%',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Mục tiêu',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white.withValues(alpha: .5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.view_in_ar_rounded,
                  title: 'Nhận diện Form',
                  subtitle: 'AI quét động tác tập',
                  onTap: () => Navigator.pushNamed(context, '/camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  icon: Icons.center_focus_strong_rounded,
                  title: 'Quét Dinh dưỡng',
                  subtitle: 'Chụp phân tích bữa ăn',
                  onTap: () => _showNutrition(context),
                ),
              ),
            ],
          ),
        ),
        SectionHeading(
          title: 'Bài tập đề xuất',
          action: 'Xem thêm',
          onAction: () => _showWorkout(context, 'Bài tập dành cho bạn'),
        ),
        SizedBox(
          height: 174,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _WorkoutTile(
                title: 'Hủy Diệt Cơ Đùi',
                level: 'Cơ bản',
                image: 'assets/images/workout.jpg',
                subtitle: '4 bài tập • 24 phút • 180 kcal',
                onTap: () => _showWorkout(context, 'Hủy Diệt Cơ Đùi'),
              ),
              const SizedBox(width: 12),
              _WorkoutTile(
                title: 'Sức Mạnh Thân Trên',
                level: 'Trung cấp',
                image: 'assets/images/trainer.jpg',
                subtitle: '5 bài tập • 30 phút • 220 kcal',
                onTap: () => _showWorkout(context, 'Sức Mạnh Thân Trên'),
              ),
            ],
          ),
        ),
        const SectionHeading(title: 'Dinh dưỡng hôm nay'),
        GymCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 5,
                children: [
                  const Text(
                    'Calo còn thiếu: 450 kcal',
                    style: TextStyle(
                      color: GymColors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Tổng: 1,850 Kcal',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _NutrientBar(
                label: 'Protein',
                value: '120g / 150g',
                progress: .8,
                color: GymColors.purple,
              ),
              const SizedBox(height: 10),
              const _NutrientBar(
                label: 'Carbs',
                value: '180g / 220g',
                progress: .82,
                color: Color(0xFFF5C842),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _showNutrition(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.restaurant_rounded,
                size: 32,
                color: GymColors.purple,
              ),
              const SizedBox(height: 14),
              const Text(
                'Phân tích bữa ăn mẫu',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bản demo chưa kết nối camera. Dưới đây là dữ liệu minh họa cho một bữa ăn.',
                style: TextStyle(color: GymColors.muted, height: 1.5),
              ),
              const SizedBox(height: 22),
              const GymCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ức gà, cơm gạo lứt & rau xanh',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 14),
                    Text(
                      '520 kcal',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: GymColors.purple,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Protein 42g  •  Carbs 56g  •  Chất béo 14g',
                      style: TextStyle(fontSize: 12, color: GymColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Đã hiểu',
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWorkout(BuildContext context, String title) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lịch tập minh họa • Nghỉ 60 giây giữa các hiệp',
                style: TextStyle(color: GymColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ...((title == 'Sức Mạnh Thân Trên')
                      ? [
                          'Bench Press',
                          'Lat Pulldown',
                          'Shoulder Press',
                          'Dumbbell Row',
                          'Biceps Curl',
                        ]
                      : [
                          'Barbell Squat',
                          'Leg Press',
                          'Walking Lunge',
                          'Leg Extension',
                        ])
                  .map(
                    (exercise) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fitness_center_rounded,
                            size: 20,
                            color: GymColors.purple,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(exercise)),
                          const Text(
                            '3 × 12',
                            style: TextStyle(
                              color: GymColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Thử nhận diện Squat',
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(context, '/camera');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: GymColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: GymColors.border),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: GymColors.purple, size: 27),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: GymColors.muted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({
    required this.title,
    required this.level,
    required this.image,
    required this.subtitle,
    required this.onTap,
  });
  final String title;
  final String level;
  final String image;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 258,
    child: Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(14),
      child: Ink.image(
        image: AssetImage(image),
        fit: BoxFit.cover,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x11000000), Color(0xE6000000)],
                stops: [.2, 1],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(level, style: const TextStyle(fontSize: 10)),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFCCCCCC),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _NutrientBar extends StatelessWidget {
  const _NutrientBar({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });
  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          Text(
            value,
            style: const TextStyle(fontSize: 10, color: GymColors.muted),
          ),
        ],
      ),
      const SizedBox(height: 7),
      LinearProgressIndicator(
        value: progress,
        color: color,
        backgroundColor: const Color(0xFF363636),
        minHeight: 5,
        borderRadius: BorderRadius.circular(5),
      ),
    ],
  );
}
