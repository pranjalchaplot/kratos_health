import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/nutrition_models.dart';
import '../providers/soma_provider.dart';
import '../theme/soma_theme.dart';

class RecipeCustomizerSheet extends StatefulWidget {
  final ParsedMealItem item;
  final void Function(ParsedMealItem updatedItem) onMealItemUpdated;

  const RecipeCustomizerSheet({
    super.key,
    required this.item,
    required this.onMealItemUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required ParsedMealItem item,
    required void Function(ParsedMealItem updatedItem) onMealItemUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecipeCustomizerSheet(
        item: item,
        onMealItemUpdated: onMealItemUpdated,
      ),
    );
  }

  @override
  State<RecipeCustomizerSheet> createState() => _RecipeCustomizerSheetState();
}

class _RecipeCustomizerSheetState extends State<RecipeCustomizerSheet> {
  late List<RecipeIngredientItem> _ingredients;
  late TextEditingController _recipeNameController;
  bool _isSavingCustom = false;

  @override
  void initState() {
    super.initState();
    // Copy ingredients so user edits are local until applied or saved
    _ingredients = widget.item.customizedIngredients.map((i) => i.copyWith()).toList();
    if (_ingredients.isEmpty && widget.item.resolvedEntity?.ingredients.isNotEmpty == true) {
      _ingredients = widget.item.resolvedEntity!.ingredients.map((i) => i.copyWith()).toList();
    }

    final entityName = widget.item.resolvedEntity?.name ?? widget.item.rawInput;
    final defaultCustomName = widget.item.isCustom
        ? entityName
        : '$entityName (Custom)';
    _recipeNameController = TextEditingController(text: defaultCustomName);
  }

  @override
  void dispose() {
    _recipeNameController.dispose();
    super.dispose();
  }

  double _effectiveUnitGrams(double baseServingGrams) {
    final normalizedUnit = widget.item.unit.toLowerCase().trim();
    if (normalizedUnit == 'plate' && baseServingGrams < 100.0) {
      // In Indian dining, 1 plate of piece-based snacks/sweets is 2 pieces
      return baseServingGrams * 2.0;
    } else if (normalizedUnit == 'g' || normalizedUnit == 'gram') {
      return 1.0;
    } else if (normalizedUnit == 'kg') {
      return 1000.0;
    }
    return baseServingGrams;
  }

  MacroNutrients _computeCurrentMacros() {
    double totalGrams = 0;
    double totalKcal = 0;
    double totalProt = 0;
    double totalCarb = 0;
    double totalFat = 0;

    for (final ing in _ingredients) {
      totalGrams += ing.gramsUsed;
      final factor = ing.gramsUsed / 100.0;
      totalKcal += ing.macrosPer100g.calories * factor;
      totalProt += ing.macrosPer100g.proteinG * factor;
      totalCarb += ing.macrosPer100g.carbsG * factor;
      totalFat += ing.macrosPer100g.fatG * factor;
    }

    final servingGrams = totalGrams > 0 ? totalGrams : 100.0;
    final scaleTo100g = 100.0 / servingGrams;

    final macrosPer100g = MacroNutrients(
      calories: double.parse((totalKcal * scaleTo100g).toStringAsFixed(2)),
      proteinG: double.parse((totalProt * scaleTo100g).toStringAsFixed(2)),
      carbsG: double.parse((totalCarb * scaleTo100g).toStringAsFixed(2)),
      fatG: double.parse((totalFat * scaleTo100g).toStringAsFixed(2)),
    );

    final effectiveUnit = _effectiveUnitGrams(servingGrams);
    final totalServingGrams = widget.item.quantity * effectiveUnit;
    return macrosPer100g.scale(totalServingGrams / 100.0);
  }

  double _computeTotalServingGrams() {
    final baseGrams = _ingredients.fold<double>(0.0, (sum, i) => sum + i.gramsUsed);
    final effectiveUnit = _effectiveUnitGrams(baseGrams > 0 ? baseGrams : 100.0);
    return widget.item.quantity * effectiveUnit;
  }

  void _updateGrams(int index, double delta) {
    HapticFeedback.lightImpact();
    setState(() {
      final current = _ingredients[index];
      final newGrams = (current.gramsUsed + delta).clamp(1.0, 500.0);
      _ingredients[index] = current.copyWith(gramsUsed: newGrams);
    });
  }

