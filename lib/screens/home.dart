import 'package:flutter/material.dart';

import '../notifications/controller.dart';

import '../services/profile_service.dart';
import '../models/workout.dart';
import '../ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _profile = ProfileService.instance;

  @override
  void initState() {
    super.initState();
    if (_profile.profile == null && !_profile.loading) {
      Future.microtask(_profile.load);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _profile,
    builder: (context, _) {
      final data = _profile.profile;
      final todaySeconds = (data?['todayWorkoutSeconds'] as num?)?.toInt() ?? 0;
      return RefreshIndicator(
        onRefresh: _profile.load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    child: Icon(Icons.person_outline),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data == null
                          ? 'Xin chào'
                          : 'Xin chào, ${data['fullName']}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.local_fire_department,
                    color: GymColors.purple,
                    size: 18,
                  ),
                  Text(
                    '${data?['streakDays'] ?? 0} Ngày',
                    style: const TextStyle(color: GymColors.purple),
                  ),
                  IconButton(
                    tooltip: 'Làm mới hồ sơ',
                    onPressed: _profile.loading ? null : _profile.load,
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                ],
              ),
              if (_profile.loading) const LinearProgressIndicator(),
              if (_profile.error != null) ...[
                Text(
                  _profile.error!,
                  style: const TextStyle(color: Colors.orange),
                ),
                TextButton(
                  onPressed: _profile.load,
                  child: const Text('Thử lại'),
                ),
              ],
              const SizedBox(height: 16),
              GymCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TỔNG QUAN HÔM NAY',
                      style: TextStyle(fontSize: 11, color: GymColors.muted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        _stat(
                          'Thời gian phiên tập',
                          data == null ? '—' : '${todaySeconds ~/ 60} phút',
                        ),
                        _stat(
                          'Phiên đã lưu',
                          data == null
                              ? '—'
                              : '${data['workoutSessions'] ?? 0}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Chuyển động · Quãng đường · Mục tiêu: Chưa có dữ liệu đo.',
                      style: TextStyle(color: GymColors.muted, fontSize: 11),
                    ),
                    if (data != null && (data['workoutSessions'] ?? 0) == 0)
                      const Text(
                        'Chưa có phiên tập nào được lưu.',
                        style: TextStyle(color: GymColors.muted, fontSize: 11),
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
                        onTap: () => Navigator.pushNamed(context, '/nutrition'),
                      ),
                    ),
                  ],
                ),
              ),
              SectionHeading(
                title: 'Bài tập đề xuất',
                action: 'Xem thêm',
                onAction: () => _showCatalog(context),
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
                      subtitle: '4 bài tập • Lịch tham khảo',
                      onTap: () => _showWorkout(context, workoutPlans[0]),
                    ),
                    const SizedBox(width: 12),
                    _WorkoutTile(
                      title: 'Sức Mạnh Thân Trên',
                      level: 'Trung cấp',
                      image: 'assets/images/trainer.jpg',
                      subtitle: '5 bài tập • Lịch tham khảo',
                      onTap: () => _showWorkout(context, workoutPlans[1]),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/workout-plans'),
                  icon: const Icon(Icons.calendar_month_outlined, size: 17),
                  label: const Text('Kế hoạch và lịch tập của tôi'),
                ),
              ),
              SectionHeading(
                title: 'Dinh dưỡng hôm nay',
                action: 'Mở nhật ký',
                onAction: () => Navigator.pushNamed(context, '/nutrition'),
              ),
              GymCard(
                child: Row(
                  children: [
                    const Icon(Icons.restaurant_outlined, color: GymColors.purple),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Theo dõi calo và macro từ các bữa ăn của bạn.')),
                    TextButton(onPressed: () => Navigator.pushNamed(context, '/nutrition'), child: const Text('Ghi món')),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _stat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      ),
      Text(label, style: const TextStyle(color: GymColors.muted, fontSize: 11)),
    ],
  );

  void _showCatalog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            const Text('Thư viện bài tập',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Chọn giáo án để xem bài, hiệp, lần và thời lượng.',
                style: TextStyle(color: GymColors.muted)),
            const SizedBox(height: 16),
            for (final plan in workoutPlans)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(plan.title),
                subtitle: Text('${plan.exercises.length} bài · ${plan.level}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showWorkout(context, plan);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showWorkout(BuildContext context, WorkoutPlan plan) {
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
                plan.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                plan.description,
                style: const TextStyle(color: GymColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ...plan.exercises.map(
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(exercise.name),
                                const SizedBox(height: 3),
                                Text(
                                  exercise.description,
                                  style: const TextStyle(
                                    color: GymColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${exercise.sets} × ${exercise.reps}\n${exercise.restSeconds}s nghỉ',
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
              for (final exercise in plan.exercises)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('Bắt đầu ${exercise.name}'),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.pushNamed(
                        context,
                        '/camera',
                        arguments: exercise,
                      );
                    },
                  ),
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
