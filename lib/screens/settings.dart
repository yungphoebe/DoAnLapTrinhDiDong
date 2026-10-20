import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/profile_service.dart';
import '../services/health_service.dart';
import '../models/health_workout.dart';
import '../services/coach_voice_service.dart';

// Session-only preferences for the UI demo.
var _preferences = _Preferences();

class _Preferences {
  int voice = 0, motivation = 1;
  bool water = true, weekly = true, haptic = false, sound = true;
  bool reminder = true, camera = true;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _health = HealthService();
  HealthIntegrationStatus? _healthStatus;

  Future<void> _connectHealth() async {
    final status = await _health.requestPermission();
    if (!mounted) return;
    setState(() => _healthStatus = status);
    final message = switch (status.state) {
      HealthIntegrationState.ready => 'Đã kết nối dữ liệu sức khỏe.',
      HealthIntegrationState.unsupported =>
        'Thiết bị không hỗ trợ Health Connect hoặc Apple Health.',
      HealthIntegrationState.permissionDenied =>
        'Quyền sức khỏe bị từ chối. Bạn có thể cấp lại trong cài đặt thiết bị.',
      HealthIntegrationState.error =>
        'Không thể kết nối: ${status.message ?? 'lỗi không xác định'}.',
      HealthIntegrationState.permissionRequired =>
        'Cần cấp quyền sức khỏe để đồng bộ.',
    };
    if (mounted) showMessage(context, message);
  }

  @override
  void initState() {
    super.initState();
    if (ProfileService.instance.profile == null &&
        ApiClient.instance.token != null) {
      Future.microtask(ProfileService.instance.load);
    }
  }

