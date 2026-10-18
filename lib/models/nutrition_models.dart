import 'dart:convert';

enum EntityType { recipe, ingredient }

enum ParseStatus { success, partial, unresolved }

class MacroNutrients {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const MacroNutrients({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  static const zero = MacroNutrients(calories: 0, proteinG: 0, carbsG: 0, fatG: 0);

  MacroNutrients operator +(MacroNutrients other) {
    return MacroNutrients(
      calories: double.parse((calories + other.calories).toStringAsFixed(2)),
      proteinG: double.parse((proteinG + other.proteinG).toStringAsFixed(2)),
      carbsG: double.parse((carbsG + other.carbsG).toStringAsFixed(2)),
      fatG: double.parse((fatG + other.fatG).toStringAsFixed(2)),
    );
  }

  MacroNutrients scale(double factor) {
    return MacroNutrients(
      calories: double.parse((calories * factor).toStringAsFixed(2)),
      proteinG: double.parse((proteinG * factor).toStringAsFixed(2)),
      carbsG: double.parse((carbsG * factor).toStringAsFixed(2)),
      fatG: double.parse((fatG * factor).toStringAsFixed(2)),
    );
  }

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };

  factory MacroNutrients.fromJson(Map<String, dynamic> json) => MacroNutrients(
        calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
        proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
        carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
        fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
      );
}

class RecipeIngredientItem {
  final int ingredientId;
  final String name;
  double gramsUsed;
  final MacroNutrients macrosPer100g;

  RecipeIngredientItem({
    required this.ingredientId,
    required this.name,
    required this.gramsUsed,
    required this.macrosPer100g,
  });

  MacroNutrients get macros => macrosPer100g.scale(gramsUsed / 100.0);

  RecipeIngredientItem copyWith({
    int? ingredientId,
    String? name,
    double? gramsUsed,
    MacroNutrients? macrosPer100g,
  }) {
    return RecipeIngredientItem(
      ingredientId: ingredientId ?? this.ingredientId,
      name: name ?? this.name,
      gramsUsed: gramsUsed ?? this.gramsUsed,
      macrosPer100g: macrosPer100g ?? this.macrosPer100g,
    );
  }

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'name': name,
        'grams_used': gramsUsed,
        'macros_per_100g': macrosPer100g.toJson(),
      };

  factory RecipeIngredientItem.fromJson(Map<String, dynamic> json) => RecipeIngredientItem(
        ingredientId: json['ingredient_id'] as int,
        name: json['name'] as String,
        gramsUsed: (json['grams_used'] as num).toDouble(),
        macrosPer100g: MacroNutrients.fromJson(json['macros_per_100g'] as Map<String, dynamic>),
      );
}

class FoodEntity {
  final int id;
  final String name;
  final EntityType entityType;
  final String standardServingUnit;
  final double standardServingGrams;
  final MacroNutrients macrosPer100g;
  final bool isCanonicalDefault;
  final int popularityRank;
  final bool isCustom;
  final List<RecipeIngredientItem> ingredients;

  const FoodEntity({
    required this.id,
    required this.name,
    required this.entityType,
    required this.standardServingUnit,
    required this.standardServingGrams,
    required this.macrosPer100g,
    this.isCanonicalDefault = false,
    this.popularityRank = 100,
    this.isCustom = false,
    this.ingredients = const [],
  });

  FoodEntity copyWith({
    int? id,
    String? name,
    EntityType? entityType,
    String? standardServingUnit,
    double? standardServingGrams,
    MacroNutrients? macrosPer100g,
    bool? isCanonicalDefault,
    int? popularityRank,
    bool? isCustom,
    List<RecipeIngredientItem>? ingredients,
  }) {
    return FoodEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      entityType: entityType ?? this.entityType,
      standardServingUnit: standardServingUnit ?? this.standardServingUnit,
      standardServingGrams: standardServingGrams ?? this.standardServingGrams,
      macrosPer100g: macrosPer100g ?? this.macrosPer100g,
      isCanonicalDefault: isCanonicalDefault ?? this.isCanonicalDefault,
      popularityRank: popularityRank ?? this.popularityRank,
      isCustom: isCustom ?? this.isCustom,
      ingredients: ingredients ?? this.ingredients,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'entity_type': entityType.name.toUpperCase(),
        'standard_serving_unit': standardServingUnit,
        'standard_serving_grams': standardServingGrams,
        'macros_per_100g': macrosPer100g.toJson(),
        'is_canonical_default': isCanonicalDefault,
        'popularity_rank': popularityRank,
        'is_custom': isCustom,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
      };
}

class AlternateEntity {
  final int entityId;
  final String name;
  final EntityType entityType;
  final double confidenceScore;
  final bool isCustom;

  const AlternateEntity({
    required this.entityId,
    required this.name,
    required this.entityType,
    required this.confidenceScore,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
        'entity_id': entityId,
        'name': name,
        'entity_type': entityType.name.toUpperCase(),
        'confidence_score': confidenceScore,
        'is_custom': isCustom,
      };
}

class ParsedMealItem {
  final String rawInput;
  FoodEntity? resolvedEntity;
  double quantity;
  String unit;
  double calculatedGrams;
  double confidenceScore;
  MacroNutrients macros;
  List<AlternateEntity> alternates;
  List<RecipeIngredientItem> customizedIngredients;

  ParsedMealItem({
    required this.rawInput,
    this.resolvedEntity,
    required this.quantity,
    required this.unit,
    required this.calculatedGrams,
    required this.confidenceScore,
    required this.macros,
    List<AlternateEntity>? alternates,
    List<RecipeIngredientItem>? customizedIngredients,
  })  : alternates = alternates ?? [],
        customizedIngredients = customizedIngredients ??
            (resolvedEntity?.ingredients.map((i) => i.copyWith()).toList() ?? []);

  bool get isResolved => resolvedEntity != null;
  bool get isCustom => resolvedEntity?.isCustom ?? false;

  Map<String, dynamic> toJson() => {
        'raw_input': rawInput,
        'resolved_entity_id': resolvedEntity?.id,
        'entity_name': resolvedEntity?.name ?? 'Unresolved',
        'entity_type': resolvedEntity?.entityType.name.toUpperCase() ?? 'UNKNOWN',
        'quantity': quantity,
        'unit': unit,
        'calculated_grams': calculatedGrams,
        'confidence_score': confidenceScore,
        'is_custom': isCustom,
        'macros': macros.toJson(),
        'alternates': alternates.map((a) => a.toJson()).toList(),
        'customized_ingredients': customizedIngredients.map((i) => i.toJson()).toList(),
      };
}

class MealParseResult {
  final String query;
  final ParseStatus status;
  final List<ParsedMealItem> items;
  final MacroNutrients totalMacros;
  final List<String> unresolvedTokens;

  const MealParseResult({
    required this.query,
    required this.status,
    required this.items,
    required this.totalMacros,
    required this.unresolvedTokens,
  });

  static const empty = MealParseResult(
    query: '',
    status: ParseStatus.unresolved,
    items: [],
    totalMacros: MacroNutrients.zero,
    unresolvedTokens: [],
  );

  Map<String, dynamic> toJson() => {
        'query': query,
        'status': status.name.toUpperCase(),
        'items': items.map((i) => i.toJson()).toList(),
        'total_macros': totalMacros.toJson(),
        'unresolved_tokens': unresolvedTokens,
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
