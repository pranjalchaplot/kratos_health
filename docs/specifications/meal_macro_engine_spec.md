# Specification: Lightweight Local Meal & Macro Engine

## 1. Executive Summary & Architecture Overview
This specification defines an ultra-lightweight, zero-cloud, deterministic meal-logging and macronutrient computation engine designed for embedded, offline execution on resource-constrained client environments.

The system accepts free-form text and voice-transcribed meal logs (e.g., *"I had 2 bowls of poha and 1 glass of milk"*), parses quantities, units, and food entities deterministically, matches entities against an embedded SQLite database (specialized for Indian IFCT/ICMR staples and global USDA foods), and computes macronutrients without relying on external cloud APIs or neural network models.

```
[ Free-form / Voice Input Log ]
              │
              ▼
[ Step 1: Text Normalization & Segmentation ]
   • Conversational boilerplate stripping
   • Segmentation by conjunctions ("and", ",", "+", "with")
              │
              ▼
[ Step 2: Deterministic Entity & Quantity Extractor ]
   • Numeric and vulgar fraction parsing ("1/2" -> 0.5, "two" -> 2.0)
   • Unit normalization (household & metric)
   • Food token extraction
              │
              ▼
[ Step 3: Local SQLite Entity Resolution (nutrition.db) ]
   • Tier 1: Exact alias resolution in `food_aliases`
   • Tier 2: FTS5 Full-Text Search with BM25 ranking & popularity bias
   • Multi-candidate alternate ranking
              │
              ▼
[ Step 4: Deterministic Arithmetic Formulation ]
   • Serving weight resolution (Unit -> Grams via standard & density overrides)
   • Scaling multiplier computation
   • Macronutrient summation (Calories, Protein, Carbs, Fats)
              │
              ▼
[ Standardized JSON Response Contract ]
```

---

## 2. Technical Constraints & Non-Functional Requirements (NFRs)
1. **Disk Footprint:** The combined size of the SQLite binary database, FTS5 virtual tables, parser definitions, and seed data must **strictly remain $< 20\text{ MB}$** (Target: $< 5\text{ MB}$).
2. **Zero Cloud Dependency:** 100% offline functionality. No remote API calls, no network telemetry, and no remote embedding services.
3. **Deterministic Math:** Identical input strings and serving weights must yield mathematically identical macronutrient outputs to 2 decimal places.
4. **Latency:** Parse, entity lookup, and macro computation must execute in $< 50\text{ ms}$ on standard mobile hardware.
5. **Platform Independence:** The specifications below use standard SQL, POSIX/PCRE Regular Expressions, and pure arithmetic logic.

---

## 3. Data Modeling & Relational Schema (SQL DDL)

The database schema models both foundational raw ingredients (normalized per 100g edible portion) and composite cooked recipes made of multiple raw ingredients.

```sql
-- 1. Base Ingredients (Normalized to per 100g edible portion)
CREATE TABLE IF NOT EXISTS ingredients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    calories_per_100g REAL NOT NULL,
    protein_per_100g REAL NOT NULL,
    carbs_per_100g REAL NOT NULL,
    fat_per_100g REAL NOT NULL,
    source TEXT NOT NULL DEFAULT 'IFCT_2017', -- 'IFCT_2017' | 'USDA'
    is_canonical_default INTEGER NOT NULL DEFAULT 0,
    popularity_rank INTEGER NOT NULL DEFAULT 100
);

-- 2. Composite Recipes (Cooked dishes made from ingredients)
CREATE TABLE IF NOT EXISTS recipes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    standard_serving_unit TEXT NOT NULL, -- 'bowl', 'plate', 'katori', 'piece', 'cup'
    standard_serving_grams REAL NOT NULL,
    source TEXT NOT NULL DEFAULT 'NIN_ICMR',
    is_canonical_default INTEGER NOT NULL DEFAULT 0,
    popularity_rank INTEGER NOT NULL DEFAULT 100
);

-- 3. Recipe Ingredient Breakdown (Normalized ingredients per 1 standard serving)
CREATE TABLE IF NOT EXISTS recipe_ingredients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    recipe_id INTEGER NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    ingredient_id INTEGER NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
    grams_used REAL NOT NULL
);

-- 4. Food Aliases & Regional Synonyms
CREATE TABLE IF NOT EXISTS food_aliases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    alias TEXT NOT NULL UNIQUE,
    entity_type TEXT NOT NULL CHECK(entity_type IN ('RECIPE', 'INGREDIENT')),
    entity_id INTEGER NOT NULL
);

-- 5. Standard Unit Conversions & Food Density Overrides
CREATE TABLE IF NOT EXISTS unit_conversions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    unit_name TEXT NOT NULL,
    default_grams REAL NOT NULL,
    entity_type TEXT NULL CHECK(entity_type IN ('RECIPE', 'INGREDIENT', NULL)),
    entity_id INTEGER NULL,
    override_grams REAL NULL
);

-- 6. SQLite FTS5 Full-Text Search Virtual Table
CREATE VIRTUAL TABLE IF NOT EXISTS entity_fts USING fts5(
    name,
    aliases,
    entity_type UNINDEXED,
    entity_id UNINDEXED,
    tokenize = 'porter unicode61 remove_diacritics 1'
);

-- Indices for performance
CREATE INDEX IF NOT EXISTS idx_aliases_alias ON food_aliases(alias);
CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_recipe ON recipe_ingredients(recipe_id);
CREATE INDEX IF NOT EXISTS idx_unit_conversions_unit ON unit_conversions(unit_name);
```

