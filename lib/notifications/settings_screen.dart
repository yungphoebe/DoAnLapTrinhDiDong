import 'package:flutter/material.dart';

import '../ui.dart';
import 'controller.dart';
import 'models.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key, this.controller});
  final NotificationController? controller;
  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  late final c = widget.controller ?? NotificationController.instance;
  ReminderSettings? _draft;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await c.load();
    if (mounted) {
      setState(() {
        _draft = c.localSettings;
        _loading = false;
      });
    }
  }

  Future<void> _time(String value, void Function(String) update) async {
    final parts = value.split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (selected != null && mounted) {
      setState(
        () => update(
          '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch nhắc & thông báo')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : AnimatedBuilder(
            animation: c,
            builder: (context, _) {
              final s = _draft!;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (c.error != null) ...[
                    Text(
                      c.error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    TextButton(
                      onPressed: c.saving ? null : _load,
                      child: const Text('Tải lại'),
                    ),
                  ],
                  if (c.blocked)
                    const Text(
                      'Có loại nhắc đang bị chặn trên máy này vì chưa lưu được lên máy chủ.',
                    ),
                  if (c.deviceMessage != null) Text(c.deviceMessage!),
                  OutlinedButton(
                    onPressed: c.enableDevice,
                    child: const Text(
                      'Cấp quyền / bật thông báo trên thiết bị',
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Nhắc tập luyện'),
                    value: s.workoutEnabled,
                    onChanged: c.saving
                        ? null
                        : (v) => setState(
                            () => _draft = s.copyWith(workoutEnabled: v),
                          ),
                  ),
                  ListTile(
                    title: const Text('Giờ tập'),
                    trailing: Text(s.workoutTime),
                    onTap: () => _time(
                      s.workoutTime,
                      (v) => _draft = s.copyWith(workoutTime: v),
                    ),
                  ),
                  Wrap(
                    spacing: 5,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        FilterChip(
                          label: Text(day == 7 ? 'CN' : 'T${day + 1}'),
                          selected: s.workoutDays.contains(day),
                          onSelected: (selected) {
                            final days = [...s.workoutDays];
                            if (selected) {
                              days.add(day);
                            } else {
                              days.remove(day);
                            }
                            if (days.isNotEmpty) {
                              setState(
                                () => _draft = s.copyWith(
                                  workoutDays: days..sort(),
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Nhắc uống nước'),
                    value: s.waterEnabled,
                    onChanged: c.saving
                        ? null
                        : (v) => setState(
                            () => _draft = s.copyWith(waterEnabled: v),
                          ),
                  ),
                  ListTile(
                    title: const Text('Bắt đầu'),
                    trailing: Text(s.waterStart),
                    onTap: () => _time(
                      s.waterStart,
                      (v) => _draft = s.copyWith(waterStart: v),
                    ),
                  ),
                  ListTile(
                    title: const Text('Kết thúc'),
                    trailing: Text(s.waterEnd),
                    onTap: () => _time(
                      s.waterEnd,
                      (v) => _draft = s.copyWith(waterEnd: v),
                    ),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: s.waterIntervalMinutes,
                    decoration: const InputDecoration(
                      labelText: 'Khoảng cách nhắc uống nước',
                    ),
                    items: [
                      for (final value in [60, 90, 120, 180, 240])
                        DropdownMenuItem(
                          value: value,
                          child: Text('$value phút'),
                        ),
                    ],
                    onChanged: (value) => setState(
                      () => _draft = s.copyWith(waterIntervalMinutes: value),
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Nhắc xem báo cáo tuần'),
                    value: s.weeklyEnabled,
                    onChanged: c.saving
                        ? null
                        : (v) => setState(
                            () => _draft = s.copyWith(weeklyEnabled: v),
                          ),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: s.weeklyDay,
                    decoration: const InputDecoration(
                      labelText: 'Ngày báo cáo',
                    ),
                    items: [
                      for (var day = 1; day <= 7; day++)
                        DropdownMenuItem(
                          value: day,
                          child: Text(day == 7 ? 'Chủ nhật' : 'Thứ ${day + 1}'),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _draft = s.copyWith(weeklyDay: value)),
                  ),
                  ListTile(
                    title: const Text('Giờ báo cáo'),
                    trailing: Text(s.weeklyTime),
                    onTap: () => _time(
                      s.weeklyTime,
                      (v) => _draft = s.copyWith(weeklyTime: v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tắt nhắc sẽ hủy lịch trên thiết bị này. Thiết bị Android khác cập nhật khi mở lại ứng dụng.',
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: c.saving ? 'Đang lưu…' : 'Lưu lịch nhắc',
                    onPressed: c.saving
                        ? null
                        : () async {
                            if (s.waterStart.compareTo(s.waterEnd) > 0) {
                              showMessage(
                                context,
                                'Giờ kết thúc phải sau giờ bắt đầu.',
                              );
                              return;
                            }
                            final saved = await c.save(s);
                            if (!context.mounted) return;
                            if (saved) {
                              Navigator.pop(context);
                              showMessage(context, 'Đã lưu lịch nhắc.');
                            }
                          },
                  ),
                ],
              );
            },
          ),
  );
}
