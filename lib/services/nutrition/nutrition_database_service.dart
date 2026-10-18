import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/nutrition_models.dart';

class EntitySearchResult {
  final FoodEntity entity;
  final double confidenceScore;
  final List<AlternateEntity> alternates;

  const EntitySearchResult({
    required this.entity,
    required this.confidenceScore,
    required this.alternates,
  });
}

class NutritionDatabaseService {
  static final NutritionDatabaseService instance = NutritionDatabaseService._internal();

  NutritionDatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  /// Optional override for testing with direct file path or in-memory DB
  void setDatabaseForTesting(Database db) {
    _db = db;
  }

  Future<Database> _initDatabase() async {
    // 1. Initialize FFI for Desktop / Unit Test runners
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(appDir.path, 'nutrition.db');
    } catch (_) {
      // Fallback for tests running outside flutter app runner
      final testDir = Directory.current.path;
      dbPath = p.join(testDir, 'assets', 'database', 'nutrition.db');
    }

    // 2. Ensure database file exists and syncs when bundled asset is updated
    final dbFile = File(dbPath);
    if (!await dbFile.exists() || await dbFile.length() == 0) {
      await _copyAssetToDisk(dbFile);
    } else {
      try {
        final byteData = await rootBundle.load('assets/database/nutrition.db');
        if (byteData.lengthInBytes > await dbFile.length()) {
          await _copyAssetToDisk(dbFile);
        }
      } catch (_) {}
    }