---

## 4. NLP & Text Parser Specification

### 4.1 Boilerplate Stripping
Conversational prefixes, suffixes, and filler phrases must be stripped before segmentation:
* Prefixes: `^(\s*(i\s+(had|ate|drank|consumed|took|eat)|for\s+(breakfast|lunch|dinner|snack|supper)|having|eating|drinking)\s+)`
* Conjunctions / Delimiters: `(?:\s+and\s+|\s*,\s*|\s*\+\s*|\s+with\s+|\s+along\s+with\s+|\s+plus\s+)`

### 4.2 Numeric & Fraction Parsing
The parser supports integers, decimals, vulgar unicode fractions, textual slash fractions, and word numerals:

| Input Format | Sample | Parsed Float |
| :--- | :--- | :--- |
| Integer / Decimal | `2`, `1.5`, `.5` | `2.0`, `1.5`, `0.5` |
| Textual Fraction | `1/2`, `3/4`, `1 1/2` | `0.5`, `0.75`, `1.5` |
| Vulgar Fraction | `½`, `¼`, `¾`, `1½` | `0.5`, `0.25`, `0.75`, `1.5` |
| Word Numerals | `"half"`, `"quarter"`, `"one"`, `"two"`, `"three"`, `"four"` | `0.5`, `0.25`, `1.0`, `2.0`, `3.0`, `4.0` |
| Word Combinations | `"two and a half"`, `"one and a quarter"` | `2.5`, `1.25` |

### 4.3 Serving Unit Normalization
Household and metric unit variants are normalized to standard keys:

| Canonical Key | Recognized Input Variants | Default Weight |
| :--- | :--- | :--- |
| `katori` | `katori`, `katoris`, `small bowl` | 150g |
| `bowl` | `bowl`, `bowls`, `medium bowl` | 200g |
| `plate` | `plate`, `plates`, `dish` | 300g |
| `glass` | `glass`, `glasses`, `tumbler` | 250g / 250ml |
| `cup` | `cup`, `cups` | 240g / 240ml |
| `piece` | `piece`, `pieces`, `pc`, `pcs`, `slice`, `slices`, `item` | Entity standard |
| `roti` | `roti`, `rotis`, `chapati`, `chapatis`, `phulka`, `phulkas` | 35g |
| `tbsp` | `tbsp`, `tablespoon`, `tablespoons` | 15g |
| `tsp` | `tsp`, `teaspoon`, `teaspoons` | 5g |
| `g` | `g`, `gram`, `grams`, `gm`, `gms` | 1g |
| `kg` | `kg`, `kilogram`, `kilograms` | 1000g |
| `ml` | `ml`, `milliliter`, `milliliters` | 1g (density 1.0) |