  void _removeIngredient(int index) {
    if (_ingredients.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A recipe must have at least one ingredient.')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  Future<void> _openAddIngredientDialog() async {
    HapticFeedback.selectionClick();
    final provider = context.read<SomaProvider>();
    final allIngredients = await provider.getAllIngredients();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SomaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = allIngredients
                .where((ing) => ing.name.toLowerCase().contains(filter.toLowerCase()))
                .toList();

            return Container(
              height: 480,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ADD INGREDIENT TO RECIPE',
                    style: SomaFonts.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: SomaColors.primaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    style: SomaFonts.primary(color: SomaColors.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search ingredient (e.g. Peas, Ghee, Paneer)...',
                      hintStyle: SomaFonts.primary(color: SomaColors.onSecondaryContainer),
                      prefixIcon: const Icon(Icons.search, size: 18, color: SomaColors.primaryContainer),
                      filled: true,
                      fillColor: SomaColors.cardBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        filter = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final ing = filtered[idx];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          title: Text(
                            ing.name,
                            style: SomaFonts.display(fontSize: 13, fontWeight: FontWeight.bold, color: SomaColors.onSurface),
                          ),
                          subtitle: Text(
                            '${ing.macrosPer100g.calories.round()} kcal • ${ing.macrosPer100g.proteinG.round()}g P per 100g',
                            style: SomaFonts.mono(fontSize: 10, color: SomaColors.onSecondaryContainer),
                          ),
                          trailing: const Icon(Icons.add_circle_outline, color: SomaColors.primaryContainer, size: 20),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _ingredients.add(RecipeIngredientItem(
                                ingredientId: ing.id,
                                name: ing.name,
                                gramsUsed: 25.0,
                                macrosPer100g: ing.macrosPer100g,
                              ));
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _applyToCurrentMeal() {
    HapticFeedback.lightImpact();
    final provider = context.read<SomaProvider>();
    final updatedItem = provider.recalculateItemWithIngredients(
      item: widget.item,
      updatedIngredients: _ingredients,
      updatedCustomName: _recipeNameController.text.trim(),
    );
    widget.onMealItemUpdated(updatedItem);
    Navigator.pop(context);
  }

  Future<void> _saveAsCustomRecipe() async {
    final customName = _recipeNameController.text.trim();
    if (customName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for your custom recipe.')),
      );
      return;
    }

    setState(() => _isSavingCustom = true);
    HapticFeedback.heavyImpact();

    try {
      final provider = context.read<SomaProvider>();
      final baseName = widget.item.resolvedEntity?.name ?? widget.item.rawInput;

      final savedEntity = await provider.saveCustomRecipe(
        baseRecipeName: baseName,
        customRecipeName: customName,
        servingUnit: widget.item.unit,
        ingredients: _ingredients,
      );

      final updatedItem = provider.recalculateItemWithIngredients(
        item: widget.item,
        updatedIngredients: _ingredients,
        updatedCustomName: customName,
      );
      // Attach the saved custom entity
      updatedItem.resolvedEntity = savedEntity;

      widget.onMealItemUpdated(updatedItem);

      if (mounted) {
        setState(() => _isSavingCustom = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Custom recipe "$customName" saved! It will be prioritized when you search or speak next time.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving custom recipe: $e');
      if (mounted) {
        setState(() => _isSavingCustom = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save custom recipe: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentMacros = _computeCurrentMacros();
    final totalGrams = _computeTotalServingGrams();
    final isCustom = widget.item.isCustom;

    return Container(
      margin: EdgeInsets.only(top: 60, bottom: bottomInset),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: SomaColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: SomaColors.cardBorder, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SomaColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title & Custom Badge Row
          Row(
            children: [
              Expanded(
                child: Text(
                  'CUSTOMIZE RECIPE INGREDIENTS',
                  style: SomaFonts.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: SomaColors.onSecondaryContainer,
                  ),
                ),
              ),
              if (isCustom)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 10, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'CUSTOM',
                        style: SomaFonts.mono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Recipe Name Field
          TextField(
            controller: _recipeNameController,
            style: SomaFonts.display(fontSize: 15, fontWeight: FontWeight.bold, color: SomaColors.onSurface),
            decoration: InputDecoration(
              labelText: 'Recipe Name',
              labelStyle: SomaFonts.primary(color: SomaColors.onSecondaryContainer, fontSize: 11),
              filled: true,
              fillColor: SomaColors.cardBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: const Icon(Icons.edit, size: 16, color: SomaColors.primaryContainer),
            ),
          ),
          const SizedBox(height: 12),

          // Live Macro Preview Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SomaColors.primaryContainer.withValues(alpha: 0.15),
                  SomaColors.cardBackground,
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SomaColors.primaryContainer.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMacroCol('WEIGHT', '${totalGrams.round()}', 'g', SomaColors.onSurface),
                    _buildMacroCol('CALORIES', '${currentMacros.calories.round()}', 'kcal', SomaColors.primaryContainer),
                    _buildMacroCol('PROTEIN', '${currentMacros.proteinG.round()}', 'g', Colors.cyanAccent),
                    _buildMacroCol('CARBS', '${currentMacros.carbsG.round()}', 'g', Colors.amberAccent),
                    _buildMacroCol('FATS', '${currentMacros.fatG.round()}', 'g', Colors.orangeAccent),
                  ],
                ),
                if (widget.item.unit.isNotEmpty && widget.item.unit != 'piece' && widget.item.unit != 'g') ...[
                  const SizedBox(height: 6),
                  Text(
                    'Scaled for ${widget.item.quantity == 1.0 ? '1' : widget.item.quantity} ${widget.item.unit} (${totalGrams.round()}g edible)',
                    style: SomaFonts.mono(fontSize: 10, color: SomaColors.onSecondaryContainer),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Section Header: Ingredients List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'INGREDIENTS (${_ingredients.length})',
                style: SomaFonts.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: SomaColors.primaryContainer,
                ),
              ),
              TextButton.icon(
                onPressed: _openAddIngredientDialog,
                icon: const Icon(Icons.add, size: 14, color: SomaColors.primaryContainer),
                label: Text(
                  'Add Item',
                  style: SomaFonts.mono(fontSize: 10.5, fontWeight: FontWeight.bold, color: SomaColors.primaryContainer),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Scrollable Ingredients Steppers
          Expanded(
            child: ListView.builder(
              itemCount: _ingredients.length,
              itemBuilder: (context, idx) {
                final ing = _ingredients[idx];
                final ingMacros = ing.macros;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: SomaColors.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SomaColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ing.name,
                              style: SomaFonts.primary(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: SomaColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${ingMacros.calories.round()} kcal • ${ingMacros.proteinG.toStringAsFixed(1)}g P',
                              style: SomaFonts.mono(fontSize: 9.5, color: SomaColors.onSecondaryContainer),
                            ),
                          ],
                        ),
                      ),

                      // Stepper: - 5g, Grams, + 5g
                      Container(
                        decoration: BoxDecoration(
                          color: SomaColors.surfaceContainerHigh.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _updateGrams(idx, -5),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Icon(Icons.remove, size: 12, color: SomaColors.onSurface),
                              ),
                            ),
                            Text(
                              '${ing.gramsUsed.round()}g',
                              style: SomaFonts.mono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: SomaColors.primaryContainer,
                              ),
                            ),
                            InkWell(
                              onTap: () => _updateGrams(idx, 5),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Icon(Icons.add, size: 12, color: SomaColors.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Delete Ingredient Icon
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: SomaColors.onSecondaryContainer),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _removeIngredient(idx),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _applyToCurrentMeal,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: SomaColors.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'APPLY TO THIS MEAL',
                    style: SomaFonts.mono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: SomaColors.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _isSavingCustom ? null : _saveAsCustomRecipe,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSavingCustom
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          'SAVE AS CUSTOM',
                          style: SomaFonts.mono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCol(String title, String val, String unit, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: SomaFonts.mono(fontSize: 8, fontWeight: FontWeight.bold, color: SomaColors.onSecondaryContainer),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              val,
              style: SomaFonts.display(fontSize: 13, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(width: 1),
            Text(
              unit,
              style: SomaFonts.mono(fontSize: 8.5, color: SomaColors.onSecondaryContainer),
            ),
          ],
        ),
      ],
    );
  }
}
