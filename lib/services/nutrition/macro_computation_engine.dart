import '../../models/nutrition_models.dart';
import 'meal_text_parser.dart';
import 'nutrition_database_service.dart';

class MacroComputationEngine {
  final NutritionDatabaseService dbService;

  MacroComputationEngine({NutritionDatabaseService? dbService})
      : dbService = dbService ?? NutritionDatabaseService.instance;

  /// Main entry point: Parses free-form natural language query and computes macros
  Future<MealParseResult> parseAndCompute(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return MealParseResult.empty;
    }

    final tokens = MealTextParser.parse(trimmed);
    if (tokens.isEmpty) {
      return MealParseResult(
        query: trimmed,
        status: ParseStatus.unresolved,
        items: [],
        totalMacros: MacroNutrients.zero,
        unresolvedTokens: [trimmed],
      );
    }

    final items = <ParsedMealItem>[];
    final unresolved = <String>[];

    for (final token in tokens) {
      final match = await dbService.resolveFoodToken(token.foodQuery);
      if (match == null) {
        unresolved.add(token.rawSegment);
        continue;
      }

      final entity = match.entity;
      final effectiveUnit = token.unit ?? entity.standardServingUnit;

      final unitGrams = await dbService.resolveUnitGrams(
        unit: effectiveUnit,
        entityType: entity.entityType,
        entityId: entity.id,
        entityStandardServingGrams: entity.standardServingGrams,
        entityStandardServingUnit: entity.standardServingUnit,
      );

      final totalGrams = token.quantity * unitGrams;
      final scaleMultiplier = totalGrams / 100.0;
      final computedMacros = entity.macrosPer100g.scale(scaleMultiplier);

      items.add(ParsedMealItem(
        rawInput: token.rawSegment,
        resolvedEntity: entity,
        quantity: token.quantity,
        unit: effectiveUnit,
        calculatedGrams: double.parse(totalGrams.toStringAsFixed(1)),
        confidenceScore: match.confidenceScore,
        macros: computedMacros,
        alternates: match.alternates,
      ));
    }

    final totalMacros = items.fold<MacroNutrients>(
      MacroNutrients.zero,
      (sum, item) => sum + item.macros,
    );

    ParseStatus status;
    if (items.isNotEmpty && unresolved.isEmpty) {
      status = ParseStatus.success;
    } else if (items.isNotEmpty && unresolved.isNotEmpty) {
      status = ParseStatus.partial;
    } else {
      status = ParseStatus.unresolved;
    }

    return MealParseResult(
      query: trimmed,
      status: status,
      items: items,
      totalMacros: totalMacros,
      unresolvedTokens: unresolved,
    );
  }

  /// Recalculates an item when user updates quantity, unit, or switches alternate entity
  Future<ParsedMealItem> recalculateItem(
    ParsedMealItem item, {
    double? newQuantity,
    String? newUnit,
    FoodEntity? newEntity,
  }) async {
    final entity = newEntity ?? item.resolvedEntity;
    final quantity = newQuantity ?? item.quantity;
    final unit = newUnit ?? item.unit;

    if (entity == null) {
      return item;
    }

    final unitGrams = await dbService.resolveUnitGrams(
      unit: unit,
      entityType: entity.entityType,
      entityId: entity.id,
      entityStandardServingGrams: entity.standardServingGrams,
      entityStandardServingUnit: entity.standardServingUnit,
    );

    final totalGrams = quantity * unitGrams;
    final scaleMultiplier = totalGrams / 100.0;
    final computedMacros = entity.macrosPer100g.scale(scaleMultiplier);

    return ParsedMealItem(
      rawInput: item.rawInput,
      resolvedEntity: entity,
      quantity: quantity,
      unit: unit,
      calculatedGrams: double.parse(totalGrams.toStringAsFixed(1)),
      confidenceScore: item.confidenceScore,
      macros: computedMacros,
      alternates: item.alternates,
      customizedIngredients: item.customizedIngredients,
    );
  }

  /// Recalculates an item when its recipe ingredients are customized
  ParsedMealItem recalculateWithIngredients({
    required ParsedMealItem item,
    required List<RecipeIngredientItem> updatedIngredients,
    String? updatedCustomName,
  }) {
    double totalGramsUsed = 0.0;
    double totalKcal = 0.0;
    double totalProt = 0.0;
    double totalCarb = 0.0;
    double totalFat = 0.0;

    for (final ing in updatedIngredients) {
      totalGramsUsed += ing.gramsUsed;
      final factor = ing.gramsUsed / 100.0;
      totalKcal += ing.macrosPer100g.calories * factor;
      totalProt += ing.macrosPer100g.proteinG * factor;
      totalCarb += ing.macrosPer100g.carbsG * factor;
      totalFat += ing.macrosPer100g.fatG * factor;
    }

    final servingGrams = totalGramsUsed > 0 ? totalGramsUsed : 100.0;
    final scaleTo100g = 100.0 / servingGrams;

    final updatedMacrosPer100g = MacroNutrients(
      calories: double.parse((totalKcal * scaleTo100g).toStringAsFixed(2)),
      proteinG: double.parse((totalProt * scaleTo100g).toStringAsFixed(2)),
      carbsG: double.parse((totalCarb * scaleTo100g).toStringAsFixed(2)),
      fatG: double.parse((totalFat * scaleTo100g).toStringAsFixed(2)),
    );

    final currentEntity = item.resolvedEntity;
    final updatedEntity = (currentEntity ?? FoodEntity(
      id: 0,
      name: updatedCustomName ?? 'Custom Recipe',
      entityType: EntityType.recipe,
      standardServingUnit: item.unit,
      standardServingGrams: servingGrams,
      macrosPer100g: updatedMacrosPer100g,
      isCustom: true,
      ingredients: updatedIngredients,
    )).copyWith(
      name: updatedCustomName ?? currentEntity?.name,
      standardServingGrams: servingGrams,
      macrosPer100g: updatedMacrosPer100g,
      isCustom: true,
      ingredients: updatedIngredients,
    );

    double effectiveUnitGrams = servingGrams;
    final normalizedUnit = item.unit.toLowerCase().trim();
    if (normalizedUnit == 'plate' && servingGrams < 100.0) {
      effectiveUnitGrams = servingGrams * 2.0;
    } else if (normalizedUnit == 'g' || normalizedUnit == 'gram') {
      effectiveUnitGrams = 1.0;
    } else if (normalizedUnit == 'kg') {
      effectiveUnitGrams = 1000.0;
    }

    final calculatedGrams = item.quantity * effectiveUnitGrams;
    final scaleMultiplier = calculatedGrams / 100.0;
    final itemMacros = updatedMacrosPer100g.scale(scaleMultiplier);

    return ParsedMealItem(
      rawInput: item.rawInput,
      resolvedEntity: updatedEntity,
      quantity: item.quantity,
      unit: item.unit,
      calculatedGrams: double.parse(calculatedGrams.toStringAsFixed(1)),
      confidenceScore: item.confidenceScore,
      macros: itemMacros,
      alternates: item.alternates,
      customizedIngredients: updatedIngredients,
    );
  }
}