    // Open read-write so user can create & save custom recipes
    return await openDatabase(
      dbPath,
      readOnly: false,
    );
  }

  Future<void> _copyAssetToDisk(File targetFile) async {
    try {
      await targetFile.parent.create(recursive: true);
      // Try rootBundle first
      final byteData = await rootBundle.load('assets/database/nutrition.db');
      final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      await targetFile.writeAsBytes(bytes, flush: true);
    } catch (e) {
      // In standalone tests, copy directly from filesystem asset directory
      final localAsset = File(p.join(Directory.current.path, 'assets', 'database', 'nutrition.db'));
      if (await localAsset.exists()) {
        await localAsset.copy(targetFile.path);
      } else {
        debugPrint('Could not copy nutrition asset: $e');
      }
    }
  }

  /// Resolves a food query token using Tier 1 Exact Alias lookup and Tier 2 FTS5 Ranking
  Future<EntitySearchResult?> resolveFoodToken(String token) async {
    final db = await database;
    final normalized = token.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    // --- Tier 1: Exact Alias Lookup (Custom recipes prioritized via is_custom DESC) ---
    final aliasMatches = await db.rawQuery(
      '''
      SELECT fa.entity_type, fa.entity_id, fa.alias, fa.is_custom
      FROM food_aliases fa
      WHERE fa.alias = ?
      ORDER BY fa.is_custom DESC, fa.id DESC
      LIMIT 1
      ''',
      [normalized],
    );

    if (aliasMatches.isNotEmpty) {
      final row = aliasMatches.first;
      final typeStr = row['entity_type'] as String;
      final entType = typeStr == 'RECIPE' ? EntityType.recipe : EntityType.ingredient;
      final entId = row['entity_id'] as int;

      final entity = await getEntity(entType, entId);
      if (entity != null) {
        final alternates = await getAlternatesFor(entity.name, entType, entId, queryToken: normalized);
        return EntitySearchResult(
          entity: entity,
          confidenceScore: 1.0,
          alternates: alternates,
        );
      }
    }

    // --- Tier 2: FTS5 Full-Text Search ---
    final cleanWords = normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (cleanWords.isEmpty) return null;

    final ftsPattern = cleanWords.map((w) => '$w*').join(' ');

    List<Map<String, Object?>> ftsResults;
    try {
      ftsResults = await db.rawQuery(
        '''
        SELECT entity_type, entity_id, name, is_custom, bm25(entity_fts) as score
        FROM entity_fts
        WHERE entity_fts MATCH ?
        ORDER BY is_custom DESC, score ASC
        LIMIT 4
        ''',
        [ftsPattern],
      );
    } catch (_) {
      // Fallback if FTS match query fails syntax
      ftsResults = await db.rawQuery(
        '''
        SELECT 'RECIPE' as entity_type, id as entity_id, name, is_custom, 0.5 as score
        FROM recipes
        WHERE LOWER(name) LIKE ?
        UNION ALL
        SELECT 'INGREDIENT' as entity_type, id as entity_id, name, 0 as is_custom, 0.5 as score
        FROM ingredients
        WHERE LOWER(name) LIKE ?
        ORDER BY is_custom DESC
        LIMIT 4
        ''',
        ['%$normalized%', '%$normalized%'],
      );
    }

    if (ftsResults.isEmpty) {
      return null;
    }

    final topRow = ftsResults.first;
    final topTypeStr = topRow['entity_type'] as String;
    final topType = topTypeStr == 'RECIPE' ? EntityType.recipe : EntityType.ingredient;
    final topId = topRow['entity_id'] as int;

    final topEntity = await getEntity(topType, topId);
    if (topEntity == null) return null;

    final rawScore = (topRow['score'] as num?)?.toDouble() ?? 1.0;
    // Normalize BM25 score to confidence (0.40 - 0.95)
    final confidence = (1.0 - (rawScore.abs() * 0.1)).clamp(0.40, 0.95);

    final alternates = <AlternateEntity>[];
    for (var i = 1; i < ftsResults.length; i++) {
      final altRow = ftsResults[i];
      final altTypeStr = altRow['entity_type'] as String;
      final altType = altTypeStr == 'RECIPE' ? EntityType.recipe : EntityType.ingredient;
      final altId = altRow['entity_id'] as int;
      final altName = altRow['name'] as String;
      final altIsCustom = ((altRow['is_custom'] as int?) ?? 0) == 1;
      final altScore = (altRow['score'] as num?)?.toDouble() ?? 1.5;
      final altConfidence = (1.0 - (altScore.abs() * 0.1)).clamp(0.35, 0.85);

      alternates.add(AlternateEntity(
        entityId: altId,
        name: altName,
        entityType: altType,
        confidenceScore: double.parse(altConfidence.toStringAsFixed(2)),
        isCustom: altIsCustom,
      ));
    }

    return EntitySearchResult(
      entity: topEntity,
      confidenceScore: double.parse(confidence.toStringAsFixed(2)),
      alternates: alternates,
    );
  }

  /// Fetches alternate options for a given food name
  Future<List<AlternateEntity>> getAlternatesFor(
    String foodName,
    EntityType currentType,
    int currentId, {
    String? queryToken,
  }) async {
    final db = await database;
    final combined = '$foodName ${queryToken ?? ''}'.toLowerCase();
    final cleanWords = combined.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet().toList();
    if (cleanWords.isEmpty) return [];

    final ftsPattern = cleanWords.map((w) => '$w*').join(' OR ');

    try {
      final rows = await db.rawQuery(
        '''
        SELECT entity_type, entity_id, name, is_custom, bm25(entity_fts) as score
        FROM entity_fts
        WHERE entity_fts MATCH ? AND NOT (entity_type = ? AND entity_id = ?)
        ORDER BY is_custom DESC, score ASC
        LIMIT 4
        ''',
        [ftsPattern, currentType.name.toUpperCase(), currentId],
      );

      return rows.map((r) {
        final tStr = r['entity_type'] as String;
        final type = tStr == 'RECIPE' ? EntityType.recipe : EntityType.ingredient;
        final score = (r['score'] as num?)?.toDouble() ?? 1.0;
        final conf = (1.0 - (score.abs() * 0.1)).clamp(0.40, 0.90);
        final isCustom = ((r['is_custom'] as int?) ?? 0) == 1;
        return AlternateEntity(
          entityId: r['entity_id'] as int,
          name: r['name'] as String,
          entityType: type,
          confidenceScore: double.parse(conf.toStringAsFixed(2)),
          isCustom: isCustom,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches complete FoodEntity by type and ID
  Future<FoodEntity?> getEntity(EntityType type, int id) async {
    final db = await database;

    if (type == EntityType.ingredient) {
      final rows = await db.query(
        'ingredients',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final r = rows.first;
      return FoodEntity(
        id: id,
        name: r['name'] as String,
        entityType: EntityType.ingredient,
        standardServingUnit: '100g',
        standardServingGrams: 100.0,
        macrosPer100g: MacroNutrients(
          calories: (r['calories_per_100g'] as num).toDouble(),
          proteinG: (r['protein_per_100g'] as num).toDouble(),
          carbsG: (r['carbs_per_100g'] as num).toDouble(),
          fatG: (r['fat_per_100g'] as num).toDouble(),
        ),
        isCanonicalDefault: (r['is_canonical_default'] as int) == 1,
        popularityRank: (r['popularity_rank'] as int?) ?? 100,
        isCustom: false,
      );
    } else {
      // Recipe: Aggregate nutrition from composed ingredients
      final recRows = await db.query(
        'recipes',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (recRows.isEmpty) return null;
      final r = recRows.first;
      final servingUnit = r['standard_serving_unit'] as String;
      final servingGrams = (r['standard_serving_grams'] as num).toDouble();
      final isCustom = ((r['is_custom'] as int?) ?? 0) == 1;

      final ingRows = await db.rawQuery(
        '''
        SELECT 
          ri.ingredient_id,
          ri.grams_used,
          i.name,
          i.calories_per_100g,
          i.protein_per_100g,
          i.carbs_per_100g,
          i.fat_per_100g
        FROM recipe_ingredients ri
        JOIN ingredients i ON ri.ingredient_id = i.id
        WHERE ri.recipe_id = ?
        ''',
        [id],
      );

      final ingredientItems = <RecipeIngredientItem>[];
      double totalKcal = 0;
      double totalProt = 0;
      double totalCarb = 0;
      double totalFat = 0;

      for (final ing in ingRows) {
        final used = (ing['grams_used'] as num).toDouble();
        final factor = used / 100.0;
        final c100 = (ing['calories_per_100g'] as num).toDouble();
        final p100 = (ing['protein_per_100g'] as num).toDouble();
        final cb100 = (ing['carbs_per_100g'] as num).toDouble();
        final f100 = (ing['fat_per_100g'] as num).toDouble();

        totalKcal += c100 * factor;
        totalProt += p100 * factor;
        totalCarb += cb100 * factor;
        totalFat += f100 * factor;

        ingredientItems.add(RecipeIngredientItem(
          ingredientId: ing['ingredient_id'] as int,
          name: ing['name'] as String,
          gramsUsed: used,
          macrosPer100g: MacroNutrients(
            calories: c100,
            proteinG: p100,
            carbsG: cb100,
            fatG: f100,
          ),
        ));
      }

      // Normalize macros per 100g of cooked recipe
      final scaleTo100g = servingGrams > 0 ? (100.0 / servingGrams) : 1.0;

      return FoodEntity(
        id: id,
        name: r['name'] as String,
        entityType: EntityType.recipe,
        standardServingUnit: servingUnit,
        standardServingGrams: servingGrams,
        macrosPer100g: MacroNutrients(
          calories: double.parse((totalKcal * scaleTo100g).toStringAsFixed(2)),
          proteinG: double.parse((totalProt * scaleTo100g).toStringAsFixed(2)),
          carbsG: double.parse((totalCarb * scaleTo100g).toStringAsFixed(2)),
          fatG: double.parse((totalFat * scaleTo100g).toStringAsFixed(2)),
        ),
        isCanonicalDefault: (r['is_canonical_default'] as int) == 1,
        popularityRank: (r['popularity_rank'] as int?) ?? 100,
        isCustom: isCustom,
        ingredients: ingredientItems,
      );
    }
  }

  /// Resolves the weight in grams of a given unit for an entity
  Future<double> resolveUnitGrams({
    required String? unit,
    required EntityType entityType,
    required int entityId,
    required double entityStandardServingGrams,
  }) async {
    if (unit == null || unit.isEmpty) {
      return entityStandardServingGrams;
    }

    final normalizedUnit = unit.toLowerCase().trim();
    if (normalizedUnit == 'g' || normalizedUnit == 'gram' || normalizedUnit == 'grams' || normalizedUnit == 'ml') {
      return 1.0;
    }
    if (normalizedUnit == 'kg' || normalizedUnit == 'l' || normalizedUnit == 'liter' || normalizedUnit == 'liters') {
      return 1000.0;
    }
    if (normalizedUnit == 'piece' || normalizedUnit == 'serving' || normalizedUnit == 'portion') {
      return entityStandardServingGrams;
    }

    final db = await database;

    // 1. Check for specific override
    final overrideRows = await db.query(
      'unit_conversions',
      where: 'unit_name = ? AND entity_type = ? AND entity_id = ?',
      whereArgs: [normalizedUnit, entityType.name.toUpperCase(), entityId],
      limit: 1,
    );
    if (overrideRows.isNotEmpty && overrideRows.first['override_grams'] != null) {
      return (overrideRows.first['override_grams'] as num).toDouble();
    }

    // 2. Check for default unit conversion
    final defaultRows = await db.query(
      'unit_conversions',
      where: 'unit_name = ? AND entity_type IS NULL',
      whereArgs: [normalizedUnit],
      limit: 1,
    );
    if (defaultRows.isNotEmpty) {
      return (defaultRows.first['default_grams'] as num).toDouble();
    }

    // Fallback to entity's standard serving grams
    return entityStandardServingGrams;
  }

  /// Returns all foundational ingredients for ingredient picker / search
  Future<List<FoodEntity>> getAllIngredients() async {
    final db = await database;
    final rows = await db.query('ingredients', orderBy: 'name ASC');
    return rows.map((r) {
      return FoodEntity(
        id: r['id'] as int,
        name: r['name'] as String,
        entityType: EntityType.ingredient,
        standardServingUnit: '100g',
        standardServingGrams: 100.0,
        macrosPer100g: MacroNutrients(
          calories: (r['calories_per_100g'] as num).toDouble(),
          proteinG: (r['protein_per_100g'] as num).toDouble(),
          carbsG: (r['carbs_per_100g'] as num).toDouble(),
          fatG: (r['fat_per_100g'] as num).toDouble(),
        ),
      );
    }).toList();
  }

  /// Persists a customized recipe into SQLite with is_custom = 1 and popularity_rank = 1
  Future<FoodEntity> saveCustomRecipe({
    required String baseRecipeName,
    required String customRecipeName,
    required String servingUnit,
    required List<RecipeIngredientItem> ingredients,
    List<String>? extraAliases,
  }) async {
    final db = await database;

    final totalServingGrams = ingredients.fold<double>(0.0, (sum, i) => sum + i.gramsUsed);

    // 1. Insert into recipes
    final recipeId = await db.insert(
      'recipes',
      {
        'name': customRecipeName,
        'standard_serving_unit': servingUnit,
        'standard_serving_grams': totalServingGrams > 0 ? totalServingGrams : 100.0,
        'source': 'USER_CUSTOM',
        'is_canonical_default': 1,
        'popularity_rank': 1,
        'is_custom': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 2. Insert ingredients
    await db.delete('recipe_ingredients', where: 'recipe_id = ?', whereArgs: [recipeId]);
    for (final ing in ingredients) {
      await db.insert('recipe_ingredients', {
        'recipe_id': recipeId,
        'ingredient_id': ing.ingredientId,
        'grams_used': ing.gramsUsed,
      });
    }

    // 3. Add aliases with is_custom = 1 (so exact alias resolution picks custom first)
    final cleanAliases = <String>{
      baseRecipeName.toLowerCase().replaceAll(RegExp(r'\([^)]*\)'), '').trim(),
      customRecipeName.toLowerCase().replaceAll(RegExp(r'\([^)]*\)'), '').trim(),
      if (extraAliases != null) ...extraAliases.map((a) => a.toLowerCase().trim()),
    };

    for (final alias in cleanAliases) {
      if (alias.isEmpty) continue;
      await db.insert(
        'food_aliases',
        {
          'alias': alias,
          'entity_type': 'RECIPE',
          'entity_id': recipeId,
          'is_custom': 1,
        },
      );
    }

    // 4. Insert into entity_fts
    final aliasStr = cleanAliases.join(' ');
    await db.rawInsert(
      '''
      INSERT INTO entity_fts (name, aliases, entity_type, entity_id, is_custom)
      VALUES (?, ?, 'RECIPE', ?, 1)
      ''',
      [customRecipeName, aliasStr, recipeId],
    );

    final savedEntity = await getEntity(EntityType.recipe, recipeId);
    return savedEntity!;
  }
}
