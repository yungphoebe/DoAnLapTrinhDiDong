import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:ai_gym/models/nutrition.dart';
import 'package:ai_gym/services/api_client.dart';
import 'package:ai_gym/services/nutrition_service.dart';

class _ApiMock extends Mock implements ApiClient {}

void main() {
  test('nutrition food and entry totals are calculated from servings', () {
    final entry = NutritionEntry(
      id: 'meal-1',
      date: DateTime(2026, 10, 18),
      mealType: 'Lunch',
      foods: [
        NutritionFood(name: 'Rice', calories: 260, servings: 2, protein: 5),
      ],
    );
    expect(entry.calories, 520);
    expect(entry.protein, 10);
    expect(entry.toJson()['name'], 'Lunch');
    expect((entry.toJson()['items'] as List), isEmpty);
  });

  test('scan estimate uses the injectable nutrition endpoint', () async {
    final api = _ApiMock();
    when(
      () => api.post('/api/nutrition/scans/analyze', any(), includeAuth: true),
    ).thenAnswer(
      (_) async => http.Response(
        '{"id":"scan","foodName":"Estimated meal","estimatedGrams":100,"calories":200,"protein":10,"carbs":25,"fat":7}',
        201,
      ),
    );
    final foods = await NutritionService(api: api)
        .estimate(image: Uint8List.fromList([1, 2, 3]));
    expect(foods.single.name, 'Estimated meal');
    expect(foods.single.calories, 200);
    verify(
      () => api.post('/api/nutrition/scans/analyze', any(), includeAuth: true),
    ).called(1);
  });
}
