import 'package:flutter/material.dart';

import '../notifications/controller.dart';
import '../notifications/training_bot_copy.dart';
import '../services/profile_service.dart';
import '../ui.dart';
import '../widgets/training_pet.dart';

class TrainingBotScreen extends StatefulWidget {
  const TrainingBotScreen({super.key});

  @override
  State<TrainingBotScreen> createState() => _TrainingBotScreenState();
}

class _TrainingBotScreenState extends State<TrainingBotScreen>
    with WidgetsBindingObserver {
  final _profile = ProfileService.instance;
  final _notifications = NotificationController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  Future<void> _refresh() async {
    await Future.wait([_profile.load(), _notifications.load()]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Bot nhắc tập'),
          actions: [
            IconButton(
              tooltip: 'Cài đặt lịch nhắc',
              icon: const Icon(Icons.notifications_active_outlined),
              onPressed: () =>
                  Navigator.pushNamed(context, '/reminder-settings'),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([_profile, _notifications]),
          builder: (context, _) {
            final profile = _profile.error == null && !_profile.loading
                ? _profile.profile
                : null;
            final trained =
                ((profile?['todayWorkoutSeconds'] as num?) ?? 0) > 0;
            final settings = _notifications.localSettings;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Center(child: GymMascot(mood: trained ? PetMood.celebrating
                      : settings.botRoastEnabled && profile != null ? PetMood.teasing : PetMood.greeting)),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'GYM BUDDY',
                      style: TextStyle(
                        color: GymColors.purple,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_profile.loading) const LinearProgressIndicator(),
                  if (_profile.error != null)
                    TextButton(
                        onPressed: _refresh,
                        child: Text('${_profile.error} Thử lại')),
                  GymCard(
                      child: Text(trainingBotMessage(
                    profile,
                    roast: settings.botRoastEnabled,
                  ))),
                  const SizedBox(height: 12),
                  Text(
                    settings.botRoastEnabled
                        ? 'Chế độ: Cà khịa 😏'
                        : 'Chế độ: Động viên 💪',
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    settings.workoutEnabled
                        ? 'Giờ nhắc: ${settings.workoutTime} · ${settings.workoutDays.map((d) => d == 7 ? 'CN' : 'T${d + 1}').join(', ')}'
                        : 'Lịch nhắc tập đang tắt',
                    textAlign: TextAlign.center,
                  ),
                  if (_notifications.error != null) Text(_notifications.error!),
                  if (_notifications.deviceMessage != null)
                    Text(_notifications.deviceMessage!),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: trained ? 'Xem lịch sử tập' : 'Bắt đầu tập ngay',
                    onPressed: () async {
                      await Navigator.pushNamed(
                          context, trained ? '/workout-history' : '/camera');
                      if (mounted) await _profile.load();
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/reminder-settings'),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Chọn giọng bot & lịch nhắc'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Bot ghi nhận các phiên tập đã lưu. Bật Cà khịa nếu bạn thích '
                    'được trêu để có động lực; tắt bất cứ lúc nào trong lịch nhắc. '
                    'Ngày nghỉ thì cứ nghỉ, hồi phục cũng là một phần của tập luyện.',
                    style: TextStyle(color: GymColors.muted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      );
}
