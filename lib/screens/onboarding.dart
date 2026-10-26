import 'package:flutter/material.dart';

import '../ui.dart';
import '../services/profile_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  int _goal = 0;
  String _sex = 'Nam';
  int _age = 24;
  double _height = 176;
  double _weight = 72.5;
  String _level = 'Trung cấp';
  int _days = 3;
  String _location = 'Phòng Gym';
  bool _saving = false;
  bool _loading = false;
  static const _goalNames = ['Tăng cơ bắp', 'Giảm mỡ thừa', 'Tăng sức bền'];

  @override
  void initState() {
    super.initState();
    if (ProfileService.instance.profile == null) {
      _loading = true;
      Future.microtask(ProfileService.instance.load).then((_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _readProfile();
        });
      });
    } else {
      _readProfile();
    }
  }

  void _readProfile() {
    final profile = ProfileService.instance.profile;
    if (profile == null) return;
    final goal = _goalNames.indexOf(profile['goal'] as String? ?? '');
    if (goal >= 0) _goal = goal;
    _sex = profile['gender'] as String? ?? _sex;
    _age = (profile['age'] as num?)?.toInt() ?? _age;
    _height = (profile['heightCm'] as num?)?.toDouble() ?? _height;
    _weight = (profile['weightKg'] as num?)?.toDouble() ?? _weight;
    _level = profile['trainingLevel'] as String? ?? _level;
    _days = (profile['trainingDays'] as num?)?.toInt() ?? _days;
    _location = profile['trainingLocation'] as String? ?? _location;
  }

  void _back() {
    if (_saving) return;
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.maybePop(context);
    }
  }

  void _skip() =>
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ProfileService.instance.save({
        'fullName': ProfileService.instance.profile?['fullName'],
        'age': _age,
        'heightCm': _height,
        'weightKg': _weight,
        'gender': _sex,
        'goal': _goalNames[_goal],
        'trainingDays': _days,
        'trainingLevel': _level,
        'trainingLocation': _location,
      });
      if (mounted) _skip();
    } catch (error) {
      if (mounted) showMessage(context, 'Không thể lưu hồ sơ: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _loading
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : PopScope(
          canPop: _step == 0 && !_saving,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _step > 0) _back();
          },
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      children: [
                        CircleBackButton(onPressed: _back),
                        Expanded(
                          child: Text(
                            [
                              'Thiết lập mục tiêu',
                              'Chỉ số cá nhân',
                              'Thiết lập lịch tập',
                            ][_step],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    child: Row(
                      children: List.generate(
                        3,
                        (index) => Expanded(
                          child: Container(
                            height: 3,
                            margin: EdgeInsets.only(right: index < 2 ? 7 : 0),
                            decoration: BoxDecoration(
                              color: index <= _step
                                  ? GymColors.purple
                                  : GymColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BƯỚC ${_step + 1}/3',
                            style: const TextStyle(
                              color: GymColors.purple,
                              fontSize: 11,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            [
                              'Mục tiêu chính của bạn là gì?',
                              'Thông tin cơ thể của bạn',
                              'Phong cách tập & Lịch trình',
                            ][_step],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            [
                              'AI sẽ cá nhân hóa lịch tập và chế độ dinh dưỡng để giúp bạn đạt mục tiêu nhanh hơn.',
                              'Thông tin giúp AI tính lượng calo cần thiết mỗi ngày (TDEE) và xây dựng lộ trình phù hợp.',
                              'Một kế hoạch phù hợp với lối sống của bạn là khởi đầu cho thói quen bền vững.',
                            ][_step],
                            style: const TextStyle(
                              color: GymColors.muted,
                              fontSize: 12,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (_step == 0) ..._goals(),
                          if (_step == 1) ..._bodyMetrics(),
                          if (_step == 2) ..._schedule(),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (_step == 1) ...[
                              Expanded(
                                flex: 2,
                                child: OutlinedButton(
                                  onPressed: _back,
                                  child: const Text(
                                    'Quay lại',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              flex: _step == 2 ? 4 : 3,
                              child: PrimaryButton(
                                label: _saving
                                    ? 'Đang lưu...'
                                    : _step == 2
                                    ? 'Tạo kế hoạch của tôi'
                                    : 'Tiếp tục',
                                onPressed: _saving
                                    ? null
                                    : _step == 2
                                    ? _finish
                                    : () => setState(() => _step++),
                                icon: _step == 2
                                    ? null
                                    : Icons.arrow_forward_rounded,
                              ),
                            ),
                          ],
                        ),
                        if (_step == 0) ...[
                          const SizedBox(height: 9),
                          TextButton(
                            onPressed: _skip,
                            child: const Text(
                              'Bỏ qua thiết lập',
                              style: TextStyle(
                                fontSize: 12,
                                color: GymColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

  List<Widget> _goals() {
    const goals = [
      (
        'Tăng cơ bắp',
        'Xây dựng cơ bắp, cải thiện sức mạnh và vóc dáng.',
        Icons.fitness_center_rounded,
      ),
      (
        'Giảm mỡ thừa',
        'Đốt cháy calo, giảm mỡ và giữ cơ thể săn chắc.',
        Icons.local_fire_department_outlined,
      ),
      (
        'Tăng sức bền',
        'Nâng cao thể lực và sức khỏe tim mạch.',
        Icons.favorite_border_rounded,
      ),
    ];
    return List.generate(goals.length, (index) {
      final selected = _goal == index;
      final (title, description, icon) = goals[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? const Color(0xFF281D34) : GymColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: selected ? GymColors.purple : GymColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _goal = index),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF45265E)
                            : const Color(0xFF2B2B2B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 24,
                        color: selected ? GymColors.purple : GymColors.muted,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            description,
                            style: const TextStyle(
                              color: GymColors.muted,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 9),
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 19,
                      color: selected ? GymColors.purple : GymColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _bodyMetrics() => [
    _label('Giới tính sinh học'),
    Row(
      children: [
        for (final sex in ['Nam', 'Nữ']) ...[
          if (sex == 'Nữ') const SizedBox(width: 12),
          Expanded(
            child: ChoiceTile(
              label: sex,
              icon: sex == 'Nam' ? Icons.male : Icons.female,
              selected: _sex == sex,
              onTap: () => setState(() => _sex = sex),
            ),
          ),
        ],
      ],
    ),
    const SizedBox(height: 16),
    _metric(
      'Tuổi của bạn',
      'Tính theo năm dương lịch',
      '$_age',
      '',
      decreaseTooltip: 'Giảm tuổi',
      increaseTooltip: 'Tăng tuổi',
      decrease: _age > 10 ? () => setState(() => _age--) : null,
      increase: _age < 100 ? () => setState(() => _age++) : null,
    ),
    const SizedBox(height: 14),
    _metric(
      'Chiều cao',
      'Đơn vị đo chuẩn',
      _height.toStringAsFixed(0),
      'cm',
      onTap: _editHeight,
    ),
    const SizedBox(height: 14),
    _metric(
      'Cân nặng hiện tại',
      'Ảnh hưởng trực tiếp lộ trình tập',
      _weight.toStringAsFixed(1),
      'kg',
      decreaseTooltip: 'Giảm cân nặng',
      increaseTooltip: 'Tăng cân nặng',
      decrease: _weight > 30 ? () => setState(() => _weight -= .5) : null,
      increase: _weight < 250 ? () => setState(() => _weight += .5) : null,
    ),
    const SizedBox(height: 25),
    const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, size: 14, color: GymColors.muted),
        SizedBox(width: 7),
        Expanded(
          child: Text(
            'Kiểm tra và điều chỉnh các thông số đúng với bạn. Thông tin chỉ được lưu vào tài khoản khi bạn hoàn tất thiết lập.',
            style: TextStyle(color: GymColors.muted, fontSize: 10, height: 1.5),
          ),
        ),
      ],
    ),
  ];

  Widget _metric(
    String title,
    String subtitle,
    String value,
    String unit, {
    VoidCallback? decrease,
    VoidCallback? increase,
    VoidCallback? onTap,
    String? decreaseTooltip,
    String? increaseTooltip,
  }) => GymCard(
    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 9, color: GymColors.muted),
              ),
            ],
          ),
        ),
        if (decreaseTooltip != null)
          IconButton(
            tooltip: decreaseTooltip,
            onPressed: decrease,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF2B2B2B),
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.remove, size: 16),
          ),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (unit.isNotEmpty)
                  Text(
                    ' $unit',
                    style: TextStyle(
                      fontSize: 10,
                      color: onTap == null ? GymColors.muted : GymColors.purple,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (increaseTooltip != null)
          IconButton(
            tooltip: increaseTooltip,
            onPressed: increase,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF2B2B2B),
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.add, size: 16),
          ),
      ],
    ),
  );

  List<Widget> _schedule() => [
    _label('Trình độ hiện tại'),
    _choices(
      ['Cơ bản', 'Trung cấp', 'Nâng cao'],
      _level,
      (value) => setState(() => _level = value),
    ),
    const SizedBox(height: 24),
    _label('Số buổi tập mỗi tuần'),
    _choices(
      ['2 buổi', '3 buổi', '4 buổi', '5 buổi'],
      '$_days buổi',
      (value) => setState(() => _days = int.parse(value.substring(0, 1))),
    ),
    const SizedBox(height: 24),
    _label('Địa điểm tập luyện'),
    Row(
      children: [
        Expanded(
          child: ChoiceTile(
            label: 'Phòng Gym',
            icon: Icons.fitness_center_rounded,
            selected: _location == 'Phòng Gym',
            onTap: () => setState(() => _location = 'Phòng Gym'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ChoiceTile(
            label: 'Tại nhà',
            icon: Icons.home_outlined,
            selected: _location == 'Tại nhà',
            onTap: () => setState(() => _location = 'Tại nhà'),
          ),
        ),
      ],
    ),
    const SizedBox(height: 28),
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF261C32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF52306F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: GymColors.purple,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ĐỀ XUẤT DÀNH CHO BẠN',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: .5,
                    color: GymColors.purple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            'Lộ trình $_days buổi/tuần',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '$_level • $_location\n${_days <= 3 ? 'Tập toàn thân xen kẽ ngày nghỉ.' : 'Luân phiên thân trên và thân dưới.'} '
            '${_goal == 1
                ? 'Kết hợp cardio nhẹ sau buổi tập.'
                : _goal == 2
                ? 'Tăng dần thời lượng vận động.'
                : 'Tăng dần cường độ theo khả năng.'}',
            style: const TextStyle(
              color: GymColors.muted,
              fontSize: 11,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nhấn “Tạo kế hoạch của tôi” để lưu thông tin và lịch tập vào tài khoản.',
            style: TextStyle(color: GymColors.muted, fontSize: 9),
          ),
        ],
      ),
    ),
  ];

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    ),
  );

  Widget _choices(
    List<String> values,
    String selected,
    ValueChanged<String> onChanged,
  ) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < values.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: ChoiceTile(
              label: values[index],
              selected: values[index] == selected,
              onTap: () => onChanged(values[index]),
            ),
          ),
        ],
      ],
    ),
  );

  Future<void> _editHeight() async {
    var draft = _height;
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Chiều cao'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${draft.round()} cm',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: GymColors.purple,
                ),
              ),
              Slider(
                value: draft,
                min: 100,
                max: 230,
                divisions: 130,
                label: '${draft.round()} cm',
                onChanged: (value) => update(() => draft = value),
              ),
              const Text(
                'Kéo thanh để điều chỉnh chiều cao.',
                style: TextStyle(fontSize: 11, color: GymColors.muted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, draft),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) setState(() => _height = result);
  }
}