  Future<void> _editProfile() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(),
    );
    if (!mounted || name == null) return;
    try {
      await ProfileService.instance.save({'fullName': name});
      if (mounted) showMessage(context, 'Đã lưu hồ sơ.');
    } catch (error) {
      if (mounted) showMessage(context, 'Không thể lưu hồ sơ: $error');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ProfileService.instance,
    builder: (context, _) => Scaffold(
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
                    child: Icon(Icons.person_outline),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ProfileService.instance.profile?['fullName']
                                  as String? ??
                              'Chưa có dữ liệu',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ProfileService.instance.profile?['email']
                                  as String? ??
                              'Chưa có dữ liệu',
                          style: const TextStyle(
                            fontSize: 10,
                            color: GymColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed:
                        ProfileService.instance.loading ||
                            ProfileService.instance.profile == null
                        ? null
                        : _editProfile,
                    child: const Text(
                      'Chỉnh sửa',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            if (ProfileService.instance.error != null)
              TextButton(
                onPressed: ProfileService.instance.load,
                child: Text('${ProfileService.instance.error} · Thử lại'),
              ),
            _section('THÔNG TIN CƠ THỂ & MỤC TIÊU'),
            _row(
              Icons.height,
              'Chiều cao',
              value: _profileValue('heightCm', ' cm'),
            ),
            _row(
              Icons.monitor_weight_outlined,
              'Cân nặng',
              value: _profileValue('weightKg', ' kg'),
            ),
            _row(Icons.cake_outlined, 'Tuổi', value: _profileValue('age')),
            _row(
              Icons.person_outline,
              'Giới tính',
              value: _profileValue('gender'),
            ),
            _row(Icons.flag_outlined, 'Mục tiêu', value: _profileValue('goal')),
            _row(
              Icons.calendar_today,
              'Lịch tập',
              value: _profileValue('trainingDays', ' buổi/tuần'),
            ),
            _row(
              Icons.fitness_center,
              'Trình độ',
              value: _profileValue('trainingLevel'),
            ),
            _row(
              Icons.place_outlined,
              'Địa điểm tập',
              value: _profileValue('trainingLocation'),
            ),
            TextButton(
              onPressed: ProfileService.instance.profile == null
                  ? null
                  : () => Navigator.pushNamed(context, '/onboarding'),
              child: const Text('Cập nhật thông tin cơ thể & mục tiêu'),
            ),
            _section('TÀI KHOẢN'),
            _row(
              Icons.history,
              'Lịch sử tập luyện',
              onTap: () => Navigator.pushNamed(context, '/workout-history'),
            ),
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
              onTap: () => showMessage(
                context,
                'Chỉ số trong bản mẫu sử dụng kg và cm.',
              ),
            ),
            _section('AI COACH & HUẤN LUYỆN'),
            _row(
              Icons.restaurant_outlined,
              'Nhật ký dinh dưỡng',
              value: 'Calo & macro',
              onTap: () => Navigator.pushNamed(context, '/nutrition'),
            ),
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
              trailing: _switch(
                _preferences.reminder,
                (v) => setState(() => _preferences.reminder = v),
              ),
            ),
            _row(
              Icons.monitor_heart_outlined,
              'Đồng bộ sức khỏe',
              value: _healthStatus?.state == HealthIntegrationState.ready
                  ? 'Đã kết nối'
                  : 'Chưa kết nối',
              onTap: _connectHealth,
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
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('AI GYM — bản giao diện'),
                  content: const Text(
                    'Khám phá các trang bằng thanh điều hướng. Dữ liệu tập luyện, hội thoại, thông báo và kết nối huấn luyện viên đều được minh họa trong phiên này.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              ),
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
                _preferences = _Preferences();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text(
                'Đăng xuất tài khoản',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Phiên bản giao diện 1.0.0 | AI GYM',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: GymColors.muted),
            ),
          ],
        ),
      ),
    ),
  );

  String _profileValue(String key, [String unit = '']) {
    final value = ProfileService.instance.profile?[key];
    return value == null ? 'Chưa có dữ liệu' : '$value$unit';
  }

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
  final _voiceService = CoachVoiceService();
  late int _voice = _preferences.voice;
  late int _motivation = _preferences.motivation;
  late bool _water = _preferences.water,
      _weekly = _preferences.weekly,
      _haptic = _preferences.haptic,
      _sound = _preferences.sound;
  List<Map<String, String>> _voices = [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _voice = preferences.getInt('coach.voice') ?? _voice;
      _motivation = preferences.getInt('coach.motivation') ?? _motivation;
      _water = preferences.getBool('coach.water') ?? _water;
      _weekly = preferences.getBool('coach.weekly') ?? _weekly;
      _haptic = preferences.getBool('coach.haptic') ?? _haptic;
      _sound = preferences.getBool('coach.sound') ?? _sound;
    });
    final voices = await _voiceService.voices();
    if (mounted) setState(() => _voices = voices);
  }

  Future<void> _save() async {
    _preferences
      ..voice = _voice
      ..motivation = _motivation
      ..water = _water
      ..weekly = _weekly
      ..haptic = _haptic
      ..sound = _sound;
    final preferences = await SharedPreferences.getInstance();
    await preferences
        .setInt('coach.voice', _voice)
        .then(
          (_) => _voices.isEmpty
              ? Future.value(true)
              : preferences.setString(
                  'coach.voiceName',
                  _voices[_voice.clamp(0, _voices.length - 1)]['name']!,
                ),
        )
        .then(
          (_) => _voices.isEmpty
              ? Future.value(true)
              : preferences.setString(
                  'coach.voiceLocale',
                  _voices[_voice.clamp(0, _voices.length - 1)]['locale']!,
                ),
        )
        .then((_) => preferences.setInt('coach.motivation', _motivation))
        .then((_) => preferences.setBool('coach.water', _water))
        .then((_) => preferences.setBool('coach.weekly', _weekly))
        .then((_) => preferences.setBool('coach.haptic', _haptic))
        .then((_) => preferences.setBool('coach.sound', _sound));
    if (!mounted) return;
    Navigator.pop(context);
    showMessage(context, 'Đã lưu cài đặt Coach.');
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
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
            onTap: () async {
              if (!_sound) {
                showMessage(context, 'Hãy bật giọng đọc trước khi nghe thử.');
                return;
              }
              final text = 'Giữ thẳng lưng, bạn sẽ vượt qua hiệp tiếp theo!';
              await _voiceService.speak(
                text,
                voiceName: _voices.isEmpty
                    ? null
                    : _voices[_voice.clamp(0, _voices.length - 1)]['name'],
                locale: _voices.isEmpty
                    ? 'vi-VN'
                    : _voices[_voice.clamp(0, _voices.length - 1)]['locale'],
              );
            },
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
          _notification(
            Icons.volume_up_outlined,
            'Đọc phản hồi bằng giọng nói',
            _sound,
            (v) => setState(() => _sound = v),
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
  final _name = TextEditingController(
    text: ProfileService.instance.profile?['fullName'] as String? ?? '',
  );
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
