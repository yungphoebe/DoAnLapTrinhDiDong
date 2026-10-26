import 'dart:async';
import 'package:flutter/material.dart';
import '../models/challenge.dart';
import '../services/challenge_service.dart';
import '../services/api_client.dart';
import '../ui.dart';
import '../support/share_medal_sheet.dart';

// ─── State quản lý toàn app kết nối API ──────────────────────────────────────────
class ChallengeStore extends ChangeNotifier {
  static final instance = ChallengeStore();

  final List<ActiveChallenge> activeChallenges = [];
  final List<EarnedMedal> medals = [];
  bool isLoading = false;
  String? _lastNotification;
  String? get lastNotification => _lastNotification;

  bool isActive(String id) => activeChallenges.any((a) => a.challenge.id == id);
  bool isCompleted(String id) => medals.any((m) => m.challenge.id == id);

  ActiveChallenge? getActive(String id) {
    try {
      return activeChallenges.firstWhere((a) => a.challenge.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    try {
      isLoading = true;
      notifyListeners();

      final rawList = await ChallengeService.instance.fetchChallenges();
      activeChallenges.clear();
      medals.clear();

      for (final raw in rawList) {
        final id = raw['id']?.toString() ?? '';
        final c = allChallenges.firstWhere((ch) => ch.id == id, orElse: () => allChallenges.first);
        final isActive = raw['is_active'] == true;
        final isCompleted = raw['is_completed'] == true;

        if (isCompleted) {
          final completedAt = DateTime.tryParse(raw['completed_at']?.toString() ?? '') ?? DateTime.now();
          medals.add(EarnedMedal(challenge: c, earnedDate: completedAt));
        } else if (isActive) {
          final logsRaw = (raw['daily_logs'] as List?) ?? [];
          final logs = logsRaw.map((l) => DailyProgressLog.fromJson(l as Map<String, dynamic>)).toList();

          activeChallenges.add(ActiveChallenge(
            challenge: c,
            startDate: DateTime.tryParse(raw['start_date']?.toString() ?? '') ?? DateTime.now(),
            currentStepIndex: (raw['current_step_index'] as num?)?.toInt() ?? 0,
            currentProgress: (raw['current_progress'] as num?)?.toInt() ?? 0,
            lastProgressDate: raw['last_progress_date']?.toString(),
            dailyLogs: logs,
            todayAmount: (raw['today_amount'] as num?)?.toInt() ?? 0,
            canUpdateToday: raw['can_update_today'] == true,
            secondsUntilNextDay: (raw['seconds_until_next_day'] as num?)?.toInt() ?? 0,
            nextAllowedDate: raw['next_allowed_date']?.toString() ?? '',
            todayTarget: (raw['today_target'] as num?)?.toInt() ?? 0,
            totalTarget: (raw['total_target'] as num?)?.toInt() ?? 0,
            totalProgress: (raw['total_progress'] as num?)?.toInt() ?? 0,
            isOverTarget: raw['is_over_target'] == true,
            isTodayTargetReached: raw['is_today_target_reached'] == true,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error loading challenges: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> joinChallenge(GymChallenge c) async {
    try {
      await ChallengeService.instance.joinChallenge(c.id);
      await load();
      _lastNotification = 'Bạn đã tham gia thử thách "${c.title}"! Chúc may mắn!';
      notifyListeners();
    } catch (e) {
      _lastNotification = e is ApiException ? e.message : e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> quitChallenge(ActiveChallenge ac) async {
    try {
      await ChallengeService.instance.quitChallenge(ac.challenge.id);
      await load();
      _lastNotification = 'Đã từ bỏ thử thách "${ac.challenge.title}".';
      notifyListeners();
    } catch (e) {
      _lastNotification = e is ApiException ? e.message : e.toString();
      notifyListeners();
      rethrow;
    }
  }
}

// ─── Đồng hồ đếm ngược tới 00:00 ngày mai ──────────────────────────────────────
class CountdownTimerWidget extends StatefulWidget {
  const CountdownTimerWidget({super.key, required this.initialSeconds, this.onComplete});
  final int initialSeconds;
  final VoidCallback? onComplete;

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.initialSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remaining > 0) {
        setState(() => _remaining--);
      } else {
        _timer?.cancel();
        widget.onComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(CountdownTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSeconds != widget.initialSeconds) {
      _remaining = widget.initialSeconds;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(int sec) {
    final h = (sec ~/ 3600).toString().padLeft(2, '0');
    final m = ((sec % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _format(_remaining),
      style: const TextStyle(
        fontFamily: 'Courier',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFFFFB83F),
      ),
    );
  }
}

// ─── Màn hình Thử Thách ───────────────────────────────────────────────────────
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _store = ChallengeStore.instance;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _store.addListener(_refresh);
    _store.load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GymColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: GymColors.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 52),
              title: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thử Thách Gym',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Kiên trì mỗi ngày • Chinh phục huy chương',
                    style: TextStyle(fontSize: 10, color: GymColors.muted),
                  ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: GymColors.border)),
                ),
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: GymColors.purple,
                  labelColor: GymColors.purple,
                  unselectedLabelColor: GymColors.muted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: [
                    Tab(text: 'Khám Phá (${allChallenges.length})'),
                    Tab(text: 'Đang Tham Gia (${_store.activeChallenges.length})'),
                    Tab(text: 'Huy Chương (${_store.medals.length})'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: _store.isLoading && _store.activeChallenges.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabs,
                children: [
                  _ExploreTab(store: _store),
                  _ActiveTab(store: _store),
                  _MedalsTab(store: _store),
                ],
              ),
      ),
    );
  }
}

// ─── Tab 1: Khám phá ──────────────────────────────────────────────────────────
class _ExploreTab extends StatelessWidget {
  const _ExploreTab({required this.store});
  final ChallengeStore store;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: allChallenges.length,
      itemBuilder: (context, i) {
        final c = allChallenges[i];
        final isDone = store.isCompleted(c.id);
        final isActive = store.isActive(c.id);
        return _ChallengeCard(
          challenge: c,
          status: isDone
              ? ChallengeStatus.completed
              : isActive
                  ? ChallengeStatus.active
                  : ChallengeStatus.available,
          onTap: () => _showDetail(context, c, store),
        );
      },
    );
  }

  void _showDetail(BuildContext context, GymChallenge c, ChallengeStore store) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GymColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ChallengeDetailSheet(challenge: c, store: store),
    );
  }
}

