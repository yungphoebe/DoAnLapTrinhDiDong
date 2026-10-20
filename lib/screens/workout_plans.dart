import 'package:flutter/material.dart';

import '../services/workout_service.dart';
import '../services/profile_service.dart';
import '../ui.dart';

class WorkoutPlansScreen extends StatefulWidget {
  const WorkoutPlansScreen({super.key});

  @override
  State<WorkoutPlansScreen> createState() => _WorkoutPlansScreenState();
}

class _WorkoutPlansScreenState extends State<WorkoutPlansScreen> {
  final _service = WorkoutService();
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _weekly;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plans = await _service.plans();
      final weekly = await _service.weeklyProgress();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _weekly = weekly;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được kế hoạch: $error';
      });
    }
  }

  Future<void> _createRecommended() async {
    final profile = ProfileService.instance.profile ?? {};
    try {
      final catalog = await _service.exercises();
      if (catalog.isEmpty) throw StateError('Danh mục bài tập đang trống.');
      final level = profile['trainingLevel']?.toString();
      final goal = profile['goal']?.toString();
      await _service.createPlan(
        name: 'Kế hoạch ${goal?.isNotEmpty == true ? goal : 'cá nhân'}',
        goal: goal,
        level: level,
        exercises: catalog.take(5).toList().asMap().entries.map((entry) {
          final exercise = entry.value;
          return {
            'exerciseId': exercise['id'],
            'sets': 3,
            'reps': level == 'Cơ bản' ? 10 : 12,
            'restSeconds': 60,
            'order': entry.key,
          };
        }).toList(),
      );
      if (mounted) {
        showMessage(context, 'Đã tạo và lưu kế hoạch theo hồ sơ của bạn.');
        await _load();
      }
    } catch (error) {
      if (mounted) showMessage(context, 'Không tạo được kế hoạch: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const CircleBackButton(),
      title: const Text('Kế hoạch và lịch tập'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.orange)),
                if (_weekly != null)
                  GymCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TIẾN ĐỘ TUẦN',
                          style: TextStyle(
                            color: GymColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_weekly!['completedMinutes'] ?? 0} phút đã tập',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_weekly!['completedWorkouts'] ?? 0}/${_weekly!['plannedWorkouts'] ?? 0} buổi hoàn thành',
                          style: const TextStyle(color: GymColors.muted),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Tạo kế hoạch từ hồ sơ của tôi',
                  icon: Icons.auto_awesome,
                  onPressed: _createRecommended,
                ),
                const SizedBox(height: 14),
                if (_plans.isEmpty)
                  const GymCard(
                    child: Text('Chưa có kế hoạch. Hãy tạo kế hoạch đầu tiên.'),
                  )
                else
                  ..._plans.map(_planCard),
              ],
            ),
          ),
  );

  Widget _planCard(Map<String, dynamic> plan) {
    final exercises = plan['exercises'] as List<dynamic>? ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GymCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan['name']?.toString() ?? 'Kế hoạch',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (plan['goal'] != null) Text('Mục tiêu: ${plan['goal']}'),
            if (plan['level'] != null) Text('Trình độ: ${plan['level']}'),
            const SizedBox(height: 8),
            for (final item in exercises)
              Text(
                '${item['exerciseName']} · ${item['sets']} × ${item['reps']} · nghỉ ${item['restSeconds']} giây',
              ),
          ],
        ),
      ),
    );
  }
}
