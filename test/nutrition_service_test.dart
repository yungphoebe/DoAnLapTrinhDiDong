import 'dart:typed_data';
import 'dart:convert';

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
    expect((entry.toJson()['items'] as List).single, {
      'name': 'Rice',
      'grams': 200.0,
      'calories': 520.0,
      'protein': 10.0,
      'carbs': 0.0,
      'fat': 0.0,
    });
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
    expect(foods.single.id, isNull);
    verify(
      () => api.post('/api/nutrition/scans/analyze', any(), includeAuth: true),
    ).called(1);
  });

  test(
    'scan weight and custom meal totals survive save without catalog lookup',
    () async {
      final food = NutritionFood.fromJson({
        'id': 'scan-id',
        'foodName': 'Cơm gà',
        'estimatedGrams': 350,
        'calories': 620,
        'protein': 35,
        'carbs': 75,
        'fat': 20,
      });
      expect(food.grams, 350);
      final api = _ApiMock();
      when(() => api.post('/api/nutrition/meals', any(), includeAuth: true))
          .thenAnswer(
            (_) async => http.Response(
              jsonEncode({
                'id': 'meal',
                'name': 'Trưa',
                'consumedAt': '2026-10-20T05:00:00Z',
                'items': [
                  {
                    'id': 'item-id',
                    'foodId': null,
                    'foodName': 'Cơm gà',
                    'grams': 350,
                    'calories': 620,
                    'protein': 35,
                    'carbs': 75,
                    'fat': 20,
                  },
                ],
              }),
              201,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          );
      final result = await NutritionService(api: api).create(
        NutritionEntry(
          id: '',
          date: DateTime(2026, 10, 20),
          mealType: 'Trưa',
          foods: [food],
        ),
      );
      expect(result.calories, 620);
      expect(result.foods.single.id, isNull);
      final payload =
          verify(
                () => api.post(
                  '/api/nutrition/meals',
                  captureAny(),
                  includeAuth: true,
                ),
              ).captured.single
              as Map;
      expect((payload['items'] as List).single, {
        'name': 'Cơm gà',
        'grams': 350.0,
        'calories': 620.0,
        'protein': 35.0,
        'carbs': 75.0,
        'fat': 20.0,
      });
      verifyNever(() => api.get(any(), includeAuth: true));
    },
  );

  test('saved catalog item uses foodId instead of meal item id', () {
    final food = NutritionFood.fromJson({
      'id': 'item',
      'foodId': 'catalog',
      'foodName': 'Rice',
      'grams': 200,
      'calories': 260,
    });
    expect(food.id, 'catalog');
  });

  test('analysis errors show the server message', () async {
    final api = _ApiMock();
    when(
      () => api.post('/api/nutrition/scans/analyze', any(), includeAuth: true),
    ).thenAnswer(
      (_) async => http.Response('{"message":"No food detected"}', 422),
    );
    expect(
      () => NutritionService(api: api).estimate(image: Uint8List.fromList([1])),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'No food detected',
        ),
      ),
    );
  });
}
