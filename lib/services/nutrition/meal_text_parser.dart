class ExtractedToken {
  final String rawSegment;
  final double quantity;
  final String? unit;
  final String foodQuery;

  const ExtractedToken({
    required this.rawSegment,
    required this.quantity,
    this.unit,
    required this.foodQuery,
  });
}

class MealTextParser {
  static final RegExp _boilerplatePrefixRegex = RegExp(
    r'^(?:i\s+(?:had|ate|drank|consumed|took|eat)|for\s+(?:breakfast|lunch|dinner|snack|supper|brunch)|having|eating|drinking|just\s+ate)\s+',
    caseSensitive: false,
  );

  static final RegExp _boilerplateSuffixRegex = RegExp(
    r'\s+(?:for\s+(?:breakfast|lunch|dinner|snack|supper|brunch)|at\s+(?:breakfast|lunch|dinner|night|morning))$',
    caseSensitive: false,
  );

  static final RegExp _segmentDelimitersRegex = RegExp(
    r'(?:\s+and\s+(?!a\s+half\b|half\b)|\s*,\s*|\s*\+\s*|\s+with\s+|\s+along\s+with\s+|\s+plus\s+)',
    caseSensitive: false,
  );

  static const Map<String, double> _wordNumbers = {
    'half': 0.5,
    'quarter': 0.25,
    'a': 1.0,
    'an': 1.0,
    'one': 1.0,
    'two': 2.0,
    'three': 3.0,
    'four': 4.0,
    'five': 5.0,
    'six': 6.0,
    'seven': 7.0,
    'eight': 8.0,
    'nine': 9.0,
    'ten': 10.0,
  };

  static const Map<String, double> _vulgarFractions = {
    '½': 0.5,
    '¼': 0.25,
    '¾': 0.75,
    '⅓': 0.33,
    '⅔': 0.67,
  };

  static const Map<String, String> _unitSynonyms = {
    'katori': 'katori',
    'katoris': 'katori',
    'bowl': 'bowl',
    'bowls': 'bowl',
    'plate': 'plate',
    'plates': 'plate',
    'glass': 'glass',
    'glasses': 'glass',
    'cup': 'cup',
    'cups': 'cup',
    'piece': 'piece',
    'pieces': 'piece',
    'pc': 'piece',
    'pcs': 'piece',
    'slice': 'slice',
    'slices': 'slice',
    'roti': 'roti',
    'rotis': 'roti',
    'chapati': 'roti',
    'chapatis': 'roti',
    'phulka': 'roti',
    'phulkas': 'roti',
    'puri': 'piece',
    'puris': 'piece',
    'poori': 'piece',
    'pooris': 'piece',
    'samosa': 'piece',
    'samosas': 'piece',
    'samose': 'piece',
    'kachori': 'piece',
    'kachoris': 'piece',
    'bhatura': 'piece',
    'bhature': 'piece',
    'ladoo': 'piece',
    'laddu': 'piece',
    'scoop': 'scoop',
    'scoops': 'scoop',
    'tbsp': 'tbsp',
    'tablespoon': 'tbsp',
    'tablespoons': 'tbsp',
    'tsp': 'tsp',
    'teaspoon': 'tsp',
    'teaspoons': 'tsp',
    'g': 'g',
    'gram': 'g',
    'grams': 'g',
    'gm': 'g',
    'gms': 'g',
    'kg': 'kg',
    'kgs': 'kg',
    'kilogram': 'kg',
    'kilograms': 'kg',
    'ml': 'ml',
    'milliliter': 'ml',
    'milliliters': 'ml',
    'l': 'l',
    'liter': 'l',
    'liters': 'l',
    'litre': 'l',
    'litres': 'l',
  };

  /// Normalizes and parses free-form natural language input into segmented tokens
  static List<ExtractedToken> parse(String text) {
    if (text.trim().isEmpty) return [];

    // Step 1: Strip boilerplate prefix and suffix
    var cleaned = text.trim();
    cleaned = cleaned.replaceFirst(_boilerplatePrefixRegex, '');
    cleaned = cleaned.replaceFirst(_boilerplateSuffixRegex, '');

    // Step 2: Split by conjunction delimiters
    final rawSegments = cleaned
        .split(_segmentDelimitersRegex)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final results = <ExtractedToken>[];
    for (final seg in rawSegments) {
      final token = _parseSingleSegment(seg);
      if (token != null) {
        results.add(token);
      }
    }
    return results;
  }

