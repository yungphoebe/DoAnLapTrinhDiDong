import 'package:flutter/material.dart';

import '../ui.dart';
import '../notifications/controller.dart';
import '../services/auth_service.dart';

// Session-only preferences for the UI demo.
final _preferences = _Preferences();

class _Preferences {
  String name = 'Minh Trí';
  int voice = 0, motivation = 1;
  bool water = true, weekly = true, haptic = false;
  bool reminder = true, camera = true;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    NotificationController.instance.load();
  }

  Future<void> _editProfile() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(),
    );
    if (mounted && name != null) setState(() => _preferences.name = name);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const CircleBackButton(),
      title: const Text('Cài đặt hệ thống'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
        children: [
          GymCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 23,
                  backgroundImage: AssetImage('assets/images/avatar.jpg'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _preferences.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'tri.nguyen@gym.ai',
                        style: TextStyle(fontSize: 10, color: GymColors.muted),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _editProfile,
                  child: const Text(
                    'Chỉnh sửa',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          _section('TÀI KHOẢN'),
          _row(
            Icons.lock_outline,
            'Đổi mật khẩu',
            onTap: () => Navigator.pushNamed(context, '/forgot'),
          ),
          _row(
            Icons.language,
            'Ngôn ngữ',
            value: 'Tiếng Việt',
            onTap: () =>
                showMessage(context, 'Bản giao diện hiện hỗ trợ Tiếng Việt.'),
          ),
          _row(
            Icons.balance_outlined,
            'Đơn vị đo lường',
            value: 'Metric (kg/cm)',
            onTap: () =>
                showMessage(context, 'Chỉ số trong bản mẫu sử dụng kg và cm.'),
          ),
          _section('AI COACH & HUẤN LUYỆN'),
          _row(
            Icons.psychology_outlined,
            'Cài đặt AI Coach',
            value:
                'Giọng: ${_preferences.voice == 0 ? 'Nam trầm' : 'Nữ nhẹ nhàng'}',
            onTap: () async {
              await Navigator.pushNamed(context, '/coach-settings');
              if (mounted) setState(() {});
            },
          ),
          _row(
            Icons.emoji_events_outlined,
            'Nhắc nhở tập luyện',
            trailing: AnimatedBuilder(
              animation: NotificationController.instance,
              builder: (context, _) {
                final c = NotificationController.instance;
                return _switch(c.localSettings.workoutEnabled, (v) async {
                  if (c.saving) return;
                  final saved = await c.save(
                    c.localSettings.copyWith(workoutEnabled: v),
                  );
                  if (context.mounted) {
                    showMessage(
                      context,
                      saved
                          ? 'Đã lưu nhắc tập.'
                          : c.error ?? 'Chưa lưu được cài đặt.',
                    );
                  }
                });
              },
            ),
          ),
          _row(
            Icons.notifications_outlined,
            'Lịch nhắc & thông báo',
            onTap: () => Navigator.pushNamed(context, '/reminder-settings'),
          ),
          _row(
            Icons.monitor_heart_outlined,
            'Đồng bộ sức khỏe',
            value: 'Apple Health',
            onTap: () => showMessage(
              context,
              'Apple Health chưa được kết nối. Các chỉ số hiện là dữ liệu mẫu.',
            ),
          ),
          _section('QUYỀN RIÊNG TƯ'),
          _row(
            Icons.camera_alt_outlined,
            'Quyền truy cập Camera (AI)',
            trailing: _switch(_preferences.camera, (v) {
              setState(() => _preferences.camera = v);
              showMessage(
                context,
                'Công tắc minh họa; chưa yêu cầu quyền camera trên thiết bị.',
              );
            }),
          ),
          _row(
            Icons.help_outline,
            'Trợ giúp & Phản hồi',
            onTap: () => Navigator.pushNamed(context, '/support'),
          ),
          const SizedBox(height: 25),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: GymColors.surface,
              foregroundColor: const Color(0xFFFF5757),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (_) => false,
                );
              }
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text(
              'Đăng xuất tài khoản',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/support'),
            child: const Text(
              'Phiên bản & thông tin ứng dụng',
              style: TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _row(
    IconData icon,
    String title, {
    String? value,
    Widget? trailing,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 55),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF252525))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: GymColors.surface,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 17, color: const Color(0xFFCBCBCD)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          if (value != null)
            Flexible(
              flex: 2,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 10, color: GymColors.muted),
              ),
            ),
          if (trailing != null)
            trailing
          else
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: GymColors.muted,
              ),
            ),
        ],
      ),
    ),
  );
}

class CoachSettingsScreen extends StatefulWidget {
  const CoachSettingsScreen({super.key});
  @override
  State<CoachSettingsScreen> createState() => _CoachSettingsScreenState();
}

