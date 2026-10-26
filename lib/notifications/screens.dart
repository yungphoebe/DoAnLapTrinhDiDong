import 'package:flutter/material.dart';

import '../ui.dart';
import 'controller.dart';
import 'models.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.controller});
  final NotificationController? controller;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final c = widget.controller ?? NotificationController.instance;
  @override
  void initState() {
    super.initState();
    c.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Thông báo'),
      actions: [
        IconButton(
          tooltip: 'Đánh dấu tất cả đã đọc',
          onPressed: () async {
            final saved = await c.readAll();
            if (!saved && context.mounted) {
              showMessage(context, 'Chưa đánh dấu được. Vui lòng thử lại.');
            }
          },
          icon: const Icon(Icons.done_all),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: c,
      builder: (context, _) => RefreshIndicator(
        onRefresh: () => c.load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (c.loading && c.items.isEmpty)
              const Center(child: CircularProgressIndicator()),
            if (c.error != null) ...[
              Text(c.error!),
              TextButton(
                onPressed: () => c.load(),
                child: const Text('Thử lại'),
              ),
            ],
            if (!c.loading && c.error == null && c.items.isEmpty)
              const GymCard(
                child: Text(
                  'Chưa có thông báo. Bạn có thể bật lịch nhắc trong Cài đặt.',
                ),
              ),
            for (final n in c.items)
              Card(
                child: ListTile(
                  leading: Icon(switch (n.kind) {
                    'workout' => Icons.fitness_center,
                    'water' => Icons.water_drop_outlined,
                    _ => Icons.insert_chart_outlined,
                  }, color: n.read ? GymColors.muted : GymColors.purple),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.read ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${n.body}\n${n.at.toLocal().toString().substring(0, 16)}',
                  ),
                  isThreeLine: true,
                  onTap: () {
                    c.read(n);
                    Navigator.pushNamed(
                      context,
                      NotificationLink(
                        owner: c.owner!,
                        kind: n.kind,
                        id: n.id,
                        at: n.at.toIso8601String(),
                      ).route,
                    );
                  },
                ),
              ),
            if (c.hasMore)
              TextButton(
                onPressed: c.loading ? null : () => c.load(more: true),
                child: const Text('Tải thêm'),
              ),
          ],
        ),
      ),
    ),
  );
}

class NotificationDestinationScreen extends StatelessWidget {
  const NotificationDestinationScreen({super.key, required this.kind, this.at});
  final String kind;
  final DateTime? at;
  @override
  Widget build(BuildContext context) {
    final title = switch (kind) {
      'workout' => 'Lịch tập',
      'water' => 'Uống nước',
      _ => 'Báo cáo tuần',
    };
    final date = (at ?? DateTime.now()).toLocal();
    final monday = DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GymCard(
            child: Text(switch (kind) {
              'workout' => 'Bạn chưa có lịch tập cá nhân được lưu. Các bài tập minh họa hiện có nằm ở Trang chủ.',
              'water' => 'Dành một chút thời gian để uống nước. Bạn có thể điều chỉnh giờ nhắc bên dưới.',
              _ =>
                'Tuần ${monday.day}/${monday.month} – ${monday.add(const Duration(days: 6)).day}/${monday.add(const Duration(days: 6)).month}\nChưa có dữ liệu tập luyện cho tuần này.',
            }),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: NotificationController.instance,
            builder: (context, _) {
              final s = NotificationController.instance.settings;
              return Text(switch (kind) {
                'workout' => 'Giờ nhắc: ${s.workoutTime}',
                'water' =>
                  'Lịch nhắc: ${s.waterStart}–${s.waterEnd}, mỗi ${s.waterIntervalMinutes} phút',
                _ => 'Giờ nhắc báo cáo: ${s.weeklyTime}',
              });
            },
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/reminder-settings'),
            child: const Text('Cài đặt lịch nhắc'),
          ),
          if (kind == 'workout')
            TextButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (_) => false,
              ),
              child: const Text('Mở Trang chủ'),
            ),
        ],
      ),
    );
  }
}