  static ExtractedToken? _parseSingleSegment(String rawSegment) {
    var working = rawSegment.trim();
    if (working.isEmpty) return null;

    // Strip inline suffix boilerplate if inside a segment (e.g. "poha for breakfast")
    working = working.replaceFirst(_boilerplateSuffixRegex, '').trim();

    double? parsedQuantity;
    String? parsedUnit;

    // 1. Check for compound word numbers (e.g. "two and a half", "one and a half")
    final compoundMatch = RegExp(r'^(\w+)\s+and\s+a\s+half\b', caseSensitive: false).firstMatch(working);
    if (compoundMatch != null) {
      final baseWord = compoundMatch.group(1)?.toLowerCase();
      final baseVal = _wordNumbers[baseWord] ?? double.tryParse(baseWord ?? '');
      if (baseVal != null) {
        parsedQuantity = baseVal + 0.5;
        working = working.substring(compoundMatch.end).trim();
      }
    }

    // 2. Check for numeric + vulgar fraction (e.g. "1½" or "½")
    if (parsedQuantity == null) {
      for (final entry in _vulgarFractions.entries) {
        final vPattern = RegExp(r'^(\d+)?\s*' + entry.key + r'(?:\s+|$)');
        final m = vPattern.firstMatch(working);
        if (m != null) {
          final prefixNum = m.group(1) != null ? double.parse(m.group(1)!) : 0.0;
          parsedQuantity = prefixNum + entry.value;
          working = working.substring(m.end).trim();
          break;
        }
      }
    }

    // 3. Check for textual slash fractions (e.g. "1/2", "3/4", "1 1/2")
    if (parsedQuantity == null) {
      final fractionMatch = RegExp(r'^(?:(\d+)\s+)?(\d+)/(\d+)\b').firstMatch(working);
      if (fractionMatch != null) {
        final whole = fractionMatch.group(1) != null ? double.parse(fractionMatch.group(1)!) : 0.0;
        final num = double.parse(fractionMatch.group(2)!);
        final den = double.parse(fractionMatch.group(3)!);
        if (den != 0) {
          parsedQuantity = whole + (num / den);
          working = working.substring(fractionMatch.end).trim();
        }
      }
    }

    // 4. Check for standard decimal or integer digits (e.g. "2", "1.5", ".5")
    if (parsedQuantity == null) {
      final digitMatch = RegExp(r'^(\d+(?:\.\d+)?|\.\d+)\b').firstMatch(working);
      if (digitMatch != null) {
        parsedQuantity = double.tryParse(digitMatch.group(1)!);
        working = working.substring(digitMatch.end).trim();
      }
    }

    // 5. Check for standalone word numbers (e.g. "one", "two", "half", "a", "an")
    if (parsedQuantity == null) {
      final words = working.split(RegExp(r'\s+'));
      if (words.isNotEmpty) {
        final firstWord = words.first.toLowerCase();
        if (_wordNumbers.containsKey(firstWord)) {
          parsedQuantity = _wordNumbers[firstWord];
          working = words.skip(1).join(' ').trim();
        }
      }
    }

    // Default quantity to 1.0 if not detected
    parsedQuantity ??= 1.0;

    // 6. Extract Unit from subsequent tokens
    final unitWords = working.split(RegExp(r'\s+'));
    if (unitWords.isNotEmpty) {
      final candidateUnit = unitWords.first.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      if (_unitSynonyms.containsKey(candidateUnit)) {
        final remainingWords = unitWords.skip(1).join(' ').trim();
        if (remainingWords.isNotEmpty) {
          parsedUnit = _unitSynonyms[candidateUnit];
          working = remainingWords;
        } else {
          // If no remaining words (e.g. "2 rotis", "2 samosas", "4 puris"), candidateUnit is the food entity itself!
          if ([
            'roti', 'rotis', 'chapati', 'chapatis', 'phulka', 'phulkas',
            'puri', 'puris', 'poori', 'pooris',
            'samosa', 'samosas', 'samose',
            'kachori', 'kachoris',
            'ladoo', 'laddu',
            'bhatura', 'bhature',
          ].contains(candidateUnit)) {
            parsedUnit = _unitSynonyms[candidateUnit] ?? 'piece';
            working = candidateUnit;
          } else {
            parsedUnit = _unitSynonyms[candidateUnit];
            working = remainingWords;
          }
        }
      }
    }

    // 7. Strip connector words like "of", "serving of", "portions of"
    working = working.replaceFirst(RegExp(r'^(?:of|servings?\s+of|portions?\s+of)\s+', caseSensitive: false), '').trim();

    // 8. Clean up remaining food query
    final cleanFood = working.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();

    if (cleanFood.isEmpty) return null;

    return ExtractedToken(
      rawSegment: rawSegment,
      quantity: parsedQuantity,
      unit: parsedUnit,
      foodQuery: cleanFood,
    );
  }
}