### 4.4 Default Fallback Rules
1. **Quantity Fallback:** If no numeric quantity is extracted (e.g., *"bowl of poha"*), default to `1.0`.
2. **Unit Fallback:** If no unit is specified (e.g., *"2 rotis"* or *"1 apple"*), default to the matched entity's `standard_serving_unit` (`piece`, `bowl`, etc.).

---

## 5. Entity Resolution Pipeline

### Tier 1: Exact Alias Lookup
Query `food_aliases` where `alias = LOWER(TRIM(:token))`. If found, resolve directly with confidence score $1.0$.

### Tier 2: FTS5 Full-Text Search
When no exact alias matches, execute SQLite FTS5 search on `entity_fts`:
```sql
SELECT entity_type, entity_id, name, bm25(entity_fts) as score
FROM entity_fts
WHERE entity_fts MATCH :search_pattern
ORDER BY score ASC, popularity_rank ASC
LIMIT 4;
```
Where `:search_pattern` includes prefix tokens (e.g. `poha*`).
- **Confidence Scoring:**
  - Exact name match: $0.95$
  - FTS top rank: $\max(0.40, 1.0 - (\text{score} \times 0.1))$
  - Alternate suggestions: Top 3 remaining records returned as selectable alternatives.

---

## 6. Deterministic Arithmetic Formulation

### 6.1 Serving Weight Resolution
$$\text{Total Edible Grams} = \text{Parsed Quantity} \times \text{Unit Gram Weight}$$
Where $\text{Unit Gram Weight}$ is resolved from:
1. Specific override in `unit_conversions` for `(entity_type, entity_id, unit_name)`.
2. Standard unit default from `unit_conversions` for `unit_name`.
3. Entity's `standard_serving_grams` if unit is `piece` or unspecified.

### 6.2 Scaling Factor Calculation
For composite recipes:
$$\text{Scale Multiplier} = \frac{\text{Total Edible Grams}}{\text{Recipe Standard Serving Grams}}$$

For foundational ingredients:
$$\text{Scale Multiplier} = \frac{\text{Total Edible Grams}}{100}$$

### 6.3 Macronutrient Summation
For a Recipe composed of $k$ ingredients:
$$\text{Nutrient} = \sum_{k \in \text{Ingredients}} \left( \text{Nutrient per 100g}_k \times \frac{\text{Grams Used}_k}{100} \right) \times \text{Scale Multiplier}$$

For a single Ingredient:
$$\text{Nutrient} = \text{Nutrient per 100g} \times \text{Scale Multiplier}$$

Aggregated totals across all items in a log:
$$\text{Total Macro} = \sum_{i \in \text{Items}} \text{Macro}_i$$

---

## 7. JSON Output Data Contract

```json
{
  "query": "I had 2 bowls of poha and 1 glass of milk",
  "status": "SUCCESS",
  "items": [
    {
      "raw_input": "2 bowls of poha",
      "resolved_entity_id": 1,
      "entity_name": "Poha (Cooked)",
      "entity_type": "RECIPE",
      "quantity": 2.0,
      "unit": "bowl",
      "calculated_grams": 400.0,
      "confidence_score": 1.0,
      "macros": {
        "calories": 520.0,
        "protein_g": 9.2,
        "carbs_g": 92.4,
        "fat_g": 13.8
      },
      "alternates": []
    },
    {
      "raw_input": "1 glass of milk",
      "resolved_entity_id": 4,
      "entity_name": "Cow Milk (Toned)",
      "entity_type": "INGREDIENT",
      "quantity": 1.0,
      "unit": "glass",
      "calculated_grams": 250.0,
      "confidence_score": 0.95,
      "macros": {
        "calories": 147.5,
        "protein_g": 7.75,
        "carbs_g": 11.75,
        "fat_g": 7.5
      },
      "alternates": [
        {
          "entity_id": 5,
          "name": "Buffalo Milk (Full Cream)",
          "entity_type": "INGREDIENT",
          "confidence_score": 0.85
        },
        {
          "entity_id": 6,
          "name": "Almond Milk (Unsweetened)",
          "entity_type": "INGREDIENT",
          "confidence_score": 0.80
        }
      ]
    }
  ],
  "total_macros": {
    "calories": 667.5,
    "protein_g": 16.95,
    "carbs_g": 104.15,
    "fat_g": 21.3
  },
  "unresolved_tokens": []
}
```
