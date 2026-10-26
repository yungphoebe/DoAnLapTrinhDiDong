import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/profile_service.dart';
import '../services/workout_service.dart';
import '../ui.dart';

class WorkoutPlansScreen extends StatefulWidget {
  const WorkoutPlansScreen({super.key});

  @override
  State<WorkoutPlansScreen> createState() => _WorkoutPlansScreenState();
}

class _WorkoutPlansScreenState extends State<WorkoutPlansScreen> {
  final _service = WorkoutService();
  final _goal = TextEditingController();
  final _location = TextEditingController();
  final _equipment = TextEditingController();
  final _minutes = TextEditingController(text: '45');
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _weekly;
  Map<String, dynamic>? _proposal;
  String _level = 'Cơ bản';
  int _days = 3;
  bool _loading = true;
  bool _generating = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ProfileService.instance.profile ?? {};
    _goal.text = profile['goal']?.toString() ?? 'Tăng cường thể lực';
    _location.text = profile['trainingLocation']?.toString() ?? 'Tại nhà';
    _level = profile['trainingLevel']?.toString() ?? 'Cơ bản';
    _days = (profile['trainingDays'] as num?)?.toInt().clamp(1, 7) ?? 3;
    _load();
  }

  @override
  void dispose() {
    _goal.dispose();
    _location.dispose();
    _equipment.dispose();
    _minutes.dispose();
    super.dispose();
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

  Future<void> _generateProposal() async {
    final sessionMinutes = int.tryParse(_minutes.text);
    if (_goal.text.trim().isEmpty ||
        _location.text.trim().isEmpty ||
        sessionMinutes == null ||
        sessionMinutes < 10 ||
        sessionMinutes > 240) {
      showMessage(
          context, 'Nhập mục tiêu, địa điểm và thời lượng 10–240 phút.');
      return;
    }
    setState(() {
      _generating = true;
      _proposal = null;
    });
    try {
      final proposal = await _service.proposePlan(
        goal: _goal.text.trim(),
        level: _level,
        daysPerWeek: _days,
        sessionMinutes: sessionMinutes,
        trainingLocation: _location.text.trim(),
        equipment: _equipment.text.trim(),
      );
      if (!mounted) return;
      setState(() => _proposal = proposal);
    } catch (error) {
      if (mounted) showMessage(context, 'Không tạo được lịch tập: $error');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _saveProposal() async {
    final proposal = _proposal;
    if (proposal == null || _saving) return;
    final sessionMinutes = int.tryParse(_minutes.text);
    final exercises = (proposal['exercises'] as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    if (sessionMinutes == null ||
        sessionMinutes < 10 ||
        sessionMinutes > 240 ||
        _goal.text.trim().isEmpty ||
        _location.text.trim().isEmpty ||
        exercises.any((item) => (item['dayNumber'] as num).toInt() > _days)) {
      showMessage(
          context, 'Kiểm tra lại mục tiêu, địa điểm, thời lượng và ngày tập.');
      return;
    }
    setState(() => _saving = true);
    try {
      final requestExercises = exercises
          .map(
            (item) => {
              'id': item['id'],
              'exerciseId': item['exerciseId'],
              'dayNumber': item['dayNumber'],
              'sets': item['sets'],
              'reps': item['reps'],
              'targetSeconds': item['targetSeconds'],
              'restSeconds': item['restSeconds'],
              'order': item['order'],
            },
          )
          .toList();
      final arguments = {
        'name': proposal['name']?.toString() ?? 'Kế hoạch cá nhân',
        'goal': _goal.text.trim(),
        'level': _level,
        'daysPerWeek': _days,
        'sessionMinutes': sessionMinutes,
        'trainingLocation': _location.text.trim(),
        'equipment': _equipment.text.trim(),
        'exercises': requestExercises,
      };
      final planId = proposal['id']?.toString();
      if (planId == null) {
        await _service.createPlan(
          name: arguments['name']! as String,
          goal: arguments['goal'] as String?,
          level: arguments['level'] as String?,
          daysPerWeek: arguments['daysPerWeek']! as int,
          sessionMinutes: arguments['sessionMinutes']! as int,
          trainingLocation: arguments['trainingLocation'] as String?,
          equipment: arguments['equipment'] as String?,
          exercises: requestExercises,
        );
      } else {
        await _service.updatePlan(
          id: planId,
          name: arguments['name']! as String,
          goal: arguments['goal'] as String?,
          level: arguments['level'] as String?,
          daysPerWeek: arguments['daysPerWeek']! as int,
          sessionMinutes: arguments['sessionMinutes']! as int,
          trainingLocation: arguments['trainingLocation'] as String?,
          equipment: arguments['equipment'] as String?,
          exercises: requestExercises,
        );
      }
      if (!mounted) return;
      setState(() => _proposal = null);
      showMessage(context, 'Đã lưu lịch tập với bài tập từ danh mục.');
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, 'Không lưu được kế hoạch: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editProposalExercise(Map<String, dynamic> item) async {
    final sets = TextEditingController(text: item['sets'].toString());
    final reps = TextEditingController(text: item['reps'].toString());
    final rest = TextEditingController(text: item['restSeconds'].toString());
    var day = (item['dayNumber'] as num).toInt();
    final updated = await showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: Text('Chỉnh ${item['exerciseName']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: day,
                decoration: const InputDecoration(labelText: 'Ngày tập'),
                items: List.generate(_days, (index) => index + 1)
                    .map((value) => DropdownMenuItem(
                        value: value, child: Text('Ngày $value')))
                    .toList(),
                onChanged: (value) => updateDialog(() => day = value ?? day),
              ),
              TextField(
                controller: sets,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số hiệp'),
              ),
              TextField(
                controller: reps,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số lần mỗi hiệp'),
              ),
              TextField(
                controller: rest,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Nghỉ giữa hiệp (giây)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final parsedSets = int.tryParse(sets.text);
                final parsedReps = int.tryParse(reps.text);
                final parsedRest = int.tryParse(rest.text);
                if (parsedSets == null ||
                    parsedSets < 1 ||
                    parsedSets > 100 ||
                    parsedReps == null ||
                    parsedReps < 1 ||
                    parsedReps > 1000 ||
                    parsedRest == null ||
                    parsedRest < 0 ||
                    parsedRest > 3600) {
                  showMessage(
                      dialogContext, 'Mục tiêu hiệp/lần/nghỉ không hợp lệ.');
                  return;
                }
                Navigator.pop(dialogContext, {
                  'dayNumber': day,
                  'sets': parsedSets,
                  'reps': parsedReps,
                  'restSeconds': parsedRest,
                });
              },
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
    sets.dispose();
    reps.dispose();
    rest.dispose();
    if (updated == null || !mounted) return;
    final proposal = Map<String, dynamic>.from(_proposal!);
    final exercises = (proposal['exercises'] as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    final index = exercises.indexWhere(
      (value) =>
          value['exerciseId'] == item['exerciseId'] &&
          value['order'] == item['order'],
    );
    if (index < 0) return;
    exercises[index] = {...exercises[index], ...updated};
    setState(() => _proposal = {...proposal, 'exercises': exercises});
  }

  Exercise _exerciseFor(Map<String, dynamic> plan, Map<String, dynamic> item) {
    final id = (item['exerciseId'] as num).toInt();
    return Exercise(
      id: 'catalog_$id',
      catalogId: id,
      name: item['exerciseName']?.toString() ?? 'Bài tập',
      description: item['description']?.toString() ?? '',
      muscleGroup: item['muscleGroup']?.toString(),
      sets: (item['sets'] as num?)?.toInt() ?? 1,
      reps: (item['reps'] as num?)?.toInt() ?? 1,
      targetSeconds: (item['targetSeconds'] as num?)?.toInt(),
      restSeconds: (item['restSeconds'] as num?)?.toInt() ?? 60,
      dayNumber: (item['dayNumber'] as num?)?.toInt() ?? 1,
      level: plan['level']?.toString() ?? 'Cơ bản',
      planId: plan['id']?.toString(),
      planExerciseId: item['id']?.toString(),
    );
  }

  Future<void> _startExercise(
      Map<String, dynamic> plan, Map<String, dynamic> item) async {
    await Navigator.pushNamed(
      context,
      '/camera',
      arguments: _exerciseFor(plan, item),
    );
    if (mounted) await _load();
  }

  bool _exerciseCompleted(Map<String, dynamic> item) =>
      (item['results'] as List<dynamic>? ?? [])
          .any((result) => result['completed'] == true);

  void _editPlan(Map<String, dynamic> plan) {
    final exercises = (plan['exercises'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    setState(() {
      _days = ((plan['daysPerWeek'] as num?)?.toInt() ?? 3).clamp(1, 7);
      _goal.text = plan['goal']?.toString() ?? '';
      _level = plan['level']?.toString() ?? 'Cơ bản';
      _location.text = plan['trainingLocation']?.toString() ?? '';
      _equipment.text = plan['equipment']?.toString() ?? '';
      _minutes.text = (plan['sessionMinutes'] ?? 45).toString();
      _proposal = {
        ...plan,
        'exercises': exercises,
      };
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: const CircleBackButton(),
          title: const Text('Kế hoạch và lịch tập'),
          actions: [
            IconButton(
              tooltip: 'Lịch nhắc chạy bộ',
              onPressed: () =>
                  Navigator.pushNamed(context, '/reminder-settings'),
              icon: const Icon(Icons.notifications_active_outlined),
            ),
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
                      Text(_error!,
                          style: const TextStyle(color: Colors.orange)),
                    if (_weekly != null) _weeklyCard(),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/activity'),
                      icon: const Icon(Icons.directions_walk),
                      label: const Text('Theo dõi đi bộ / chạy bộ'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/reminder-settings'),
                      icon: const Icon(Icons.alarm),
                      label: const Text('Cài lịch nhắc chạy bộ'),
                    ),
                    const SizedBox(height: 14),
                    _planInputs(),
                    const SizedBox(height: 14),
                    if (_proposal != null) _proposalCard(),
                    if (_plans.isEmpty)
                      const GymCard(
                        child: Text(
                            'Chưa có kế hoạch. Hãy tạo lịch tập đầu tiên.'),
                      )
                    else
                      ..._plans.map(_planCard),
                  ],
                ),
              ),
      );

  Widget _weeklyCard() => GymCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TIẾN ĐỘ TUẦN',
                style: TextStyle(color: GymColors.muted, fontSize: 11)),
            const SizedBox(height: 8),
            Text(
              '${_weekly!['completedMinutes'] ?? 0} phút đã tập',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            Text(
              '${_weekly!['completedWorkouts'] ?? 0}/${_weekly!['plannedWorkouts'] ?? 0} buổi hoàn thành',
              style: const TextStyle(color: GymColors.muted),
            ),
          ],
        ),
      );

  Widget _planInputs() => GymCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TẠO LỊCH TẬP CÁ NHÂN HÓA',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _goal,
              decoration: const InputDecoration(labelText: 'Mục tiêu'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _level,
              decoration: const InputDecoration(labelText: 'Trình độ'),
              items: const ['Cơ bản', 'Trung cấp', 'Nâng cao']
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => setState(() => _level = value ?? _level),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _days,
              decoration:
                  const InputDecoration(labelText: 'Số ngày tập mỗi tuần'),
              items: List.generate(7, (index) => index + 1)
                  .map((value) => DropdownMenuItem(
                      value: value, child: Text('$value ngày')))
                  .toList(),
              onChanged: (value) => setState(() => _days = value ?? _days),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Thời gian mỗi buổi (phút)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Địa điểm tập'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _equipment,
              decoration: const InputDecoration(labelText: 'Dụng cụ hiện có'),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label:
                  _generating ? 'AI đang tạo lịch...' : 'Tạo bản nháp bằng AI',
              icon: Icons.auto_awesome,
              onPressed: _generating ? null : _generateProposal,
            ),
            const SizedBox(height: 6),
            const Text(
              'AI chỉ được chọn bài tập có sẵn trong danh mục; xem lại bản nháp trước khi lưu.',
              style: TextStyle(color: GymColors.muted, fontSize: 12),
            ),
          ],
        ),
      );

  Widget _proposalCard() {
    final proposal = _proposal!;
    final exercises = (proposal['exercises'] as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final dayNumbers = exercises
        .map((item) => (item['dayNumber'] as num).toInt())
        .toSet()
        .toList()
      ..sort();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GymCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              proposal['name']?.toString() ?? 'Bản nháp kế hoạch',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const Text('Bản nháp AI · Có thể xem trước rồi lưu'),
            for (final day in dayNumbers) ...[
              const SizedBox(height: 10),
              Text('Ngày tập $day',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final item
                  in exercises.where((item) => item['dayNumber'] == day))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _exerciseCompleted(item)
                      ? const Icon(Icons.check_circle,
                          color: Colors.greenAccent)
                      : null,
                  title: Text(item['exerciseName']?.toString() ?? 'Bài tập'),
                  subtitle: Text(
                    '${item['muscleGroup'] ?? 'Toàn thân'} · ${item['sets']} hiệp × ${item['reps']} lần'
                    '${item['targetSeconds'] == null ? '' : ' / ${item['targetSeconds']} giây'} · '
                    'nghỉ ${item['restSeconds']} giây',
                  ),
                  trailing: IconButton(
                    tooltip: 'Chỉnh mục tiêu',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editProposalExercise(item),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            PrimaryButton(
              label: _saving ? 'Đang lưu...' : 'Lưu lịch tập này',
              icon: Icons.save_outlined,
              onPressed: _saving ? null : _saveProposal,
            ),
            TextButton(
              onPressed:
                  _saving ? null : () => setState(() => _proposal = null),
              child: const Text('Bỏ bản nháp'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final exercises = (plan['exercises'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final dayNumbers = exercises
        .map((item) => (item['dayNumber'] as num?)?.toInt() ?? 1)
        .toSet()
        .toList()
      ..sort();
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _editPlan(plan),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Chỉnh lịch'),
              ),
            ),
            if (plan['goal'] != null) Text('Mục tiêu: ${plan['goal']}'),
            if (plan['level'] != null) Text('Trình độ: ${plan['level']}'),
            Text(
              '${plan['daysPerWeek'] ?? dayNumbers.length} ngày/tuần · '
              '${plan['sessionMinutes'] ?? 45} phút/buổi · '
              '${plan['trainingLocation'] ?? 'Chưa chọn địa điểm'}',
            ),
            for (final day in dayNumbers) ...[
              const SizedBox(height: 10),
              Text('Ngày tập $day',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final item in exercises
                  .where((item) => (item['dayNumber'] as num?)?.toInt() == day))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['exerciseName']?.toString() ?? 'Bài tập'),
                  subtitle: Text(
                    '${item['muscleGroup'] ?? 'Nhóm cơ chưa rõ'} · ${item['sets']} hiệp × ${item['reps']} lần'
                    '${item['targetSeconds'] == null ? '' : ' / ${item['targetSeconds']} giây'} · '
                    'nghỉ ${item['restSeconds']} giây'
                    '${_exerciseCompleted(item) ? ' · Đã tập xong' : ''}',
                  ),
                  trailing: IconButton(
                    tooltip: _exerciseCompleted(item)
                        ? 'Tập lại bài này'
                        : 'Bắt đầu bài tập này',
                    icon: Icon(_exerciseCompleted(item)
                        ? Icons.replay
                        : Icons.play_circle_outline),
                    onPressed: () => _startExercise(plan, item),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
