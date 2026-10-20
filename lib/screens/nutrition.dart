import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/nutrition.dart';
import '../services/nutrition_service.dart';
import '../ui.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key, this.service});
  final NutritionService? service;

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  late final NutritionService _service = widget.service ?? NutritionService();
  final _picker = ImagePicker();
  List<NutritionEntry> _entries = [];
  Map<String, dynamic>? _dailySummary;
  Uint8List? _preview;
  List<NutritionFood> _foods = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final entries = await _service.entries();
      Map<String, dynamic>? summary;
      try {
        summary = await _service.summary();
      } catch (_) {
        summary = null;
      }
      if (mounted) {
        setState(() {
          _entries = entries;
          _dailySummary = summary;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _preview = bytes;
        _foods = [];
        _error = null;
        _loading = true;
      });
      final foods = await _service.estimate(
        image: bytes,
        mimeType: _mime(file.name),
      );
      if (mounted) setState(() => _foods = foods);
    } catch (error) {
      if (mounted) setState(() => _error = 'Không thể phân tích ảnh: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mime(String name) =>
      name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

  Future<void> _addManual() async {
    final food = await showDialog<NutritionFood>(
      context: context,
      builder: (_) => const _FoodDialog(),
    );
    if (food != null) setState(() => _foods = [..._foods, food]);
  }

  Future<void> _save() async {
    if (_foods.isEmpty) return;
    setState(() => _loading = true);
    try {
      final entry = await _service.create(
        NutritionEntry(
          id: '',
          date: DateTime.now(),
          mealType: 'Bữa ăn',
          foods: _foods,
        ),
      );
      if (!mounted) return;
      setState(() {
        _entries = [entry, ..._entries];
        _preview = null;
        _foods = [];
      });
      showMessage(context, 'Đã lưu bữa ăn vào nhật ký.');
    } catch (error) {
      if (mounted) setState(() => _error = 'Không thể lưu bữa ăn: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(NutritionEntry entry) async {
    try {
      await _service.delete(entry.id);
      if (mounted) setState(() => _entries.remove(entry));
    } catch (error) {
      if (mounted) showMessage(context, 'Không thể xóa: $error');
    }
  }

  Future<void> _editEntry(NutritionEntry entry) async {
    if (entry.foods.isEmpty) return;
    final food = await showDialog<NutritionFood>(
      context: context,
      builder: (_) => _FoodDialog(initial: entry.foods.first),
    );
    if (food == null) return;
    try {
      final updated = await _service.update(
        NutritionEntry(
          id: entry.id,
          date: entry.date,
          mealType: entry.mealType,
          foods: [food, ...entry.foods.skip(1)],
        ),
      );
      if (mounted) {
        setState(() {
          final index = _entries.indexOf(entry);
          if (index >= 0) _entries[index] = updated;
        });
      }
    } catch (error) {
      if (mounted) showMessage(context, 'Không thể cập nhật: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _entries
        .where((e) => _sameDay(e.date, DateTime.now()))
        .toList();
    final calories =
        (_dailySummary?['calories'] as num?)?.toDouble() ??
        today.fold<double>(0, (sum, e) => sum + e.calories);
    final protein =
        (_dailySummary?['protein'] as num?)?.toDouble() ??
        today.fold<double>(0, (sum, e) => sum + e.protein);
    final carbs =
        (_dailySummary?['carbs'] as num?)?.toDouble() ??
        today.fold<double>(0, (sum, e) => sum + e.carbs);
    final fat =
        (_dailySummary?['fat'] as num?)?.toDouble() ??
        today.fold<double>(0, (sum, e) => sum + e.fat);
    return Scaffold(
      appBar: AppBar(title: const Text('Dinh dưỡng')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _summary(calories, protein, carbs, fat),
            const SizedBox(height: 14),
            if (_preview != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(_preview!, height: 180, fit: BoxFit.cover),
              ),
              const SizedBox(height: 10),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.orange)),
              ..._foods.asMap().entries.map(
                (item) => _foodTile(item.key, item.value),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addManual,
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm món'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading || _foods.isEmpty ? null : _save,
                      child: const Text('Lưu bữa ăn'),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => setState(() {
                  _preview = null;
                  _foods = [];
                }),
                child: const Text('Chụp lại / chọn ảnh khác'),
              ),
            ] else ...[
              GymCard(
                child: Column(
                  children: [
                    const Text(
                      'Ghi lại bữa ăn để theo dõi calo và chất dinh dưỡng.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _loading
                                ? null
                                : () => _pick(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Chụp ảnh'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : () => _pick(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Thư viện'),
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _addManual,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Nhập thủ công'),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.orange)),
            ],
            const SectionHeading(title: 'Nhật ký theo ngày'),
            if (_loading && _entries.isEmpty)
              const Center(child: CircularProgressIndicator()),
            if (_entries.isEmpty && !_loading)
              const GymCard(
                child: Text(
                  'Chưa có bữa ăn nào được ghi nhận.',
                  style: TextStyle(color: GymColors.muted),
                ),
              ),
            ..._groupedEntries(),
          ],
        ),
      ),
    );
  }

  Widget _summary(
    double calories,
    double protein,
    double carbs,
    double fat,
  ) => GymCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TỔNG QUAN HÔM NAY',
          style: TextStyle(fontSize: 11, color: GymColors.muted),
        ),
        const SizedBox(height: 6),
        Text(
          '${calories.round()} kcal',
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
        ),
        if (_dailySummary?['calorieTarget'] is num)
          Text(
            'Mục tiêu ${(_dailySummary!['calorieTarget'] as num).round()} kcal · '
            'còn lại ${((_dailySummary!['calorieTarget'] as num).toDouble() - calories).round()} kcal',
            style: const TextStyle(color: GymColors.muted, fontSize: 12),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 22,
          children: [
            _macro('Protein', protein),
            _macro('Carb', carbs),
            _macro('Fat', fat),
          ],
        ),
      ],
    ),
  );

  Widget _macro(String label, double value) => Text(
    '$label ${value.round()}g',
    style: const TextStyle(color: GymColors.muted, fontSize: 12),
  );

  Widget _foodTile(int index, NutritionFood food) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(food.name.isEmpty ? 'Món ăn' : food.name),
    subtitle: Text(
      '${food.calories.round()} kcal · ${food.servings} khẩu phần',
    ),
    trailing: IconButton(
      icon: const Icon(Icons.edit_outlined),
      onPressed: () async {
        final edited = await showDialog<NutritionFood>(
          context: context,
          builder: (_) => _FoodDialog(initial: food),
        );
        if (edited != null) setState(() => _foods[index] = edited);
      },
    ),
  );

  List<Widget> _groupedEntries() {
    final groups = <String, List<NutritionEntry>>{};
    for (final entry in _entries) {
      final key = '${entry.date.year}-${entry.date.month}-${entry.date.day}';
      groups.putIfAbsent(key, () => []).add(entry);
    }
    return groups.entries
        .map(
          (group) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dateLabel(group.value.first.date),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              ...group.value.map(
                (entry) => Dismissible(
                  key: ValueKey(entry.id),
                  onDismissed: (_) => _delete(entry),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    child: const Icon(Icons.delete),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.mealType),
                    subtitle: Text(entry.foods.map((f) => f.name).join(', ')),
                    trailing: Text('${entry.calories.round()} kcal'),
                    onTap: () => _editEntry(entry),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        )
        .toList();
  }

  String _dateLabel(DateTime date) => _sameDay(date, DateTime.now())
      ? 'Hôm nay'
      : '${date.day}/${date.month}/${date.year}';
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _FoodDialog extends StatefulWidget {
  const _FoodDialog({this.initial});
  final NutritionFood? initial;
  @override
  State<_FoodDialog> createState() => _FoodDialogState();
}

class _FoodDialogState extends State<_FoodDialog> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _calories = TextEditingController(
    text: '${widget.initial?.calories ?? ''}',
  );
  late final _servings = TextEditingController(
    text: '${widget.initial?.servings ?? 1}',
  );
  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _servings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Món ăn'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Tên món'),
        ),
        TextField(
          controller: _calories,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Calo (kcal)'),
        ),
        TextField(
          controller: _servings,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Khẩu phần'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          NutritionFood(
            name: _name.text.trim(),
            calories: double.tryParse(_calories.text) ?? 0,
            servings: double.tryParse(_servings.text) ?? 1,
          ),
        ),
        child: const Text('Thêm'),
      ),
    ],
  );
}
