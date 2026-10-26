import 'dart:async';
import 'package:ai_gym/models/nutrition.dart';
import 'package:ai_gym/screens/nutrition.dart';
import 'package:ai_gym/services/nutrition_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NutritionFake extends NutritionService {
  NutritionEntry? saved;
  Completer<void>? savePending;
  @override
  Future<List<NutritionEntry>> entries({DateTime? from, DateTime? to}) async =>
      [];
  @override
  Future<Map<String, dynamic>> summary({DateTime? date}) async => {
    'calories': 0,
    'protein': 0,
    'carbs': 0,
    'fat': 0,
  };
  @override
  Future<NutritionEntry> create(NutritionEntry entry) async {
    saved = entry;
    if (savePending != null) await savePending!.future;
    return NutritionEntry(
      id: 'saved',
      date: entry.date,
      mealType: entry.mealType,
      foods: entry.foods,
    );
  }
}

void main() {
  testWidgets('review macros and save manual meal updates daily summary', (
    tester,
  ) async {
    final service = _NutritionFake();
    await tester.pumpWidget(
      MaterialApp(home: NutritionScreen(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhập thủ công'));
    await tester.pumpAndSettle();
    Future<void> fill(String label, String value) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    await fill('Tên món', 'Cơm gà');
    await fill('Khối lượng (g)', '350');
    await fill('Calo (kcal)', '620');
    await fill('Protein (g)', '35');
    await fill('Carb (g)', '75');
    await fill('Fat (g)', '20');
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Protein 35g'), findsOneWidget);
    await tester.ensureVisible(find.text('Lưu bữa ăn'));
    service.savePending = Completer<void>();
    await tester.tap(find.text('Lưu bữa ăn'));
    await tester.pump();
    await tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pump();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Lưu bữa ăn')).onPressed, isNull);
    service.savePending!.complete();
    await tester.pumpAndSettle();
    expect(service.saved!.protein, 35);
    expect(service.saved!.foods.single.grams, 350);
    expect(find.text('620 kcal'), findsWidgets);
    expect(find.text('Protein 35g'), findsOneWidget);
  });
}
