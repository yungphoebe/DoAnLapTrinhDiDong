import 'package:flutter/material.dart';

import '../ui.dart';
import '../notifications/controller.dart';
import '../notifications/training_bot_copy.dart';
import '../services/profile_service.dart';
import '../widgets/training_pet.dart';
import 'coach.dart';
import 'community.dart';
import 'home.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  var _selected = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !ProfileService.instance.loading) {
      ProfileService.instance.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _tab(String label, IconData icon, int index) {
    final selected = _selected == index;
    final color = selected ? GymColors.purple : GymColors.muted;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            if (index == 3) {
              Navigator.pushNamed(context, '/settings');
            } else {
              setState(() => _selected = index);
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 7),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: TextStyle(fontSize: 9, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Stack(
        children: [
          IndexedStack(
            index: _selected,
            children: const [HomeScreen(), CommunityScreen(), CoachScreen()],
          ),
          if (_selected == 0 && MediaQuery.viewInsetsOf(context).bottom == 0)
            ListenableBuilder(
              listenable: Listenable.merge([
                ProfileService.instance, NotificationController.instance,
              ]),
              builder: (context, _) {
                final service = ProfileService.instance;
                final profile = service.loading || service.error != null ? null : service.profile;
                // Keep the celebration state stable while refreshing the profile.
                final trained = ((service.profile?['todayWorkoutSeconds'] as num?) ?? 0) > 0;
                final roast = NotificationController.instance.settings.botRoastEnabled;
                return TrainingPet(
                  message: profile == null
                      ? 'Chào bạn! Mình là GYM BUDDY, bạn đồng hành tập luyện của bạn. Cùng vận động nhé!'
                      : trainingBotMessage(profile, roast: roast),
                  trained: trained,
                  progressKnown: profile != null,
                  roast: roast,
                  onStart: () async {
                    await Navigator.pushNamed(context, trained ? '/workout-history' : '/camera');
                    if (mounted) await service.load();
                  },
                  onSettings: () => Navigator.pushNamed(context, '/reminder-settings'),
                );
              },
            ),
        ],
      ),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    floatingActionButton: MediaQuery.viewInsetsOf(context).bottom > 0
        ? null
        : FloatingActionButton(
            tooltip: 'Mở camera AI',
            backgroundColor: GymColors.purple,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const CircleBorder(),
            onPressed: () => Navigator.pushNamed(context, '/camera'),
            child: const Icon(Icons.camera_alt_outlined, size: 26),
          ),
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        color: GymColors.surface,
        border: Border(top: BorderSide(color: GymColors.border)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              _tab('Trang chủ', Icons.home_outlined, 0),
              _tab('Cộng đồng/PT', Icons.people_outline, 1),
              const SizedBox(width: 64),
              _tab('AI Coach', Icons.psychology_outlined, 2),
              _tab('Hồ sơ', Icons.person_outline, 3),
            ],
          ),
        ),
      ),
    ),
  );
}
