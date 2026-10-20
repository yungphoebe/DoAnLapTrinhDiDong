class NutritionFood {
  NutritionFood({
    required this.name,
    this.id,
    this.servings = 1,
    this.grams,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  factory NutritionFood.fromJson(Map<String, dynamic> json) => NutritionFood(
    name: (json['name'] ?? json['foodName'] ?? '').toString(),
    id: (json['id'] ?? json['foodId'])?.toString(),
    servings: _number(json['servings'] ?? json['quantity'], 1),
    grams: _number(json['grams'], 100),
    calories: _number(json['calories'] ?? json['kcal']),
    protein: _number(json['protein'] ?? json['proteinGrams']),
    carbs: _number(json['carbs'] ?? json['carbohydrates']),
    fat: _number(json['fat'] ?? json['fatGrams']),
  );

  final String name;
  final String? id;
  final double servings;
  final double? grams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  NutritionFood copyWith({
    String? name,
    String? id,
    double? servings,
    double? grams,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) => NutritionFood(
    name: name ?? this.name,
    id: id ?? this.id,
    servings: servings ?? this.servings,
    grams: grams ?? this.grams,
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'id': id,
    'servings': servings,
    'grams': grams,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };

  static double _number(dynamic value, [double fallback = 0]) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
}

class NutritionEntry {
  NutritionEntry({
    required this.id,
    required this.date,
    required this.mealType,
    required this.foods,
    this.note,
  });

  factory NutritionEntry.fromJson(Map<String, dynamic> json) {
    final raw = json['foods'] ?? json['items'] ?? const [];
    return NutritionEntry(
      id: (json['id'] ?? json['entryId'] ?? '').toString(),
      date: DateTime.tryParse(
            (json['date'] ?? json['consumedAt'] ?? json['loggedAt'] ?? '').toString(),
          )?.toLocal() ??
          DateTime.now(),
      mealType: (json['mealType'] ?? json['name'] ?? json['meal'] ?? 'Bữa ăn').toString(),
      foods: raw is List
          ? raw
                .whereType<Map>()
                .map((item) => NutritionFood.fromJson(Map<String, dynamic>.from(item)))
                .toList()
          : const [],
      note: json['note']?.toString(),
    );
  }

  final String id;
  final DateTime date;
  final String mealType;
  final List<NutritionFood> foods;
  final String? note;

  double get calories => foods.fold(0, (sum, food) => sum + food.calories * food.servings);
  double get protein => foods.fold(0, (sum, food) => sum + food.protein * food.servings);
  double get carbs => foods.fold(0, (sum, food) => sum + food.carbs * food.servings);
  double get fat => foods.fold(0, (sum, food) => sum + food.fat * food.servings);

  Map<String, dynamic> toJson() => {
    'name': mealType,
    'consumedAt': date.toUtc().toIso8601String(),
    'items': foods
        .where((food) => food.id != null)
        .map((food) => {
          'foodId': food.id,
          'grams': food.grams ?? food.servings * 100,
        })
        .toList(),
  };
}
