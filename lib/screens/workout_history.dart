import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/profile_service.dart';
import '../ui.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});
  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  final _token = ApiClient.instance.token;
  List<dynamic> _sessions = [];
  bool _loading = true;
  String? _error;
  bool get _sameAccount => _token != null && _token == ApiClient.instance.token;

  @override
  void initState() {
    super.initState();
    ProfileService.instance.addListener(_accountChanged);
    _load();
  }

  void _accountChanged() {
    if (!_sameAccount && mounted) {
      setState(() {
        _sessions = [];
        _loading = false;
        _error = 'Phiên đăng nhập đã thay đổi. Vui lòng mở lại lịch sử.';
      });
    }
  }

  Future<void> _load() async {
    if (!_sameAccount) {
      _accountChanged();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.instance.get(
        '/api/profile/workouts',
        includeAuth: true,
      );
      if (!mounted || !_sameAccount) return;
      if (response.statusCode != 200) throw const FormatException();
      final sessions = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || !_sameAccount) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được lịch sử tập luyện.';
      });
    }
  }

  @override
  void dispose() {
    ProfileService.instance.removeListener(_accountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch sử tập luyện')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_error != null) ...[
                  Text(_error!),
                  if (_sameAccount)
                    TextButton(onPressed: _load, child: const Text('Thử lại')),
                ] else if (_sessions.isEmpty)
                  const Text('Chưa có phiên tập nào được lưu.')
                else
                  ..._sessions.map(
                    (session) => _session(session as Map<String, dynamic>),
                  ),
              ],
            ),
          ),
  );

  Widget _session(Map<String, dynamic> session) {
    final date = DateTime.tryParse(session['startedAt']?.toString() ?? '')
        ?.toLocal();
    final seconds = (session['durationSeconds'] as num?)?.toInt() ?? 0;
    const exerciseNames = {
      'squat': 'Squat',
      'pushup': 'Chống đẩy',
      'jumpingJack': 'Jumping Jack',
      'shoulderPress': 'Đẩy vai',
      'bicepsCurl': 'Tập tay trước',
    };
    final feedback = session['feedbackCounts'] as Map<String, dynamic>? ?? {};
    const feedbackNames = {
      'squat_torso_lean': 'Thân người nghiêng quá nhiều khi squat',
      'pushup_body_line': 'Vai, hông và cổ chân chưa thẳng hàng',
      'jack_coordination': 'Tay và chân chưa phối hợp đồng thời',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GymCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              date == null
                  ? 'Phiên tập'
                  : '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('${seconds ~/ 60} phút ${seconds % 60} giây'),
            for (final exercise
                in session['exercises'] as List<dynamic>? ?? []) ...[
              const SizedBox(height: 8),
              Text(
                exerciseNames[exercise['exercise']] ??
                    exercise['exercise'].toString(),
              ),
              Text(
                '${exercise['reps']} lần · ${exercise['correctReps']} đúng · ${exercise['incorrectReps']} cần sửa',
              ),
            ],
            if (feedback.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Góp ý tư thế'),
              for (final entry in feedback.entries)
                Text(
                  '${feedbackNames[entry.key] ?? entry.key.replaceAll('_', ' ')}: ${entry.value}',
                ),
            ],
          ],
        ),
      ),
    );
  }
}