// ─── Tab 2: Đang tham gia ─────────────────────────────────────────────────────
class _ActiveTab extends StatelessWidget {
  const _ActiveTab({required this.store});
  final ChallengeStore store;

  @override
  Widget build(BuildContext context) {
    if (store.activeChallenges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'Chưa có thử thách nào đang tham gia',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chuyển sang tab "Khám Phá" để chọn thử thách!',
              style: TextStyle(color: GymColors.muted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: store.activeChallenges.length,
      itemBuilder: (context, i) {
        final ac = store.activeChallenges[i];
        return _ActiveChallengeCard(activeChallenge: ac, store: store);
      },
    );
  }
}

// ─── Tab 3: Huy chương ───────────────────────────────────────────────────────
class _MedalsTab extends StatelessWidget {
  const _MedalsTab({required this.store});
  final ChallengeStore store;

  @override
  Widget build(BuildContext context) {
    if (store.medals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🏅', style: TextStyle(fontSize: 56)),
            SizedBox(height: 16),
            Text('Chưa có huy chương nào',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Hoàn thành thử thách để nhận huy chương!',
                style: TextStyle(color: GymColors.muted, fontSize: 13)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: store.medals.length,
      itemBuilder: (context, i) => _MedalCard(medal: store.medals[i]),
    );
  }
}

// ─── Card Thử thách trong Khám phá ───────────────────────────────────────────
class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.status,
    required this.onTap,
  });
  final GymChallenge challenge;
  final ChallengeStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: GymColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == ChallengeStatus.active ? c.color.withValues(alpha: 0.6) : GymColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: c.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(c.emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _Badge(label: c.difficultyLabel, color: c.difficultyColor),
                            const SizedBox(width: 6),
                            _Badge(label: '${c.durationDays} ngay', color: GymColors.muted),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (status == ChallengeStatus.completed)
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF30D66A), size: 24)
                  else if (status == ChallengeStatus.active)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Đang tập',
                        style: TextStyle(color: c.color, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right, color: GymColors.muted),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                c.description,
                style: const TextStyle(color: GymColors.muted, fontSize: 12, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Card Thử thách đang tham gia (Hiển thị 3 trạng thái rõ ràng) ─────────────
class _ActiveChallengeCard extends StatefulWidget {
  const _ActiveChallengeCard({required this.activeChallenge, required this.store});
  final ActiveChallenge activeChallenge;
  final ChallengeStore store;

  @override
  State<_ActiveChallengeCard> createState() => _ActiveChallengeCardState();
}

class _ActiveChallengeCardState extends State<_ActiveChallengeCard> {
  bool _loading = false;

  static String _cameraHint(String metric) => switch (metric) {
        'squat' => 'Chỉ rep squat đúng form được tính.',
        'pushup' => 'Chỉ rep push-up đúng form được tính.',
        'jumpingJack' => 'Chỉ rep jumping jack đúng form được tính.',
        'shoulderPress' => 'Chỉ rep shoulder press đúng form được tính.',
        'morningSession' => 'Mỗi buổi tập camera bắt đầu trước 8h tính 1 buổi.',
        _ => 'Mỗi buổi tập camera tính 1 buổi.',
      };

  Future<void> _trainWithCamera() async {
    await Navigator.pushNamed(context, '/camera');
    if (mounted) await widget.store.load();
  }

  Future<void> _confirmQuit(BuildContext context, ActiveChallenge ac) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4F6D), size: 22),
            SizedBox(width: 8),
            Text('Từ bỏ thử thách?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bạn có chắc muốn từ bỏ thử thách "${ac.challenge.title}"?\n\n'
          'Toàn bộ tiến trình sẽ bị hủy. Nếu tham gia lại sau này, bạn sẽ bắt đầu lại từ ngày đầu tiên.',
          style: const TextStyle(fontSize: 13, color: GymColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tiếp tục tập', style: TextStyle(color: Colors.white)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF4F6D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Từ bỏ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await widget.store.quitChallenge(ac);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.store.lastNotification ?? 'Đã từ bỏ thử thách.'),
          backgroundColor: Colors.white24,
          behavior: SnackBarBehavior.floating,
        ));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = widget.activeChallenge;
    final c = ac.challenge;
    final pct = ac.overallProgress;
    final step = ac.currentStep;
    final isDone = ac.isCompleted;
    final canUpdate = ac.canUpdateToday && !isDone;

    final todayTarget = ac.todayTarget > 0 ? ac.todayTarget : (step?.targetValue ?? 0);
    final todayAmount = ac.todayAmount;
    final isOverTarget = ac.isOverTarget || (todayTarget > 0 && todayAmount > todayTarget);

    final totalTarget = ac.totalTarget > 0 ? ac.totalTarget : c.steps.fold(0, (sum, s) => sum + s.targetValue);
    final totalProgress = ac.totalProgress;
    final remaining = (totalTarget - totalProgress).clamp(0, totalTarget);
    final unit = step?.unit ?? 'cái';

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: GymColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thanh tiến độ đỉnh card
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: c.color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(c.color),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Row(
                  children: [
                    Text(c.emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          Text(
                            'Ngày ${ac.daysElapsed + 1}/${c.durationDays} • ${(pct * 100).round()}% hoàn thành',
                            style: const TextStyle(color: GymColors.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (isDone)
                      const Chip(
                        label: Text('Đã hoàn thành', style: TextStyle(fontSize: 10, color: Colors.white)),
                        backgroundColor: Color(0xFF30D66A),
                      )
                    else if (!canUpdate)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOverTarget
                              ? const Color(0xFFFFB83F).withValues(alpha: 0.15)
                              : const Color(0xFF30D66A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isOverTarget
                                ? const Color(0xFFFFB83F).withValues(alpha: 0.5)
                                : const Color(0xFF30D66A).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOverTarget ? Icons.stars_rounded : Icons.check_circle_outline,
                              size: 13,
                              color: isOverTarget ? const Color(0xFFFFB83F) : const Color(0xFF30D66A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOverTarget ? 'Vượt chỉ tiêu' : 'Đã hoàn thành',
                              style: TextStyle(
                                color: isOverTarget ? const Color(0xFFFFB83F) : const Color(0xFF30D66A),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // ─── PHẦN KIỂM TRA TIẾN ĐỘ (Yêu cầu đề bài) ──────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: GymColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KIỂM TRA TIẾN ĐỘ',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: GymColors.muted, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _statItem(
                              'Hôm nay',
                              todayAmount > 0 ? '$todayAmount/$todayTarget $unit' : '0/$todayTarget $unit',
                              isOverTarget
                                  ? const Color(0xFFFFB83F)
                                  : (todayAmount >= todayTarget ? const Color(0xFF30D66A) : Colors.white),
                            ),
                          ),
                          Expanded(
                            child: _statItem(
                              'Tổng tiến độ',
                              '$totalProgress/$totalTarget $unit',
                              Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _statItem(
                              'Tiến độ tổng',
                              '${(pct * 100).round()}%',
                              c.color,
                            ),
                          ),
                          Expanded(
                            child: _statItem(
                              'Còn lại',
                              '$remaining $unit',
                              const Color(0xFFFFB83F),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: GymColors.border, height: 1),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 13, color: GymColors.muted),
                          const SizedBox(width: 6),
                          Text(
                            'Cập nhật tiếp theo: ${ac.canUpdateToday ? "Hôm nay (đang mở - tập với camera để cộng)" : ac.nextAllowedDate}',
                            style: const TextStyle(fontSize: 11, color: GymColors.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ─── KHU VỰC CẬP NHẬT TIẾN ĐỘ ──────────────────────────────
                if (isDone) ...[
                  // Đã hoàn thành toàn bộ thử thách
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF30D66A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF30D66A).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.emoji_events_rounded, color: Color(0xFF30D66A), size: 36),
                        const SizedBox(height: 8),
                        const Text(
                          'ĐÃ HOÀN THÀNH XUẤT SẮC!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF30D66A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Huy chương "${c.medalTitle}" đã được lưu vào bộ sưu tập.',
                          style: const TextStyle(fontSize: 11, color: GymColors.muted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ] else if (!canUpdate) ...[
                  // Đã đạt/vượt mục tiêu hôm nay -> BỊ KHÓA + ĐẾM NGƯỢC 00:00 + BIỂU DƯƠNG
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isOverTarget
                          ? const Color(0xFF241D08)
                          : const Color(0xFF102117),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isOverTarget
                            ? const Color(0xFFFFB83F).withValues(alpha: 0.6)
                            : const Color(0xFF30D66A).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isOverTarget) ...[
                          Row(
                            children: [
                              const Text('🌟', style: TextStyle(fontSize: 22)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'BIỂU DƯƠNG XUẤT SẮC!',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFFFB83F),
                                      ),
                                    ),
                                    Text(
                                      'Đã thực hiện $todayAmount/$todayTarget $unit (Vượt chỉ tiêu +${todayAmount - todayTarget} $unit!)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB83F).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFFB83F)),
                                ),
                                child: Text(
                                  '+${todayAmount - todayTarget} $unit',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFFB83F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 14, color: Color(0xFFFFB83F)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Tiến trình thử thách ghi nhận: $todayTarget/$todayTarget $unit • Thực tế bạn đã làm $todayAmount $unit!',
                                    style: const TextStyle(fontSize: 11, color: GymColors.muted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF30D66A), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Hôm nay đã làm: $todayAmount/$todayTarget $unit - Đã hoàn thành!',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF30D66A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.lock_clock_rounded, size: 14, color: GymColors.muted),
                            const SizedBox(width: 6),
                            const Text(
                              'Đã khóa. Mở khóa ngày mai sau: ',
                              style: TextStyle(fontSize: 11, color: GymColors.muted),
                            ),
                            CountdownTimerWidget(
                              initialSeconds: ac.secondsUntilNextDay,
                              onComplete: () => widget.store.load(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Input và nút bị disable
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                enabled: false,
                                decoration: InputDecoration(
                                  hintText: 'Đã khóa hôm nay ($todayAmount/$todayTarget $unit)',
                                  hintStyle: const TextStyle(color: GymColors.muted, fontSize: 12),
                                  filled: true,
                                  fillColor: Colors.black12,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: GymColors.border),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: GymColors.border,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onPressed: null,
                              child: const Text('Đã Khóa', style: TextStyle(color: GymColors.muted)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Đang mở trong ngày: Cho phép nhập nhiều hiệp cho đến khi đủ
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.color.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flash_on_rounded, color: c.color, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Mục tiêu hôm nay: $todayTarget $unit (${step?.title ?? ""})',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (todayAmount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Hôm nay đã tích lũy: $todayAmount/$todayTarget $unit',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFFB83F)),
                              ),
                              Text(
                                'Còn thiếu: ${(todayTarget - todayAmount).clamp(0, todayTarget)} $unit',
                                style: const TextStyle(fontSize: 11, color: GymColors.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (todayAmount / (todayTarget > 0 ? todayTarget : 1)).clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(c.color),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          '💡 ${_cameraHint(ac.challenge.metric)} Tiến độ chỉ tính khi camera đếm và lưu buổi tập.',
                          style: const TextStyle(fontSize: 11, color: GymColors.muted),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: c.color,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _loading ? null : _trainWithCamera,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Tập với camera', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!isDone) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF4F6D),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _loading ? null : () => _confirmQuit(context, ac),
                      icon: const Icon(Icons.cancel_outlined, size: 14),
                      label: const Text(
                        'Từ bỏ thử thách',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get totalAmountTodayText => widget.activeChallenge.todayAmount.toString();

  Widget _statItem(String title, String val, Color valColor) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 10, color: GymColors.muted)),
      const SizedBox(height: 2),
      Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valColor)),
    ],
  );
}

// ─── Modal Chi tiết Thử thách ────────────────────────────────────────────────
class _ChallengeDetailSheet extends StatelessWidget {
  const _ChallengeDetailSheet({required this.challenge, required this.store});
  final GymChallenge challenge;
  final ChallengeStore store;

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final isActive = store.isActive(c.id);
    final isDone = store.isCompleted(c.id);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: GymColors.border, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(c.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Badge(label: c.difficultyLabel, color: c.difficultyColor),
                        const SizedBox(width: 8),
                        _Badge(label: '${c.durationDays} ngay', color: GymColors.muted),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(c.description, style: const TextStyle(color: GymColors.muted, height: 1.6, fontSize: 13)),
          const SizedBox(height: 24),
          const Text('Các Giai Đoạn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...c.steps.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c.color),
                    child: Center(
                      child: Text('${i + 1}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(s.description, style: const TextStyle(color: GymColors.muted, fontSize: 11)),
                        Text('Mục tiêu: ${s.targetValue} ${s.unit}',
                            style: TextStyle(color: c.color, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                c.color.withValues(alpha: 0.15),
                c.color.withValues(alpha: 0.05),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Text(c.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Phần Thưởng Khi Hoàn Thành',
                          style: TextStyle(fontSize: 11, color: GymColors.muted)),
                      Text(c.medalTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(c.medalDescription, style: const TextStyle(color: GymColors.muted, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!isDone && !isActive)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: c.color, minimumSize: const Size(0, 52)),
                icon: const Icon(Icons.flag_rounded),
                label: const Text('Tham Gia Thử Thách',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                onPressed: () async {
                  try {
                    await store.joinChallenge(c);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        Text(c.emoji),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Đã tham gia "${c.title}"!')),
                      ]),
                      backgroundColor: c.color,
                      behavior: SnackBarBehavior.floating,
                    ));
                  } catch (e) {
                    final msg = e is ApiException ? e.message : e.toString();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(msg),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  }
                },
              ),
            )
          else if (isDone)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF30D66A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.emoji_events_rounded, color: Color(0xFF30D66A)),
                SizedBox(width: 8),
                Text('Đã hoàn thành! Huy chương đã được lưu.',
                    style: TextStyle(color: Color(0xFF30D66A), fontWeight: FontWeight.w600)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GymColors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.play_circle_rounded, color: GymColors.purple),
                SizedBox(width: 8),
                Text('Đang tham gia thử thách này.',
                    style: TextStyle(color: GymColors.purple, fontWeight: FontWeight.w600)),
              ]),
            ),
        ],
      ),
    );
  }
}

// ─── Medal Card ──────────────────────────────────────────────────────────────
class _MedalCard extends StatelessWidget {
  const _MedalCard({required this.medal});
  final EarnedMedal medal;

  @override
  Widget build(BuildContext context) {
    final c = medal.challenge;
    final dateStr = '${medal.earnedDate.day}/${medal.earnedDate.month}/${medal.earnedDate.year}';
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => ShareMedalSheet.show(
        context: context,
        medalTitle: c.medalTitle,
        medalDescription: c.medalDescription,
        emoji: c.emoji,
        color: c.color,
        earnedDate: dateStr,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: GymColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.color.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: c.color.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.color.withValues(alpha: 0.15),
                border: Border.all(color: c.color, width: 2),
              ),
              child: Center(
                child: Text(c.emoji, style: const TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              c.medalTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              c.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: GymColors.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF30D66A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF30D66A),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: GymColors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GymColors.purple.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.share_rounded, size: 10, color: GymColors.purple),
                      SizedBox(width: 3),
                      Text(
                        'Chia sẻ',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}
