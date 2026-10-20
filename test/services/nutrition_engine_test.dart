import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soma_app/models/nutrition_models.dart';
import 'package:soma_app/services/nutrition/meal_text_parser.dart';
import 'package:soma_app/services/nutrition/nutrition_database_service.dart';
import 'package:soma_app/services/nutrition/macro_computation_engine.dart';
import 'package:soma_app/services/nutrition/meal_verdict_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MealTextParser Tests', () {
    test('parses integers and simple meals', () {
      final tokens = MealTextParser.parse('2 bowls of poha');
      expect(tokens.length, 1);
      expect(tokens.first.quantity, 2.0);
      expect(tokens.first.unit, 'bowl');
      expect(tokens.first.foodQuery, 'poha');
    });

    test('strips conversational boilerplate', () {
      final tokens = MealTextParser.parse('I had 2 bowls of poha for breakfast');
      expect(tokens.length, 1);
      expect(tokens.first.quantity, 2.0);
      expect(tokens.first.unit, 'bowl');
      expect(tokens.first.foodQuery, 'poha');
    });

    test('splits compound meals with conjunctions', () {
      final tokens = MealTextParser.parse('2 bowls of poha and 1 glass of milk');
      expect(tokens.length, 2);
      expect(tokens[0].quantity, 2.0);
      expect(tokens[0].unit, 'bowl');
      expect(tokens[0].foodQuery, 'poha');

      expect(tokens[1].quantity, 1.0);
      expect(tokens[1].unit, 'glass');
      expect(tokens[1].foodQuery, 'milk');
    });

    test('parses vulgar fractions and textual fractions', () {
      final halfBowl = MealTextParser.parse('1/2 bowl dal');
      expect(halfBowl.first.quantity, 0.5);
      expect(halfBowl.first.unit, 'bowl');
      expect(halfBowl.first.foodQuery, 'dal');

      final vulgarOneHalf = MealTextParser.parse('1½ cups of curd');
      expect(vulgarOneHalf.first.quantity, 1.5);
      expect(vulgarOneHalf.first.unit, 'cup');
      expect(vulgarOneHalf.first.foodQuery, 'curd');

      final compoundHalf = MealTextParser.parse('two and a half rotis');
      expect(compoundHalf.first.quantity, 2.5);
      expect(compoundHalf.first.unit, 'roti');
      expect(compoundHalf.first.foodQuery, 'rotis');
    });

    test('parses word numerals', () {
      final tokens = MealTextParser.parse('three boiled eggs and a banana');
      expect(tokens.length, 2);
      expect(tokens[0].quantity, 3.0);
      expect(tokens[0].foodQuery, 'boiled eggs');

      expect(tokens[1].quantity, 1.0);
      expect(tokens[1].foodQuery, 'banana');
    });
  });

  group('NutritionDatabaseService & MacroComputationEngine Tests', () {
    late Directory tempDir;
    late Database testDb;
    late NutritionDatabaseService dbService;
    late MacroComputationEngine engine;

    setUpAll(() async {
      final dbPath = p.join(Directory.current.path, 'assets', 'database', 'nutrition.db');
      expect(File(dbPath).existsSync(), isTrue, reason: 'assets/database/nutrition.db must exist');

      tempDir = Directory.systemTemp.createTempSync('nutrition_test_');
      final tempDbPath = p.join(tempDir.path, 'nutrition.db');
      await File(dbPath).copy(tempDbPath);

      testDb = await databaseFactoryFfi.openDatabase(tempDbPath, options: OpenDatabaseOptions(readOnly: false));
      dbService = NutritionDatabaseService.instance;
      dbService.setDatabaseForTesting(testDb);
      engine = MacroComputationEngine(dbService: dbService);
    });

    tearDownAll(() async {
      await testDb.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('resolves exact aliases for Indian staples', () async {
      // Poha via regional alias avalakki
      final pohaMatch = await dbService.resolveFoodToken('avalakki');
      expect(pohaMatch, isNotNull);
      expect(pohaMatch!.entity.name, 'Poha (Cooked)');
      expect(pohaMatch.confidenceScore, 1.0);

      // Roti via alias phulka
      final rotiMatch = await dbService.resolveFoodToken('phulka');
      expect(rotiMatch, isNotNull);
      expect(rotiMatch!.entity.name, 'Roti / Chapati');
      expect(rotiMatch.confidenceScore, 1.0);

      // Curd via alias dahi
      final curdMatch = await dbService.resolveFoodToken('dahi');
      expect(curdMatch, isNotNull);
      expect(curdMatch!.entity.name, 'Curd / Dahi (Toned)');
      expect(curdMatch.confidenceScore, 1.0);
    });

    test('FTS5 matches composite dishes with high confidence', () async {
      final dalMatch = await dbService.resolveFoodToken('dal tadka');
      expect(dalMatch, isNotNull);
      expect(dalMatch!.entity.name.toLowerCase(), contains('dal tadka'));

      final bhurjiMatch = await dbService.resolveFoodToken('paneer bhurji');
      expect(bhurjiMatch, isNotNull);
      expect(bhurjiMatch!.entity.name, 'Paneer Bhurji');
    });

    test('calculates correct grams and macros for compound meal: 2 bowls poha + 1 glass milk', () async {
      final result = await engine.parseAndCompute('I had 2 bowls of poha and 1 glass of milk');

      expect(result.status, ParseStatus.success);
      expect(result.items.length, 2);

      // Item 1: Poha
      final poha = result.items[0];
      expect(poha.resolvedEntity?.name, 'Poha (Cooked)');
      expect(poha.quantity, 2.0);
      expect(poha.unit, 'bowl');
      expect(poha.calculatedGrams, 400.0); // 1 bowl = 200g
      expect(poha.macros.calories, greaterThan(450.0));
      expect(poha.macros.proteinG, greaterThan(8.0));
      expect(poha.macros.carbsG, greaterThan(80.0));

      // Item 2: Milk
      final milk = result.items[1];
      expect(milk.resolvedEntity?.name, 'Cow Milk (Toned 3% Fat)');
      expect(milk.quantity, 1.0);
      expect(milk.unit, 'glass');
      expect(milk.calculatedGrams, 250.0); // 1 glass = 250g
      expect(milk.macros.calories, closeTo(147.5, 5.0));

      // Total Macros
      expect(result.totalMacros.calories, closeTo(poha.macros.calories + milk.macros.calories, 0.5));
      expect(result.totalMacros.proteinG, closeTo(poha.macros.proteinG + milk.macros.proteinG, 0.5));
    });

    test('recalculates item deterministically when quantity is updated', () async {
      final result = await engine.parseAndCompute('2 rotis');
      expect(result.items.length, 1);
      final initialItem = result.items.first;

      // Update quantity to 4 rotis
      final updatedItem = await engine.recalculateItem(initialItem, newQuantity: 4.0);
      expect(updatedItem.quantity, 4.0);
      expect(updatedItem.calculatedGrams, initialItem.calculatedGrams * 2);
      expect(updatedItem.macros.calories, closeTo(initialItem.macros.calories * 2, 0.5));
      expect(updatedItem.macros.proteinG, closeTo(initialItem.macros.proteinG * 2, 0.5));
    });

    test('handles partial resolution when unknown tokens are present', () async {
      final result = await engine.parseAndCompute('2 rotis and 1 bowl of totallyunknownxyzfood');
      expect(result.status, ParseStatus.partial);
      expect(result.items.length, 1);
      expect(result.unresolvedTokens.length, 1);
      expect(result.items.first.resolvedEntity?.name, 'Roti / Chapati');
      expect(result.unresolvedTokens.first, contains('totallyunknownxyzfood'));
    });

    test('produces valid JSON contract complying with PRD specification', () async {
      final result = await engine.parseAndCompute('2 bowls of poha and 1 glass of milk');
      final json = result.toJson();

      expect(json['query'], '2 bowls of poha and 1 glass of milk');
      expect(json['status'], 'SUCCESS');
      expect(json['items'], isA<List>());
      expect(json['total_macros'], isA<Map>());
      expect(json['total_macros']['calories'], isNotNull);
      expect(json['total_macros']['protein_g'], isNotNull);
      expect(json['total_macros']['carbs_g'], isNotNull);
      expect(json['total_macros']['fat_g'], isNotNull);
    });

    test('loads sub-recipe ingredients for composite dishes (Poha)', () async {
      final result = await engine.parseAndCompute('1 bowl of poha');
      expect(result.items.isNotEmpty, isTrue);

      final poha = result.items.first;
      expect(poha.resolvedEntity, isNotNull);
      expect(poha.resolvedEntity!.entityType, EntityType.recipe);
      expect(poha.resolvedEntity!.ingredients.isNotEmpty, isTrue);

      // Verify specific staple ingredients in default Poha recipe
      final ingredientNames = poha.resolvedEntity!.ingredients.map((i) => i.name).toList();
      expect(ingredientNames, contains('Flattened Rice (Poha Raw)'));
      expect(ingredientNames, contains('Peanuts (Raw/Roasted)'));
      expect(ingredientNames, contains('Vegetable Cooking Oil'));
      expect(ingredientNames, contains('Onion (Raw)'));
    });

    test('recalculates macros dynamically when ingredients are customized (e.g., removing peanuts)', () async {
      final result = await engine.parseAndCompute('1 bowl of poha');
      final poha = result.items.first;
      final originalMacros = poha.macros;

      // Filter out peanuts (0g)
      final modifiedIngredients = poha.resolvedEntity!.ingredients
          .where((i) => !i.name.contains('Peanut'))
          .toList();

      final updatedItem = engine.recalculateWithIngredients(
        item: poha,
        updatedIngredients: modifiedIngredients,
      );

      // Removing peanuts should significantly reduce calories and fat while preserving recipe
      expect(updatedItem.macros.calories, lessThan(originalMacros.calories));
      expect(updatedItem.macros.fatG, lessThan(originalMacros.fatG));
      expect(updatedItem.customizedIngredients.length, modifiedIngredients.length);
    });

    test('fetches all foundational ingredients for ingredient picker', () async {
      final allIngredients = await dbService.getAllIngredients();
      expect(allIngredients.isNotEmpty, isTrue);
      final names = allIngredients.map((i) => i.name).toList();
      expect(names, contains('Peanuts (Raw/Roasted)'));
      expect(names, contains('Olive Oil'));
      expect(names, contains('Chicken Breast (Skinless Raw)'));
    });

    test('saves custom recipe and prioritizes it on subsequent queries', () async {
      final baseResult = await engine.parseAndCompute('1 bowl of poha');
      final originalPoha = baseResult.items.first;

      // Create customized ingredient list: 80g flattened rice, 0g peanuts, 5g oil
      final customizedList = [
        RecipeIngredientItem(
          ingredientId: originalPoha.resolvedEntity!.ingredients.firstWhere((i) => i.name.contains('Flattened Rice')).ingredientId,
          name: 'Flattened Rice (Poha Raw)',
          gramsUsed: 80.0,
          macrosPer100g: const MacroNutrients(calories: 350.0, proteinG: 6.8, carbsG: 77.0, fatG: 1.2),
        ),
        RecipeIngredientItem(
          ingredientId: originalPoha.resolvedEntity!.ingredients.firstWhere((i) => i.name.contains('Oil')).ingredientId,
          name: 'Vegetable Cooking Oil',
          gramsUsed: 5.0,
          macrosPer100g: const MacroNutrients(calories: 900.0, proteinG: 0.0, carbsG: 0.0, fatG: 100.0),
        ),
      ];

      // Save custom recipe
      final customEntity = await dbService.saveCustomRecipe(
        baseRecipeName: 'Poha (Cooked)',
        customRecipeName: 'My Custom Poha',
        servingUnit: 'bowl',
        ingredients: customizedList,
      );

      expect(customEntity.isCustom, isTrue);
      expect(customEntity.name, 'My Custom Poha');

      // Subsequent query: "poha" should prioritize the custom recipe first
      final subsequentResult = await engine.parseAndCompute('1 bowl of poha');
      expect(subsequentResult.items.isNotEmpty, isTrue);

      final topResolved = subsequentResult.items.first;
      expect(topResolved.resolvedEntity?.name, 'My Custom Poha');
      expect(topResolved.isCustom, isTrue);

      // Standard Poha should be preserved in alternates list
      final alternateNames = topResolved.alternates.map((a) => a.name).toList();
      expect(alternateNames.any((name) => name.contains('Poha')), isTrue);
    });

    test('resolves and computes Indian street food and snacks: samosa, kachori, pav bhaji', () async {
      final result = await engine.parseAndCompute('2 samosas and 1 kachori');
      expect(result.status, ParseStatus.success);
      expect(result.items.length, 2);

      // Samosa
      final samosa = result.items[0];
      expect(samosa.resolvedEntity?.name, 'Samosa (Aloo Samosa)');
      expect(samosa.quantity, 2.0);
      expect(samosa.calculatedGrams, 170.0); // 2 * 85g
      expect(samosa.macros.calories, greaterThan(350.0));
      expect(samosa.resolvedEntity!.ingredients.any((i) => i.name.contains('Maida')), isTrue);
      expect(samosa.resolvedEntity!.ingredients.any((i) => i.name.contains('Potato')), isTrue);

      // Kachori
      final kachori = result.items[1];
      expect(kachori.resolvedEntity?.name, 'Kachori (Khasta Dal Kachori)');
      expect(kachori.quantity, 1.0);
      expect(kachori.calculatedGrams, 75.0);
      expect(kachori.macros.calories, greaterThan(180.0));

      // 1 plate of kachori should scale to 2 pieces (150g), not a 300g main-course meal plate!
      final plateKachori = await engine.parseAndCompute('1 plate kachori');
      expect(plateKachori.items.first.calculatedGrams, 150.0);
      expect(plateKachori.items.first.macros.calories, closeTo(654.0, 20.0));
    });

    test('resolves popular Indian street foods and sweets: pav bhaji, chole bhature, biryani, gulab jamun', () async {
      final pb = await engine.parseAndCompute('1 plate pav bhaji');
      expect(pb.items.first.resolvedEntity?.name, 'Pav Bhaji');
      expect(pb.items.first.calculatedGrams, 300.0);

      final cb = await engine.parseAndCompute('1 plate chole bhature');
      expect(cb.items.first.resolvedEntity?.name, 'Chole Bhature');
      expect(cb.items.first.calculatedGrams, 350.0);

      final biryani = await engine.parseAndCompute('1 plate chicken biryani');
      expect(biryani.items.first.resolvedEntity?.name, 'Chicken Biryani');
      expect(biryani.items.first.calculatedGrams, 300.0);
      expect(biryani.items.first.macros.proteinG, greaterThan(25.0));

      final sweets = await engine.parseAndCompute('2 gulab jamun and 1 jalebi');
      expect(sweets.items.length, 2);
      expect(sweets.items[0].resolvedEntity?.name, 'Gulab Jamun');
      expect(sweets.items[1].resolvedEntity?.name, 'Jalebi');
    });

    test('resolves and computes beverages: black coffee, tea/chai, cold coffee, diet coke, coconut water', () async {
      // Black Coffee
      final coffee = await engine.parseAndCompute('1 cup of black coffee');
      expect(coffee.status, ParseStatus.success);
      expect(coffee.items.length, 1);
      expect(coffee.items.first.resolvedEntity?.name, 'Black Coffee (Espresso / Americano)');
      expect(coffee.items.first.macros.calories, lessThan(10.0));

      // Tea / Chai
      final chai = await engine.parseAndCompute('1 cup of chai');
      expect(chai.status, ParseStatus.success);
      expect(chai.items.first.resolvedEntity?.name, contains('Milk Tea'));
      expect(chai.items.first.macros.calories, greaterThan(40.0));

      // Diet Coke (0 cal)
      final dietCoke = await engine.parseAndCompute('1 can of diet coke');
      expect(dietCoke.status, ParseStatus.success);
      expect(dietCoke.items.first.resolvedEntity?.name, 'Diet Coke / Coke Zero (Can)');
      expect(dietCoke.items.first.calculatedGrams, 330.0);
      expect(dietCoke.items.first.macros.calories, 0.0);

      // Cold Coffee
      final coldCoffee = await engine.parseAndCompute('1 glass of cold coffee');
      expect(coldCoffee.items.first.resolvedEntity?.name, 'Cold Coffee (Iced Blended)');
      expect(coldCoffee.items.first.calculatedGrams, 300.0);

      // Coconut Water
      final coco = await engine.parseAndCompute('1 glass of coconut water');
      expect(coco.items.first.resolvedEntity?.name, 'Tender Coconut Water (Fresh)');
      expect(coco.items.first.calculatedGrams, 250.0);
    });

    test('resolves and computes sandwiches: dark chocolate sandwich, veg grilled, cheese, club sandwich', () async {
      // Dark Chocolate Sandwich
      final chocoSandwich = await engine.parseAndCompute('1 dark chocolate sandwich');
      expect(chocoSandwich.status, ParseStatus.success);
      expect(chocoSandwich.items.length, 1);
      final item = chocoSandwich.items.first;
      expect(item.resolvedEntity?.name, 'Dark Chocolate Sandwich');
      expect(item.calculatedGrams, 140.0);
      expect(item.macros.calories, greaterThan(300.0));
      expect(item.resolvedEntity!.ingredients.any((i) => i.name.contains('Dark Chocolate')), isTrue);

      // Cheese grilled sandwich
      final cheeseSandwich = await engine.parseAndCompute('1 cheese sandwich');
      expect(cheeseSandwich.items.first.resolvedEntity?.name, 'Cheese Grilled Sandwich');

      // Veg sandwich
      final vegSandwich = await engine.parseAndCompute('1 veg sandwich');
      expect(vegSandwich.items.first.resolvedEntity?.name, 'Veg Grilled Sandwich (Bombay Style)');
    });

    test('resolves and computes fast food (US/International & Indian): burger, fries, pizza, momos, shawarma', () async {
      // Burger & Fries
      final meal = await engine.parseAndCompute('1 chicken burger and french fries');
      expect(meal.status, ParseStatus.success);
      expect(meal.items.length, 2);
      expect(meal.items[0].resolvedEntity?.name, 'Chicken Burger (Crispy)');
      expect(meal.items[1].resolvedEntity?.name, 'French Fries (Medium)');
      expect(meal.totalMacros.calories, greaterThan(600.0));

      // Pizza
      final pizza = await engine.parseAndCompute('2 slices of margherita pizza');
      expect(pizza.items.first.resolvedEntity?.name, 'Margherita Pizza (1 Slice)');
      expect(pizza.items.first.quantity, 2.0);
      expect(pizza.items.first.calculatedGrams, 200.0);

      // Momos
      final momos = await engine.parseAndCompute('1 plate momos');
      expect(momos.items.first.resolvedEntity?.name, 'Steamed Veg Momos (6 Pieces)');
      expect(momos.items.first.calculatedGrams, 150.0);

      // Shawarma
      final shawarma = await engine.parseAndCompute('1 chicken shawarma');
      expect(shawarma.items.first.resolvedEntity?.name, 'Chicken Shawarma Roll');
      expect(shawarma.items.first.calculatedGrams, 200.0);

      // Cookie and Donut
      final sweets = await engine.parseAndCompute('1 chocolate chip cookie and 1 glazed donut');
      expect(sweets.items.length, 2);
      expect(sweets.items[0].resolvedEntity?.name, 'Chocolate Chip Cookie');
      expect(sweets.items[1].resolvedEntity?.name, 'Glazed Doughnut / Donut');
    });

    test('resolves cooked dals and cooked vegetables rather than raw staples (3 rotis and urad dal)', () async {
      final meal = await engine.parseAndCompute('3 rotis and urad dal');
      expect(meal.status, ParseStatus.success);
      expect(meal.items.length, 2);

      // 1. Rotis: 3 pieces -> ~105g edible, ~300 kcal
      final rotis = meal.items[0];
      expect(rotis.resolvedEntity?.name, 'Roti / Chapati');
      expect(rotis.quantity, 3.0);
      expect(rotis.calculatedGrams, 105.0);

      // 2. Urad Dal: MUST resolve to cooked recipe 'Urad Dal (Cooked / Tadka)', NOT raw dry pulse!
      final dal = meal.items[1];
      expect(dal.resolvedEntity?.name, 'Urad Dal (Cooked / Tadka)');
      expect(dal.calculatedGrams, 150.0);
      // Cooked dal is diluted with water: ~170 kcal per katori, not 492 kcal raw!
      expect(dal.macros.calories, lessThan(200.0));
      expect(dal.macros.proteinG, greaterThan(7.0));

      // Total meal should be around 450-490 kcal
      expect(meal.totalMacros.calories, lessThan(520.0));

      // 3. Verdict on 3 rotis & urad dal: BALANCED, not HIGH CAL!
      final verdict = MealVerdict.evaluate(
        calories: meal.totalMacros.calories,
        protein: meal.totalMacros.proteinG,
        carbs: meal.totalMacros.carbsG,
        fats: meal.totalMacros.fatG,
      );
      expect(verdict.tag, equals(MealVerdictTag.balanced));
      expect(verdict.label, equals('BALANCED'));

      // 4. Test cooked vegetables (mix veg, bhindi, aloo matar)
      final mixVeg = await engine.parseAndCompute('1 bowl mix veg and 2 rotis');
      expect(mixVeg.items[0].resolvedEntity?.name, 'Mixed Vegetable Sabzi (Cooked)');
      expect(mixVeg.items[1].resolvedEntity?.name, 'Roti / Chapati');

      final bhindi = await engine.parseAndCompute('1 katori bhindi');
      expect(bhindi.items.first.resolvedEntity?.name, 'Bhindi Masala (Okra Fry)');

      final alooMatar = await engine.parseAndCompute('1 bowl aloo matar');
      expect(alooMatar.items.first.resolvedEntity?.name, 'Aloo Matar (Curry)');
    });

    test('evaluates MealVerdict correctly for whole fruits (banana, apple) as LIGHT & CLEAN rather than HIGH CAL', () async {
      // 1 Banana
      final bananaResult = await engine.parseAndCompute('1 banana');
      expect(bananaResult.status, ParseStatus.success);
      expect(bananaResult.items.first.resolvedEntity?.name, 'Banana (Ripe)');

      final bananaVerdict = MealVerdict.evaluate(
        calories: bananaResult.totalMacros.calories,
        protein: bananaResult.totalMacros.proteinG,
        carbs: bananaResult.totalMacros.carbsG,
        fats: bananaResult.totalMacros.fatG,
      );
      // Must NOT be HIGH CAL!
      expect(bananaVerdict.tag, isNot(equals(MealVerdictTag.highCal)));
      expect(bananaVerdict.tag, equals(MealVerdictTag.lightClean));
      expect(bananaVerdict.label, equals('LIGHT & CLEAN'));

      // 1 Apple
      final appleResult = await engine.parseAndCompute('1 apple');
      final appleVerdict = MealVerdict.evaluate(
        calories: appleResult.totalMacros.calories,
        protein: appleResult.totalMacros.proteinG,
        carbs: appleResult.totalMacros.carbsG,
        fats: appleResult.totalMacros.fatG,
      );
      expect(appleVerdict.tag, equals(MealVerdictTag.lightClean));
      expect(appleVerdict.label, equals('LIGHT & CLEAN'));
    });

    test('resolves raw dal explicitly and provides Cooked <-> Raw switch alternates seamlessly', () async {
      // 1. Explicit raw query
      final rawUrad = await engine.parseAndCompute('100g raw urad dal');
      expect(rawUrad.status, ParseStatus.success);
      expect(rawUrad.items.first.resolvedEntity?.name, 'Urad Dal (Black Gram Split)');
      expect(rawUrad.items.first.resolvedEntity?.entityType, EntityType.ingredient);
      // Raw macros: ~328 kcal per 100g
      expect(rawUrad.items.first.macros.calories, closeTo(328.0, 5.0));
      // Alternates for raw should offer the Cooked recipe
      expect(rawUrad.items.first.alternates.any((a) => a.name.contains('Urad Dal (Cooked')), isTrue);

      // 2. Cooked query alternates should offer the Raw ingredient
      final cookedUrad = await engine.parseAndCompute('1 katori urad dal');
      expect(cookedUrad.status, ParseStatus.success);
      expect(cookedUrad.items.first.resolvedEntity?.name, 'Urad Dal (Cooked / Tadka)');
      expect(cookedUrad.items.first.resolvedEntity?.entityType, EntityType.recipe);
      // Cooked macros: ~170 kcal per 150g katori
      expect(cookedUrad.items.first.macros.calories, closeTo(170.0, 10.0));
      // Alternates for cooked should offer the Raw ingredient counterpart
      expect(cookedUrad.items.first.alternates.any((a) => a.name.contains('Raw') || a.name.contains('Black Gram Split')), isTrue);
    });
  });
}