class _CoachSettingsScreenState extends State<CoachSettingsScreen> {
  late int _voice = _preferences.voice;
  late int _motivation = _preferences.motivation;
  late bool _water = NotificationController.instance.localSettings.waterEnabled,
      _weekly = NotificationController.instance.localSettings.weeklyEnabled,
      _haptic = _preferences.haptic;

  bool _saving = false;
  Future<void> _save() async {
    if (_saving) return;
    final c = NotificationController.instance;
    if (_water != c.localSettings.waterEnabled ||
        _weekly != c.localSettings.weeklyEnabled) {
      setState(() => _saving = true);
      final saved = await c.save(
        c.localSettings.copyWith(waterEnabled: _water, weeklyEnabled: _weekly),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (!saved) {
        showMessage(context, c.error ?? 'Chưa lưu được cài đặt.');
        return;
      }
    }
    _preferences
      ..voice = _voice
      ..motivation = _motivation
      ..water = _water
      ..weekly = _weekly
      ..haptic = _haptic;
    Navigator.pop(context);
    showMessage(context, 'Đã lưu cài đặt.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const CircleBackButton(),
      title: const Text(
        'Cài đặt AI Coach & Báo cáo',
        style: TextStyle(fontSize: 15),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _section('GIỌNG NÓI AI COACH'),
          Row(
            children: [
              Expanded(
                child: ChoiceTile(
                  label: 'Nam trầm',
                  icon: Icons.graphic_eq,
                  selected: _voice == 0,
                  onTap: () => setState(() => _voice = 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceTile(
                  label: 'Nữ nhẹ nhàng',
                  icon: Icons.graphic_eq,
                  selected: _voice == 1,
                  onTap: () => setState(() => _voice = 1),
                ),
              ),
            ],
          ),
          _section('MỨC ĐỘ PHẢN HỒI TỪ AI'),
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                  child: ChoiceTile(
                    label: [
                      'Nghiêm khắc\nHardcore',
                      'Cân bằng\nOptimal',
                      'Khích lệ\nMotivating',
                    ][i],
                    selected: _motivation == i,
                    onTap: () => setState(() => _motivation = i),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  'Giọng ${_voice == 0 ? 'Nam trầm' : 'Nữ nhẹ nhàng'}',
                ),
                content: Text(
                  '${['“Tập trung vào kỹ thuật. Chuẩn bị cho hiệp tiếp theo.”', '“Giữ thẳng lưng, hít thở đều, bạn làm tốt lắm!”', '“Bạn đang tiến bộ mỗi ngày. Cùng hoàn thành hiệp này nhé!”'][_motivation]}\n\nNội dung xem trước; giọng đọc chưa được kết nối.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ),
            child: GymCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GymColors.purple.withValues(alpha: .15),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 22,
                      color: GymColors.purple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xem trước giọng đã chọn',
                          style: TextStyle(
                            fontSize: 11,
                            color: GymColors.purple,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '“Giữ thẳng lưng, bạn sẽ vượt qua hiệp tiếp theo!”',
                          style: TextStyle(
                            fontSize: 10,
                            color: GymColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _section('TẦN SUẤT THÔNG BÁO'),
          _notification(
            Icons.water_drop_outlined,
            'Nhắc nhở uống nước',
            _water,
            (v) => setState(() => _water = v),
          ),
          _notification(
            Icons.trending_up,
            'Báo cáo tiến độ tuần',
            _weekly,
            (v) => setState(() => _weekly = v),
          ),
          _notification(
            Icons.vibration,
            'Phản hồi xúc giác (Rung)',
            _haptic,
            (v) => setState(() => _haptic = v),
          ),
          const SizedBox(height: 34),
          PrimaryButton(label: 'Lưu thay đổi', onPressed: _save),
        ],
      ),
    ),
  );

  Widget _notification(
    IconData icon,
    String title,
    bool value,
    ValueChanged<bool> change,
  ) => Container(
    constraints: const BoxConstraints(minHeight: 60),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFF252525))),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: GymColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        _switch(value, change),
      ],
    ),
  );
}

Widget _section(String title) => Padding(
  padding: const EdgeInsets.only(top: 24, bottom: 12),
  child: Text(
    title,
    style: const TextStyle(
      fontSize: 9,
      color: GymColors.muted,
      fontWeight: FontWeight.w600,
      letterSpacing: .4,
    ),
  ),
);

Widget _switch(bool value, ValueChanged<bool> change) => Transform.scale(
  scale: .72,
  alignment: Alignment.centerRight,
  child: Switch(
    value: value,
    onChanged: change,
    activeTrackColor: GymColors.purple,
    activeThumbColor: Colors.white,
    inactiveThumbColor: Colors.white,
    inactiveTrackColor: GymColors.border,
  ),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog();
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController(text: _preferences.name);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Chỉnh sửa hồ sơ'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'Họ và tên'),
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Vui lòng nhập họ và tên.' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      TextButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _name.text.trim());
          }
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
