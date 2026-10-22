import 'package:flutter/material.dart';

import '../ui.dart';
import 'coach.dart';
import 'community.dart';
import 'home.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selected = 0;

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
      child: IndexedStack(
        index: _selected,
        children: const [HomeScreen(), CommunityScreen(), CoachScreen()],
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
