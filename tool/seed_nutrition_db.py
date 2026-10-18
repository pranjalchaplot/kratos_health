#!/usr/bin/env python3
"""
Seed script for generating the lightweight embedded SQLite nutrition database (`assets/database/nutrition.db`).
Complies with IFCT (Indian Food Composition Tables 2017 / NIN / ICMR) and USDA Foundation Foods.
Strictly verified to stay under 20 MB (target ~2-4 MB).
"""

import os
import sqlite3
import sys

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "database")
DB_PATH = os.path.join(OUTPUT_DIR, "nutrition.db")

def create_tables(cur):
    cur.executescript("""
    DROP TABLE IF EXISTS entity_fts;
    DROP TABLE IF EXISTS unit_conversions;
    DROP TABLE IF EXISTS food_aliases;
    DROP TABLE IF EXISTS recipe_ingredients;
    DROP TABLE IF EXISTS recipes;
    DROP TABLE IF EXISTS ingredients;

    -- 1. Base Ingredients (Normalized to per 100g edible portion)
    CREATE TABLE ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        calories_per_100g REAL NOT NULL,
        protein_per_100g REAL NOT NULL,
        carbs_per_100g REAL NOT NULL,
        fat_per_100g REAL NOT NULL,
        source TEXT NOT NULL DEFAULT 'IFCT_2017',
        is_canonical_default INTEGER NOT NULL DEFAULT 0,
        popularity_rank INTEGER NOT NULL DEFAULT 100
    );

    -- 2. Composite Recipes (Cooked dishes composed of raw ingredients)
    CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        standard_serving_unit TEXT NOT NULL,
        standard_serving_grams REAL NOT NULL,
        source TEXT NOT NULL DEFAULT 'NIN_ICMR',
        is_canonical_default INTEGER NOT NULL DEFAULT 0,
        popularity_rank INTEGER NOT NULL DEFAULT 100,
        is_custom INTEGER NOT NULL DEFAULT 0
    );

    -- 3. Recipe Ingredients breakdown per 1 standard serving
    CREATE TABLE recipe_ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
        ingredient_id INTEGER NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
        grams_used REAL NOT NULL
    );

    -- 4. Food Aliases & Regional Synonyms
    CREATE TABLE food_aliases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        alias TEXT NOT NULL,
        entity_type TEXT NOT NULL CHECK(entity_type IN ('RECIPE', 'INGREDIENT')),
        entity_id INTEGER NOT NULL,
        is_custom INTEGER NOT NULL DEFAULT 0
    );

    -- 5. Standard Unit Conversions & Overrides
    CREATE TABLE unit_conversions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unit_name TEXT NOT NULL,
        default_grams REAL NOT NULL,
        entity_type TEXT NULL CHECK(entity_type IN ('RECIPE', 'INGREDIENT', NULL)),
        entity_id INTEGER NULL,
        override_grams REAL NULL
    );

    -- 6. Full-Text Search Virtual Table (FTS5)
    CREATE VIRTUAL TABLE entity_fts USING fts5(
        name,
        aliases,
        entity_type UNINDEXED,
        entity_id UNINDEXED,
        is_custom UNINDEXED,
        tokenize = 'porter unicode61 remove_diacritics 1'
    );

    -- Indexes
    CREATE INDEX idx_aliases_alias ON food_aliases(alias);
    CREATE INDEX idx_recipe_ingredients_recipe ON recipe_ingredients(recipe_id);
    CREATE INDEX idx_unit_conversions_unit ON unit_conversions(unit_name);
    """)

# Master Ingredients Data (values per 100g edible portion: kcal, protein, carbs, fat, source, canonical, rank)
INGREDIENTS_DATA = [
    # Grains & Cereals
    ("Flattened Rice (Poha Raw)", 346.0, 6.6, 77.3, 1.2, "IFCT_2017", 0, 80),
    ("Whole Wheat Flour (Atta)", 320.0, 10.6, 64.9, 1.7, "IFCT_2017", 1, 90),
    ("White Rice (Raw)", 345.0, 6.8, 78.2, 0.5, "IFCT_2017", 0, 75),
    ("Brown Rice (Raw)", 335.0, 7.5, 71.0, 2.3, "IFCT_2017", 0, 60),
    ("Semolina (Suji/Rava)", 334.0, 10.2, 70.0, 1.0, "IFCT_2017", 0, 65),
    ("Rolled Oats", 374.0, 13.6, 62.8, 7.0, "USDA", 1, 85),
    ("Ragi Flour (Finger Millet)", 320.0, 7.3, 66.8, 1.3, "IFCT_2017", 0, 60),
    ("Jowar Flour (Sorghum)", 334.0, 10.4, 67.7, 1.9, "IFCT_2017", 0, 55),
    ("Bajra Flour (Pearl Millet)", 348.0, 11.6, 61.8, 5.0, "IFCT_2017", 0, 55),
    ("Bread (White)", 265.0, 9.0, 49.0, 3.2, "USDA", 0, 70),
    ("Bread (Whole Wheat)", 247.0, 13.0, 41.0, 3.4, "USDA", 1, 75),

    # Pulses & Legumes
    ("Toor Dal (Yellow Pigeon Pea)", 335.0, 22.3, 57.6, 1.7, "IFCT_2017", 1, 95),
    ("Moong Dal (Yellow Split)", 326.0, 24.5, 59.9, 1.2, "IFCT_2017", 0, 85),
    ("Chana Dal (Split Chickpeas)", 372.0, 20.8, 59.8, 5.6, "IFCT_2017", 0, 80),
    ("Urad Dal (Black Gram Split)", 328.0, 24.0, 59.6, 1.4, "IFCT_2017", 0, 75),
    ("Rajma (Red Kidney Beans)", 333.0, 22.9, 60.6, 1.3, "IFCT_2017", 1, 85),
    ("Kabuli Chana (White Chickpeas)", 360.0, 20.5, 60.0, 5.3, "IFCT_2017", 1, 80),
    ("Soybean (Dry)", 432.0, 36.5, 30.2, 19.9, "IFCT_2017", 0, 65),

    # Dairy & Eggs
    ("Cow Milk (Toned 3% Fat)", 59.0, 3.1, 4.7, 3.0, "IFCT_2017", 1, 95),
    ("Cow Milk (Full Cream)", 73.0, 3.3, 4.8, 4.5, "IFCT_2017", 0, 80),
    ("Buffalo Milk (Whole)", 107.0, 4.3, 5.0, 7.5, "IFCT_2017", 0, 75),
    ("Almond Milk (Unsweetened)", 15.0, 0.6, 0.3, 1.2, "USDA", 0, 50),
    ("Curd / Dahi (Toned)", 60.0, 3.8, 4.4, 3.1, "IFCT_2017", 1, 90),
    ("Curd / Dahi (Full Cream)", 98.0, 4.3, 5.0, 6.5, "IFCT_2017", 0, 80),
    ("Paneer (Fresh Cottage Cheese)", 289.0, 18.3, 4.0, 22.0, "IFCT_2017", 1, 95),
    ("Tofu (Firm)", 83.0, 10.0, 2.1, 4.2, "USDA", 0, 60),
    ("Desi Ghee (Clarified Butter)", 897.0, 0.0, 0.0, 99.7, "IFCT_2017", 1, 90),
    ("Butter (Salted)", 717.0, 0.8, 0.1, 81.1, "USDA", 0, 75),
    ("Whole Egg (Raw)", 143.0, 12.6, 0.7, 9.5, "USDA", 1, 95),
    ("Egg White", 52.0, 10.9, 0.7, 0.2, "USDA", 0, 80),
    ("Whey Protein Isolate (Unflavored)", 370.0, 88.0, 2.0, 1.0, "USDA", 1, 90),

    # Poultry, Meat & Seafood
    ("Chicken Breast (Skinless Raw)", 120.0, 22.5, 0.0, 2.6, "USDA", 1, 95),
    ("Chicken Thigh (Skinless Raw)", 177.0, 19.9, 0.0, 10.9, "USDA", 0, 75),
    ("Mutton / Goat Meat (Lean)", 143.0, 20.6, 0.0, 6.0, "IFCT_2017", 1, 75),
    ("Rohu Fish (Raw)", 97.0, 17.5, 0.0, 2.5, "IFCT_2017", 1, 70),
    ("Salmon (Raw)", 208.0, 20.4, 0.0, 13.4, "USDA", 0, 65),

    # Nuts & Seeds
    ("Peanuts (Raw/Roasted)", 567.0, 25.8, 16.1, 49.2, "IFCT_2017", 1, 85),
    ("Almonds", 579.0, 21.2, 21.6, 49.9, "USDA", 1, 85),
    ("Walnuts", 654.0, 15.2, 13.7, 65.2, "USDA", 0, 75),
    ("Cashews", 553.0, 18.2, 30.2, 43.8, "USDA", 0, 75),
    ("Peanut Butter", 588.0, 25.0, 20.0, 50.0, "USDA", 1, 80),

    # Vegetables & Fruits
    ("Potato (Raw)", 77.0, 2.0, 17.5, 0.1, "IFCT_2017", 1, 85),
    ("Onion (Raw)", 40.0, 1.1, 9.3, 0.1, "IFCT_2017", 0, 80),
    ("Tomato (Ripe Raw)", 18.0, 0.9, 3.9, 0.2, "IFCT_2017", 0, 80),
    ("Spinach (Palak Raw)", 23.0, 2.9, 3.6, 0.4, "IFCT_2017", 1, 75),
    ("Cauliflower (Gobi)", 25.0, 1.9, 5.0, 0.3, "IFCT_2017", 0, 70),
    ("Ladyfinger (Bhindi/Okra)", 33.0, 1.9, 7.5, 0.2, "IFCT_2017", 1, 70),
    ("Green Peas (Raw)", 81.0, 5.4, 14.5, 0.4, "IFCT_2017", 0, 70),
    ("Banana (Ripe)", 89.0, 1.1, 22.8, 0.3, "IFCT_2017", 1, 95),
    ("Apple", 52.0, 0.3, 13.8, 0.2, "USDA", 1, 90),
    ("Orange", 47.0, 0.9, 11.8, 0.1, "USDA", 0, 75),
    ("Papaya (Ripe)", 43.0, 0.5, 10.8, 0.3, "IFCT_2017", 0, 70),
    ("Mango (Ripe)", 60.0, 0.8, 15.0, 0.4, "IFCT_2017", 1, 80),

    # Oils, Fats, Sweeteners
    ("Vegetable Cooking Oil", 884.0, 0.0, 0.0, 100.0, "IFCT_2017", 0, 85),
    ("Olive Oil", 884.0, 0.0, 0.0, 100.0, "USDA", 0, 75),
    ("Mustard Oil", 884.0, 0.0, 0.0, 100.0, "IFCT_2017", 0, 70),
    ("Sugar (Granulated)", 387.0, 0.0, 100.0, 0.0, "IFCT_2017", 0, 80),
    ("Honey", 304.0, 0.3, 82.4, 0.0, "USDA", 0, 75),
    ("Jaggery (Gur)", 383.0, 0.4, 95.0, 0.1, "IFCT_2017", 1, 75),

    # Extended Ingredients for Street Food, Sweets, and Regional Curries
    ("Refined Wheat Flour (Maida)", 364.0, 10.3, 76.3, 0.98, "IFCT_2017", 0, 85),
    ("Gram Flour / Chickpea Flour (Besan)", 387.0, 22.4, 57.8, 5.3, "IFCT_2017", 1, 90),
    ("Pav / Indian Bread Bun", 270.0, 8.5, 53.0, 2.5, "IFCT_2017", 1, 80),
    ("Mawa / Khoya (Evaporated Milk Solids)", 421.0, 14.6, 25.3, 31.2, "IFCT_2017", 0, 75),
    ("Carrot (Gajar Raw)", 48.0, 0.9, 10.6, 0.2, "IFCT_2017", 0, 75),
    ("Eggplant / Baingan (Raw)", 24.0, 1.4, 4.0, 0.3, "IFCT_2017", 0, 70),
    ("Capsicum / Green Bell Pepper (Raw)", 24.0, 1.3, 4.3, 0.3, "IFCT_2017", 0, 70),
    ("Sago / Sabudana (Dry)", 358.0, 0.2, 88.0, 0.2, "IFCT_2017", 0, 75),
    ("Sev / Fried Gram Flour Noodles", 540.0, 10.0, 48.0, 35.0, "IFCT_2017", 0, 75),
    ("Puri / Golgappa Crispy Shell", 480.0, 8.0, 60.0, 24.0, "IFCT_2017", 0, 75),
    ("Tamarind Pulp (Raw)", 239.0, 2.8, 62.5, 0.6, "IFCT_2017", 0, 70),
    ("Fenugreek Leaves (Methi Raw)", 49.0, 4.4, 6.0, 0.9, "IFCT_2017", 0, 65),
]

# Master Recipes Data (name, standard_serving_unit, standard_serving_grams, canonical, rank, ingredients_breakdown)
RECIPES_DATA = [
    (
        "Poha (Cooked)", "bowl", 200.0, 1, 95,
        [
            ("Flattened Rice (Poha Raw)", 70.0),
            ("Peanuts (Raw/Roasted)", 10.0),
            ("Vegetable Cooking Oil", 8.0),
            ("Onion (Raw)", 30.0),
            ("Potato (Raw)", 20.0),
        ]
    ),
    (
        "Dal Tadka (Yellow Lentil Curry)", "katori", 150.0, 1, 95,
        [
            ("Toor Dal (Yellow Pigeon Pea)", 35.0),
            ("Desi Ghee (Clarified Butter)", 6.0),
            ("Tomato (Ripe Raw)", 25.0),
            ("Onion (Raw)", 20.0),
        ]
    ),
    (
        "Moong Dal (Cooked)", "katori", 150.0, 0, 85,
        [
            ("Moong Dal (Yellow Split)", 35.0),
            ("Desi Ghee (Clarified Butter)", 5.0),
            ("Tomato (Ripe Raw)", 20.0),
        ]
    ),
    (
        "Roti / Chapati", "piece", 35.0, 1, 98,
        [
            ("Whole Wheat Flour (Atta)", 25.0),
            ("Desi Ghee (Clarified Butter)", 2.0),
        ]
    ),
    (
        "Paratha (Plain)", "piece", 60.0, 1, 85,
        [
            ("Whole Wheat Flour (Atta)", 40.0),
            ("Desi Ghee (Clarified Butter)", 10.0),
        ]
    ),
    (
        "Aloo Paratha", "piece", 120.0, 1, 90,
        [
            ("Whole Wheat Flour (Atta)", 45.0),
            ("Potato (Raw)", 60.0),
            ("Desi Ghee (Clarified Butter)", 12.0),
            ("Onion (Raw)", 15.0),
        ]
    ),
    (
        "Paneer Bhurji", "plate", 180.0, 1, 90,
        [
            ("Paneer (Fresh Cottage Cheese)", 120.0),
            ("Vegetable Cooking Oil", 10.0),
            ("Onion (Raw)", 30.0),
            ("Tomato (Ripe Raw)", 20.0),
        ]
    ),
    (
        "Palak Paneer", "bowl", 220.0, 1, 85,
        [
            ("Spinach (Palak Raw)", 140.0),
            ("Paneer (Fresh Cottage Cheese)", 60.0),
            ("Desi Ghee (Clarified Butter)", 10.0),
            ("Onion (Raw)", 25.0),
            ("Tomato (Ripe Raw)", 20.0),
        ]
    ),
    (
        "Khichdi (Moong Dal & Rice)", "bowl", 220.0, 1, 85,
        [
            ("White Rice (Raw)", 40.0),
            ("Moong Dal (Yellow Split)", 30.0),
            ("Desi Ghee (Clarified Butter)", 8.0),
        ]
    ),
    (
        "Rajma Masala (Curry)", "bowl", 200.0, 1, 90,
        [
            ("Rajma (Red Kidney Beans)", 45.0),
            ("Vegetable Cooking Oil", 8.0),
            ("Onion (Raw)", 35.0),
            ("Tomato (Ripe Raw)", 35.0),
        ]
    ),
    (
        "Chana Masala / Chole", "bowl", 200.0, 1, 90,
        [
            ("Kabuli Chana (White Chickpeas)", 50.0),
            ("Vegetable Cooking Oil", 10.0),
            ("Onion (Raw)", 35.0),
            ("Tomato (Ripe Raw)", 30.0),
        ]
    ),
    (
        "Cooked White Rice (Steamed)", "bowl", 180.0, 1, 95,
        [
            ("White Rice (Raw)", 60.0),
        ]
    ),
    (
        "Cooked Brown Rice (Steamed)", "bowl", 180.0, 0, 75,
        [
            ("Brown Rice (Raw)", 60.0),
        ]
    ),
    (
        "Idli (Steamed)", "piece", 40.0, 1, 90,
        [
            ("White Rice (Raw)", 20.0),
            ("Urad Dal (Black Gram Split)", 10.0),
        ]
    ),
    (
        "Dosa (Plain)", "piece", 80.0, 1, 90,
        [
            ("White Rice (Raw)", 45.0),
            ("Urad Dal (Black Gram Split)", 15.0),
            ("Vegetable Cooking Oil", 8.0),
        ]
    ),
    (
        "Sambar", "bowl", 200.0, 1, 85,
        [
            ("Toor Dal (Yellow Pigeon Pea)", 25.0),
            ("Vegetable Cooking Oil", 5.0),
            ("Tomato (Ripe Raw)", 30.0),
            ("Onion (Raw)", 25.0),
        ]
    ),
    (
        "Upma (Semolina)", "bowl", 200.0, 1, 85,
        [
            ("Semolina (Suji/Rava)", 55.0),
            ("Vegetable Cooking Oil", 10.0),
            ("Peanuts (Raw/Roasted)", 8.0),
            ("Onion (Raw)", 25.0),
        ]
    ),
    (
        "Chicken Curry (Indian Style)", "bowl", 220.0, 1, 95,
        [
            ("Chicken Breast (Skinless Raw)", 120.0),
            ("Vegetable Cooking Oil", 12.0),
            ("Onion (Raw)", 40.0),
            ("Tomato (Ripe Raw)", 30.0),
        ]
    ),
    (
        "Boiled Whole Egg", "piece", 50.0, 1, 98,
        [
            ("Whole Egg (Raw)", 50.0),
        ]
    ),
    (
        "Egg Omelette (2 Eggs)", "piece", 120.0, 1, 95,
        [
            ("Whole Egg (Raw)", 100.0),
            ("Vegetable Cooking Oil", 8.0),
            ("Onion (Raw)", 15.0),
            ("Tomato (Ripe Raw)", 10.0),
        ]
    ),
    (
        "Egg Bhurji (Scrambled)", "plate", 140.0, 1, 90,
        [
            ("Whole Egg (Raw)", 100.0),
            ("Vegetable Cooking Oil", 10.0),
            ("Onion (Raw)", 25.0),
            ("Tomato (Ripe Raw)", 15.0),
        ]
    ),
    (
        "Chai / Indian Milk Tea", "cup", 150.0, 1, 95,
        [
            ("Cow Milk (Toned 3% Fat)", 100.0),
            ("Sugar (Granulated)", 6.0),
        ]
    ),
    (
        "Coffee with Milk", "cup", 150.0, 1, 90,
        [
            ("Cow Milk (Toned 3% Fat)", 110.0),
            ("Sugar (Granulated)", 6.0),
        ]
    ),
    (
        "Sweet Lassi", "glass", 250.0, 1, 85,
        [
            ("Curd / Dahi (Toned)", 180.0),
            ("Sugar (Granulated)", 18.0),
        ]
    ),
    (
        "Chaas / Salted Buttermilk", "glass", 250.0, 1, 90,
        [
            ("Curd / Dahi (Toned)", 80.0),
        ]
    ),
    (
        "Oatmeal Porridge with Milk", "bowl", 250.0, 1, 90,
        [
            ("Rolled Oats", 40.0),
            ("Cow Milk (Toned 3% Fat)", 200.0),
            ("Honey", 10.0),
        ]
    ),
    (
        "Whey Protein Shake (with Milk)", "glass", 300.0, 1, 90,
        [
            ("Whey Protein Isolate (Unflavored)", 30.0),
            ("Cow Milk (Toned 3% Fat)", 250.0),
        ]
    ),
    (
        "Whey Protein Shake (with Water)", "glass", 280.0, 0, 85,
        [
            ("Whey Protein Isolate (Unflavored)", 30.0),
        ]
    ),

    # Indian Snacks & Street Food
    (
        "Samosa (Aloo Samosa)", "piece", 85.0, 1, 98,
        [
            ("Refined Wheat Flour (Maida)", 35.0),
            ("Potato (Raw)", 35.0),
            ("Vegetable Cooking Oil", 12.0),
            ("Green Peas (Raw)", 5.0),
        ]
    ),
    (
        "Kachori (Khasta Dal Kachori)", "piece", 75.0, 1, 95,
        [
            ("Refined Wheat Flour (Maida)", 32.0),
            ("Moong Dal (Yellow Split)", 18.0),
            ("Vegetable Cooking Oil", 15.0),
            ("Gram Flour / Chickpea Flour (Besan)", 5.0),
        ]
    ),
    (
        "Pyaaz Kachori (Onion Kachori)", "piece", 90.0, 1, 90,
        [
            ("Refined Wheat Flour (Maida)", 35.0),
            ("Onion (Raw)", 32.0),
            ("Vegetable Cooking Oil", 16.0),
            ("Gram Flour / Chickpea Flour (Besan)", 6.0),
        ]
    ),
    (
        "Pakora / Bhajiya (Onion / Kanda Bhaji)", "plate", 120.0, 1, 95,
        [
            ("Onion (Raw)", 60.0),
            ("Gram Flour / Chickpea Flour (Besan)", 40.0),
            ("Vegetable Cooking Oil", 18.0),
        ]
    ),
    (
        "Paneer Pakora", "plate", 130.0, 1, 90,
        [
            ("Paneer (Fresh Cottage Cheese)", 65.0),
            ("Gram Flour / Chickpea Flour (Besan)", 35.0),
            ("Vegetable Cooking Oil", 18.0),
        ]
    ),
    (
        "Vada Pav", "piece", 130.0, 1, 98,
        [
            ("Pav / Indian Bread Bun", 50.0),
            ("Potato (Raw)", 50.0),
            ("Gram Flour / Chickpea Flour (Besan)", 15.0),
            ("Vegetable Cooking Oil", 12.0),
        ]
    ),
    (
        "Pav Bhaji", "plate", 300.0, 1, 98,
        [
            ("Pav / Indian Bread Bun", 100.0),
            ("Potato (Raw)", 80.0),
            ("Tomato (Ripe Raw)", 50.0),
            ("Butter (Salted)", 25.0),
            ("Green Peas (Raw)", 30.0),
            ("Onion (Raw)", 25.0),
        ]
    ),
    (
        "Chole Bhature", "plate", 350.0, 1, 98,
        [
            ("Refined Wheat Flour (Maida)", 80.0),
            ("Kabuli Chana (White Chickpeas)", 60.0),
            ("Vegetable Cooking Oil", 25.0),
            ("Onion (Raw)", 30.0),
            ("Tomato (Ripe Raw)", 30.0),
        ]
    ),
    (
        "Bhatura", "piece", 75.0, 0, 85,
        [
            ("Refined Wheat Flour (Maida)", 45.0),
            ("Vegetable Cooking Oil", 16.0),
        ]
    ),
    (
        "Puri (Poori)", "piece", 30.0, 1, 95,
        [
            ("Whole Wheat Flour (Atta)", 20.0),
            ("Vegetable Cooking Oil", 7.0),
        ]
    ),
    (
        "Puri Bhaji / Aloo Puri", "plate", 220.0, 1, 92,
        [
            ("Whole Wheat Flour (Atta)", 70.0),
            ("Potato (Raw)", 90.0),
            ("Vegetable Cooking Oil", 22.0),
            ("Tomato (Ripe Raw)", 25.0),
        ]
    ),
    (
        "Medu Vada", "piece", 50.0, 1, 90,
        [
            ("Urad Dal (Black Gram Split)", 30.0),
            ("Vegetable Cooking Oil", 12.0),
            ("Onion (Raw)", 8.0),
        ]
    ),
    (
        "Masala Dosa", "piece", 160.0, 1, 95,
        [
            ("White Rice (Raw)", 45.0),
            ("Urad Dal (Black Gram Split)", 15.0),
            ("Potato (Raw)", 60.0),
            ("Onion (Raw)", 20.0),
            ("Vegetable Cooking Oil", 10.0),
        ]
    ),
    (
        "Uttapam (Onion Tomato)", "piece", 150.0, 1, 85,
        [
            ("White Rice (Raw)", 50.0),
            ("Urad Dal (Black Gram Split)", 20.0),
            ("Onion (Raw)", 30.0),
            ("Tomato (Ripe Raw)", 25.0),
            ("Vegetable Cooking Oil", 8.0),
        ]
    ),
    (
        "Khaman Dhokla", "piece", 40.0, 1, 90,
        [
            ("Gram Flour / Chickpea Flour (Besan)", 25.0),
            ("Sugar (Granulated)", 3.0),
            ("Vegetable Cooking Oil", 3.0),
        ]
    ),
    (
        "Aloo Tikki", "piece", 60.0, 1, 90,
        [
            ("Potato (Raw)", 45.0),
            ("Vegetable Cooking Oil", 10.0),
            ("Green Peas (Raw)", 8.0),
        ]
    ),
    (
        "Pani Puri / Golgappe (6 pieces)", "plate", 150.0, 1, 98,
        [
            ("Puri / Golgappa Crispy Shell", 30.0),
            ("Potato (Raw)", 40.0),
            ("Kabuli Chana (White Chickpeas)", 25.0),
            ("Tamarind Pulp (Raw)", 8.0),
        ]
    ),
    (
        "Bhel Puri", "plate", 150.0, 1, 90,
        [
            ("Flattened Rice (Poha Raw)", 40.0),
            ("Sev / Fried Gram Flour Noodles", 25.0),
            ("Onion (Raw)", 25.0),
            ("Tomato (Ripe Raw)", 20.0),
            ("Tamarind Pulp (Raw)", 10.0),
        ]
    ),
    (
        "Sev Puri", "plate", 140.0, 1, 90,
        [
            ("Puri / Golgappa Crispy Shell", 30.0),
            ("Potato (Raw)", 40.0),
            ("Sev / Fried Gram Flour Noodles", 30.0),
            ("Onion (Raw)", 20.0),
            ("Tamarind Pulp (Raw)", 10.0),
        ]
    ),
    (
        "Dahi Puri / Dahi Vada", "plate", 180.0, 1, 90,
        [
            ("Curd / Dahi (Toned)", 90.0),
            ("Urad Dal (Black Gram Split)", 35.0),
            ("Sugar (Granulated)", 8.0),
            ("Tamarind Pulp (Raw)", 10.0),
        ]
    ),

    # Popular Indian Curries & Main Courses
    (
        "Dal Makhani", "bowl", 200.0, 1, 95,
        [
            ("Urad Dal (Black Gram Split)", 40.0),
            ("Rajma (Red Kidney Beans)", 15.0),
            ("Butter (Salted)", 15.0),
            ("Cow Milk (Full Cream)", 30.0),
            ("Tomato (Ripe Raw)", 35.0),
        ]
    ),
    (
        "Paneer Butter Masala", "bowl", 200.0, 1, 95,
        [
            ("Paneer (Fresh Cottage Cheese)", 80.0),
            ("Butter (Salted)", 15.0),
            ("Tomato (Ripe Raw)", 50.0),
            ("Onion (Raw)", 25.0),
            ("Cashews", 12.0),
        ]
    ),
    (
        "Kadai Paneer", "bowl", 200.0, 1, 90,
        [
            ("Paneer (Fresh Cottage Cheese)", 80.0),
            ("Vegetable Cooking Oil", 12.0),
            ("Tomato (Ripe Raw)", 40.0),
            ("Onion (Raw)", 30.0),
            ("Capsicum / Green Bell Pepper (Raw)", 25.0),
        ]
    ),
    (
        "Butter Chicken / Murgh Makhani", "bowl", 220.0, 1, 98,
        [
            ("Chicken Breast (Skinless Raw)", 110.0),
            ("Butter (Salted)", 18.0),
            ("Tomato (Ripe Raw)", 50.0),
            ("Cashews", 12.0),
            ("Onion (Raw)", 25.0),
        ]
    ),
    (
        "Chicken Biryani", "plate", 300.0, 1, 98,
        [
            ("White Rice (Raw)", 80.0),
            ("Chicken Breast (Skinless Raw)", 100.0),
            ("Desi Ghee (Clarified Butter)", 15.0),
            ("Onion (Raw)", 35.0),
            ("Curd / Dahi (Toned)", 30.0),
        ]
    ),
    (
        "Mutton Biryani", "plate", 300.0, 1, 90,
        [
            ("White Rice (Raw)", 80.0),
            ("Mutton / Goat Meat (Lean)", 100.0),
            ("Desi Ghee (Clarified Butter)", 18.0),
            ("Onion (Raw)", 35.0),
            ("Curd / Dahi (Toned)", 30.0),
        ]
    ),
    (
        "Veg Biryani / Veg Pulao", "plate", 250.0, 1, 90,
        [
            ("White Rice (Raw)", 70.0),
            ("Green Peas (Raw)", 25.0),
            ("Potato (Raw)", 25.0),
            ("Carrot (Gajar Raw)", 20.0),
            ("Desi Ghee (Clarified Butter)", 12.0),
            ("Onion (Raw)", 25.0),
        ]
    ),
    (
        "Aloo Gobi", "bowl", 180.0, 1, 90,
        [
            ("Potato (Raw)", 60.0),
            ("Cauliflower (Gobi)", 80.0),
            ("Vegetable Cooking Oil", 10.0),
            ("Onion (Raw)", 20.0),
            ("Tomato (Ripe Raw)", 20.0),
        ]
    ),
    (
        "Bhindi Masala (Okra Fry)", "bowl", 150.0, 1, 90,
        [
            ("Ladyfinger (Bhindi/Okra)", 110.0),
            ("Vegetable Cooking Oil", 10.0),
            ("Onion (Raw)", 25.0),
        ]
    ),
    (
        "Baingan Bharta (Roasted Eggplant Mash)", "bowl", 180.0, 1, 85,
        [
            ("Eggplant / Baingan (Raw)", 120.0),
            ("Vegetable Cooking Oil", 10.0),
            ("Onion (Raw)", 30.0),
            ("Tomato (Ripe Raw)", 30.0),
        ]
    ),
    (
        "Kadhi Pakora", "bowl", 200.0, 1, 90,
        [
            ("Curd / Dahi (Toned)", 80.0),
            ("Gram Flour / Chickpea Flour (Besan)", 35.0),
            ("Vegetable Cooking Oil", 10.0),
            ("Desi Ghee (Clarified Butter)", 4.0),
        ]
    ),
    (
        "Naan (Butter)", "piece", 90.0, 1, 90,
        [
            ("Refined Wheat Flour (Maida)", 60.0),
            ("Butter (Salted)", 10.0),
            ("Curd / Dahi (Toned)", 15.0),
        ]
    ),
    (
        "Tandoori Roti", "piece", 40.0, 1, 85,
        [
            ("Whole Wheat Flour (Atta)", 32.0),
        ]
    ),
    (
        "Fish Curry (Indian)", "bowl", 200.0, 1, 85,
        [
            ("Rohu Fish (Raw)", 110.0),
            ("Mustard Oil", 10.0),
            ("Onion (Raw)", 30.0),
            ("Tomato (Ripe Raw)", 25.0),
        ]
    ),

    # Indian Sweets & Desserts
    (
        "Gulab Jamun", "piece", 45.0, 1, 95,
        [
            ("Mawa / Khoya (Evaporated Milk Solids)", 20.0),
            ("Refined Wheat Flour (Maida)", 6.0),
            ("Sugar (Granulated)", 20.0),
            ("Desi Ghee (Clarified Butter)", 6.0),
        ]
    ),
    (
        "Jalebi", "piece", 30.0, 1, 95,
        [
            ("Refined Wheat Flour (Maida)", 12.0),
            ("Sugar (Granulated)", 14.0),
            ("Desi Ghee (Clarified Butter)", 5.0),
        ]
    ),
    (
        "Kaju Katli", "piece", 20.0, 1, 95,
        [
            ("Cashews", 11.0),
            ("Sugar (Granulated)", 9.0),
        ]
    ),
    (
        "Besan Ladoo", "piece", 35.0, 1, 90,
        [
            ("Gram Flour / Chickpea Flour (Besan)", 16.0),
            ("Desi Ghee (Clarified Butter)", 10.0),
            ("Sugar (Granulated)", 12.0),
        ]
    ),
    (
        "Suji Ka Halwa (Sheera)", "bowl", 150.0, 1, 90,
        [
            ("Semolina (Suji/Rava)", 45.0),
            ("Desi Ghee (Clarified Butter)", 20.0),
            ("Sugar (Granulated)", 30.0),
            ("Cashews", 6.0),
        ]
    ),
    (
        "Gajar Ka Halwa", "bowl", 150.0, 1, 90,
        [
            ("Carrot (Gajar Raw)", 120.0),
            ("Cow Milk (Full Cream)", 80.0),
            ("Desi Ghee (Clarified Butter)", 15.0),
            ("Sugar (Granulated)", 20.0),
            ("Mawa / Khoya (Evaporated Milk Solids)", 15.0),
        ]
    ),
    (
        "Rasgulla", "piece", 45.0, 1, 90,
        [
            ("Paneer (Fresh Cottage Cheese)", 18.0),
            ("Sugar (Granulated)", 20.0),
        ]
    ),
    (
        "Sabudana Khichdi", "bowl", 180.0, 1, 85,
        [
            ("Sago / Sabudana (Dry)", 60.0),
            ("Peanuts (Raw/Roasted)", 20.0),
            ("Vegetable Cooking Oil", 10.0),
            ("Potato (Raw)", 30.0),
        ]
    ),
    (
        "Methi Thepla", "piece", 40.0, 1, 85,
        [
            ("Whole Wheat Flour (Atta)", 25.0),
            ("Gram Flour / Chickpea Flour (Besan)", 6.0),
            ("Vegetable Cooking Oil", 6.0),
            ("Fenugreek Leaves (Methi Raw)", 10.0),
        ]
    ),
]

# Aliases for Entity Resolution (alias -> (entity_type, name))
ALIASES_DATA = [
    # Poha
    ("poha", "RECIPE", "Poha (Cooked)"),
    ("avalakki", "RECIPE", "Poha (Cooked)"),
    ("chivda", "RECIPE", "Poha (Cooked)"),
    ("atukulu", "RECIPE", "Poha (Cooked)"),
    ("flattened rice", "RECIPE", "Poha (Cooked)"),
    ("pauwa", "RECIPE", "Poha (Cooked)"),
    ("kanda poha", "RECIPE", "Poha (Cooked)"),
    ("batata poha", "RECIPE", "Poha (Cooked)"),

    # Roti
    ("roti", "RECIPE", "Roti / Chapati"),
    ("rotis", "RECIPE", "Roti / Chapati"),
    ("chapati", "RECIPE", "Roti / Chapati"),
    ("chapatis", "RECIPE", "Roti / Chapati"),
    ("phulka", "RECIPE", "Roti / Chapati"),
    ("phulkas", "RECIPE", "Roti / Chapati"),
    ("rotli", "RECIPE", "Roti / Chapati"),
    ("flatbread", "RECIPE", "Roti / Chapati"),

    # Paratha
    ("paratha", "RECIPE", "Paratha (Plain)"),
    ("parathas", "RECIPE", "Paratha (Plain)"),
    ("parantha", "RECIPE", "Paratha (Plain)"),
    ("aloo paratha", "RECIPE", "Aloo Paratha"),
    ("aloo parathas", "RECIPE", "Aloo Paratha"),

    # Dal
    ("dal", "RECIPE", "Dal Tadka (Yellow Lentil Curry)"),
    ("daal", "RECIPE", "Dal Tadka (Yellow Lentil Curry)"),
    ("dal tadka", "RECIPE", "Dal Tadka (Yellow Lentil Curry)"),
    ("yellow dal", "RECIPE", "Dal Tadka (Yellow Lentil Curry)"),
    ("toor dal", "RECIPE", "Dal Tadka (Yellow Lentil Curry)"),
    ("arhar dal", "RECIPE", "Dal Tadka (Yellow Lentil Curry)"),
    ("moong dal", "RECIPE", "Moong Dal (Cooked)"),
    ("mung dal", "RECIPE", "Moong Dal (Cooked)"),

    # Paneer
    ("paneer", "INGREDIENT", "Paneer (Fresh Cottage Cheese)"),
    ("raw paneer", "INGREDIENT", "Paneer (Fresh Cottage Cheese)"),
    ("cottage cheese", "INGREDIENT", "Paneer (Fresh Cottage Cheese)"),
    ("paneer bhurji", "RECIPE", "Paneer Bhurji"),
    ("palak paneer", "RECIPE", "Palak Paneer"),

    # Rice
    ("rice", "RECIPE", "Cooked White Rice (Steamed)"),
    ("white rice", "RECIPE", "Cooked White Rice (Steamed)"),
    ("cooked rice", "RECIPE", "Cooked White Rice (Steamed)"),
    ("chawal", "RECIPE", "Cooked White Rice (Steamed)"),
    ("steamed rice", "RECIPE", "Cooked White Rice (Steamed)"),
    ("brown rice", "RECIPE", "Cooked Brown Rice (Steamed)"),
    ("khichdi", "RECIPE", "Khichdi (Moong Dal & Rice)"),
    ("khichri", "RECIPE", "Khichdi (Moong Dal & Rice)"),

    # Curries & Pulses
    ("rajma", "RECIPE", "Rajma Masala (Curry)"),
    ("rajma chawal", "RECIPE", "Rajma Masala (Curry)"),
    ("chana masala", "RECIPE", "Chana Masala / Chole"),
    ("chole", "RECIPE", "Chana Masala / Chole"),
    ("chana", "RECIPE", "Chana Masala / Chole"),
    ("sambar", "RECIPE", "Sambar"),
    ("sambhar", "RECIPE", "Sambar"),

    # South Indian
    ("idli", "RECIPE", "Idli (Steamed)"),
    ("idlis", "RECIPE", "Idli (Steamed)"),
    ("dosa", "RECIPE", "Dosa (Plain)"),
    ("dosas", "RECIPE", "Dosa (Plain)"),
    ("plain dosa", "RECIPE", "Dosa (Plain)"),
    ("upma", "RECIPE", "Upma (Semolina)"),

    # Dairy & Milk
    ("milk", "INGREDIENT", "Cow Milk (Toned 3% Fat)"),
    ("cow milk", "INGREDIENT", "Cow Milk (Toned 3% Fat)"),
    ("toned milk", "INGREDIENT", "Cow Milk (Toned 3% Fat)"),
    ("buffalo milk", "INGREDIENT", "Buffalo Milk (Whole)"),
    ("almond milk", "INGREDIENT", "Almond Milk (Unsweetened)"),
    ("dahi", "INGREDIENT", "Curd / Dahi (Toned)"),
    ("curd", "INGREDIENT", "Curd / Dahi (Toned)"),
    ("yogurt", "INGREDIENT", "Curd / Dahi (Toned)"),
    ("yoghurt", "INGREDIENT", "Curd / Dahi (Toned)"),
    ("mosaru", "INGREDIENT", "Curd / Dahi (Toned)"),
    ("perugu", "INGREDIENT", "Curd / Dahi (Toned)"),
    ("ghee", "INGREDIENT", "Desi Ghee (Clarified Butter)"),
    ("desi ghee", "INGREDIENT", "Desi Ghee (Clarified Butter)"),
    ("butter", "INGREDIENT", "Butter (Salted)"),

    # Eggs
    ("egg", "RECIPE", "Boiled Whole Egg"),
    ("eggs", "RECIPE", "Boiled Whole Egg"),
    ("boiled egg", "RECIPE", "Boiled Whole Egg"),
    ("boiled eggs", "RECIPE", "Boiled Whole Egg"),
    ("anda", "RECIPE", "Boiled Whole Egg"),
    ("ande", "RECIPE", "Boiled Whole Egg"),
    ("omelette", "RECIPE", "Egg Omelette (2 Eggs)"),
    ("omelet", "RECIPE", "Egg Omelette (2 Eggs)"),
    ("egg bhurji", "RECIPE", "Egg Bhurji (Scrambled)"),
    ("scrambled egg", "RECIPE", "Egg Bhurji (Scrambled)"),
    ("egg white", "INGREDIENT", "Egg White"),
    ("egg whites", "INGREDIENT", "Egg White"),

    # Meats
    ("chicken", "RECIPE", "Chicken Curry (Indian Style)"),
    ("chicken curry", "RECIPE", "Chicken Curry (Indian Style)"),
    ("chicken breast", "INGREDIENT", "Chicken Breast (Skinless Raw)"),
    ("mutton", "INGREDIENT", "Mutton / Goat Meat (Lean)"),
    ("fish", "INGREDIENT", "Rohu Fish (Raw)"),

    # Fitness & Snacks
    ("oats", "INGREDIENT", "Rolled Oats"),
    ("oatmeal", "RECIPE", "Oatmeal Porridge with Milk"),
    ("whey", "INGREDIENT", "Whey Protein Isolate (Unflavored)"),
    ("whey protein", "INGREDIENT", "Whey Protein Isolate (Unflavored)"),
    ("protein shake", "RECIPE", "Whey Protein Shake (with Milk)"),
    ("peanut butter", "INGREDIENT", "Peanut Butter"),
    ("peanuts", "INGREDIENT", "Peanuts (Raw/Roasted)"),
    ("almonds", "INGREDIENT", "Almonds"),
    ("badam", "INGREDIENT", "Almonds"),
    ("banana", "INGREDIENT", "Banana (Ripe)"),
    ("bananas", "INGREDIENT", "Banana (Ripe)"),
    ("kela", "INGREDIENT", "Banana (Ripe)"),
    ("apple", "INGREDIENT", "Apple"),
    ("apples", "INGREDIENT", "Apple"),
    ("seb", "INGREDIENT", "Apple"),
    ("bread", "INGREDIENT", "Bread (Whole Wheat)"),

    # Beverages
    ("chai", "RECIPE", "Chai / Indian Milk Tea"),
    ("tea", "RECIPE", "Chai / Indian Milk Tea"),
    ("milk tea", "RECIPE", "Chai / Indian Milk Tea"),
    ("coffee", "RECIPE", "Coffee with Milk"),
    ("lassi", "RECIPE", "Sweet Lassi"),
    ("sweet lassi", "RECIPE", "Sweet Lassi"),
    ("chaas", "RECIPE", "Chaas / Salted Buttermilk"),
    ("buttermilk", "RECIPE", "Chaas / Salted Buttermilk"),

    # Samosa & Kachori
    ("samosa", "RECIPE", "Samosa (Aloo Samosa)"),
    ("samosas", "RECIPE", "Samosa (Aloo Samosa)"),
    ("samose", "RECIPE", "Samosa (Aloo Samosa)"),
    ("aloo samosa", "RECIPE", "Samosa (Aloo Samosa)"),
    ("singara", "RECIPE", "Samosa (Aloo Samosa)"),
    ("singada", "RECIPE", "Samosa (Aloo Samosa)"),
    ("shingara", "RECIPE", "Samosa (Aloo Samosa)"),
    ("kachori", "RECIPE", "Kachori (Khasta Dal Kachori)"),
    ("kachoris", "RECIPE", "Kachori (Khasta Dal Kachori)"),
    ("kachodi", "RECIPE", "Kachori (Khasta Dal Kachori)"),
    ("khasta kachori", "RECIPE", "Kachori (Khasta Dal Kachori)"),
    ("dal kachori", "RECIPE", "Kachori (Khasta Dal Kachori)"),
    ("moong dal kachori", "RECIPE", "Kachori (Khasta Dal Kachori)"),
    ("pyaaz kachori", "RECIPE", "Pyaaz Kachori (Onion Kachori)"),
    ("pyaz kachori", "RECIPE", "Pyaaz Kachori (Onion Kachori)"),
    ("onion kachori", "RECIPE", "Pyaaz Kachori (Onion Kachori)"),
    ("jodhpur kachori", "RECIPE", "Pyaaz Kachori (Onion Kachori)"),

    # Pakora & Street Snacks
    ("pakora", "RECIPE", "Pakora / Bhajiya (Onion / Kanda Bhaji)"),
    ("pakoda", "RECIPE", "Pakora / Bhajiya (Onion / Kanda Bhaji)"),
    ("pakoras", "RECIPE", "Pakora / Bhajiya (Onion / Kanda Bhaji)"),
    ("pakode", "RECIPE", "Pakora / Bhajiya (Onion / Kanda Bhaji)"),
    ("bhajiya", "RECIPE", "Pakora / Bhajiya (Onion / Kanda Bhaji)"),
    ("bhajji", "RECIPE", "Pakora / Bhajiya (Onion / Kanda Bhaji)"),
    ("kanda bhaji", "RECIPE", "Pakora / Bhajiya (Onion / Kanda Bhaji)"),
    ("onion pakoda", "RECIPE", "Pakora / Bhajiya (Onion / Kanda Bhaji)"),
    ("onion pakora", "RECIPE", "Pakora / Bhajiya (Onion / Kanda Bhaji)"),
    ("paneer pakora", "RECIPE", "Paneer Pakora"),
    ("paneer pakoda", "RECIPE", "Paneer Pakora"),
    ("vada pav", "RECIPE", "Vada Pav"),
    ("wada pav", "RECIPE", "Vada Pav"),
    ("vadapav", "RECIPE", "Vada Pav"),
    ("wadapav", "RECIPE", "Vada Pav"),
    ("batata vada", "RECIPE", "Vada Pav"),
    ("pav bhaji", "RECIPE", "Pav Bhaji"),
    ("pavbhaji", "RECIPE", "Pav Bhaji"),
    ("bhaji pav", "RECIPE", "Pav Bhaji"),
    ("chole bhature", "RECIPE", "Chole Bhature"),
    ("chole bhatura", "RECIPE", "Chole Bhature"),
    ("chana bhatura", "RECIPE", "Chole Bhature"),
    ("bhatura", "RECIPE", "Bhatura"),
    ("bhature", "RECIPE", "Bhatura"),
    ("puri", "RECIPE", "Puri (Poori)"),
    ("poori", "RECIPE", "Puri (Poori)"),
    ("puris", "RECIPE", "Puri (Poori)"),
    ("pooris", "RECIPE", "Puri (Poori)"),
    ("puri bhaji", "RECIPE", "Puri Bhaji / Aloo Puri"),
    ("poori bhaji", "RECIPE", "Puri Bhaji / Aloo Puri"),
    ("aloo puri", "RECIPE", "Puri Bhaji / Aloo Puri"),
    ("alu puri", "RECIPE", "Puri Bhaji / Aloo Puri"),
    ("medu vada", "RECIPE", "Medu Vada"),
    ("vada", "RECIPE", "Medu Vada"),
    ("vadai", "RECIPE", "Medu Vada"),
    ("sambar vada", "RECIPE", "Medu Vada"),
    ("masala dosa", "RECIPE", "Masala Dosa"),
    ("mysore masala dosa", "RECIPE", "Masala Dosa"),
    ("uttapam", "RECIPE", "Uttapam (Onion Tomato)"),
    ("uthappam", "RECIPE", "Uttapam (Onion Tomato)"),
    ("dhokla", "RECIPE", "Khaman Dhokla"),
    ("khaman", "RECIPE", "Khaman Dhokla"),
    ("khaman dhokla", "RECIPE", "Khaman Dhokla"),
    ("aloo tikki", "RECIPE", "Aloo Tikki"),
    ("tikki", "RECIPE", "Aloo Tikki"),
    ("alu tikki", "RECIPE", "Aloo Tikki"),
    ("pani puri", "RECIPE", "Pani Puri / Golgappe (6 pieces)"),
    ("panipuri", "RECIPE", "Pani Puri / Golgappe (6 pieces)"),
    ("golgappa", "RECIPE", "Pani Puri / Golgappe (6 pieces)"),
    ("golgappe", "RECIPE", "Pani Puri / Golgappe (6 pieces)"),
    ("puchka", "RECIPE", "Pani Puri / Golgappe (6 pieces)"),
    ("phuchka", "RECIPE", "Pani Puri / Golgappe (6 pieces)"),
    ("gupchup", "RECIPE", "Pani Puri / Golgappe (6 pieces)"),
    ("bhel puri", "RECIPE", "Bhel Puri"),
    ("bhelpuri", "RECIPE", "Bhel Puri"),
    ("bhel", "RECIPE", "Bhel Puri"),
    ("sev puri", "RECIPE", "Sev Puri"),
    ("sev batata puri", "RECIPE", "Sev Puri"),
    ("dahi puri", "RECIPE", "Dahi Puri / Dahi Vada"),
    ("dahi vada", "RECIPE", "Dahi Puri / Dahi Vada"),
    ("dahi bhalla", "RECIPE", "Dahi Puri / Dahi Vada"),

    # Main Curries, Biryanis & Breads
    ("dal makhani", "RECIPE", "Dal Makhani"),
    ("daal makhani", "RECIPE", "Dal Makhani"),
    ("paneer butter masala", "RECIPE", "Paneer Butter Masala"),
    ("butter paneer", "RECIPE", "Paneer Butter Masala"),
    ("paneer makhani", "RECIPE", "Paneer Butter Masala"),
    ("shahi paneer", "RECIPE", "Paneer Butter Masala"),
    ("kadai paneer", "RECIPE", "Kadai Paneer"),
    ("kadhai paneer", "RECIPE", "Kadai Paneer"),
    ("butter chicken", "RECIPE", "Butter Chicken / Murgh Makhani"),
    ("murgh makhani", "RECIPE", "Butter Chicken / Murgh Makhani"),
    ("chicken biryani", "RECIPE", "Chicken Biryani"),
    ("biryani", "RECIPE", "Chicken Biryani"),
    ("biriyani", "RECIPE", "Chicken Biryani"),
    ("chicken biriyani", "RECIPE", "Chicken Biryani"),
    ("dum biryani", "RECIPE", "Chicken Biryani"),
    ("mutton biryani", "RECIPE", "Mutton Biryani"),
    ("gosht biryani", "RECIPE", "Mutton Biryani"),
    ("veg biryani", "RECIPE", "Veg Biryani / Veg Pulao"),
    ("vegetable biryani", "RECIPE", "Veg Biryani / Veg Pulao"),
    ("veg pulao", "RECIPE", "Veg Biryani / Veg Pulao"),
    ("pulao", "RECIPE", "Veg Biryani / Veg Pulao"),
    ("aloo gobi", "RECIPE", "Aloo Gobi"),
    ("alu gobi", "RECIPE", "Aloo Gobi"),
    ("gobi aloo", "RECIPE", "Aloo Gobi"),
    ("bhindi", "RECIPE", "Bhindi Masala (Okra Fry)"),
    ("bhindi fry", "RECIPE", "Bhindi Masala (Okra Fry)"),
    ("bhindi masala", "RECIPE", "Bhindi Masala (Okra Fry)"),
    ("okra fry", "RECIPE", "Bhindi Masala (Okra Fry)"),
    ("baingan bharta", "RECIPE", "Baingan Bharta (Roasted Eggplant Mash)"),
    ("baigan bharta", "RECIPE", "Baingan Bharta (Roasted Eggplant Mash)"),
    ("kadhi", "RECIPE", "Kadhi Pakora"),
    ("kadhi pakora", "RECIPE", "Kadhi Pakora"),
    ("naan", "RECIPE", "Naan (Butter)"),
    ("butter naan", "RECIPE", "Naan (Butter)"),
    ("garlic naan", "RECIPE", "Naan (Butter)"),
    ("tandoori roti", "RECIPE", "Tandoori Roti"),
    ("fish curry", "RECIPE", "Fish Curry (Indian)"),
    ("machher jhol", "RECIPE", "Fish Curry (Indian)"),

    # Sweets & Desserts
    ("gulab jamun", "RECIPE", "Gulab Jamun"),
    ("gulabjamun", "RECIPE", "Gulab Jamun"),
    ("jamun", "RECIPE", "Gulab Jamun"),
    ("jalebi", "RECIPE", "Jalebi"),
    ("jalebis", "RECIPE", "Jalebi"),
    ("kaju katli", "RECIPE", "Kaju Katli"),
    ("kaju barfi", "RECIPE", "Kaju Katli"),
    ("besan ladoo", "RECIPE", "Besan Ladoo"),
    ("besan laddu", "RECIPE", "Besan Ladoo"),
    ("ladoo", "RECIPE", "Besan Ladoo"),
    ("laddu", "RECIPE", "Besan Ladoo"),
    ("halwa", "RECIPE", "Suji Ka Halwa (Sheera)"),
    ("suji halwa", "RECIPE", "Suji Ka Halwa (Sheera)"),
    ("sooji halwa", "RECIPE", "Suji Ka Halwa (Sheera)"),
    ("sheera", "RECIPE", "Suji Ka Halwa (Sheera)"),
    ("rava sheera", "RECIPE", "Suji Ka Halwa (Sheera)"),
    ("gajar halwa", "RECIPE", "Gajar Ka Halwa"),
    ("gajar ka halwa", "RECIPE", "Gajar Ka Halwa"),
    ("carrot halwa", "RECIPE", "Gajar Ka Halwa"),
    ("rasgulla", "RECIPE", "Rasgulla"),
    ("roshogolla", "RECIPE", "Rasgulla"),
    ("sabudana khichdi", "RECIPE", "Sabudana Khichdi"),
    ("thepla", "RECIPE", "Methi Thepla"),
    ("methi thepla", "RECIPE", "Methi Thepla"),

    # Raw Staples
    ("maida", "INGREDIENT", "Refined Wheat Flour (Maida)"),
    ("all purpose flour", "INGREDIENT", "Refined Wheat Flour (Maida)"),
    ("besan", "INGREDIENT", "Gram Flour / Chickpea Flour (Besan)"),
    ("gram flour", "INGREDIENT", "Gram Flour / Chickpea Flour (Besan)"),
    ("chickpea flour", "INGREDIENT", "Gram Flour / Chickpea Flour (Besan)"),
    ("pav", "INGREDIENT", "Pav / Indian Bread Bun"),
    ("pao", "INGREDIENT", "Pav / Indian Bread Bun"),
    ("khoya", "INGREDIENT", "Mawa / Khoya (Evaporated Milk Solids)"),
    ("mawa", "INGREDIENT", "Mawa / Khoya (Evaporated Milk Solids)"),
    ("gajar", "INGREDIENT", "Carrot (Gajar Raw)"),
    ("carrot", "INGREDIENT", "Carrot (Gajar Raw)"),
    ("carrots", "INGREDIENT", "Carrot (Gajar Raw)"),
    ("baingan", "INGREDIENT", "Eggplant / Baingan (Raw)"),
    ("eggplant", "INGREDIENT", "Eggplant / Baingan (Raw)"),
    ("brinjal", "INGREDIENT", "Eggplant / Baingan (Raw)"),
    ("capsicum", "INGREDIENT", "Capsicum / Green Bell Pepper (Raw)"),
    ("shimla mirch", "INGREDIENT", "Capsicum / Green Bell Pepper (Raw)"),
    ("sabudana", "INGREDIENT", "Sago / Sabudana (Dry)"),
    ("sago", "INGREDIENT", "Sago / Sabudana (Dry)"),
    ("sev", "INGREDIENT", "Sev / Fried Gram Flour Noodles"),
    ("bhujia", "INGREDIENT", "Sev / Fried Gram Flour Noodles"),
    ("methi", "INGREDIENT", "Fenugreek Leaves (Methi Raw)"),
]

# Standard Unit Conversions (unit_name, default_grams)
UNIT_CONVERSIONS_DATA = [
    ("katori", 150.0),
    ("bowl", 200.0),
    ("plate", 300.0),
    ("glass", 250.0),
    ("cup", 240.0),
    ("piece", 50.0),
    ("slice", 30.0),
    ("roti", 35.0),
    ("tbsp", 15.0),
    ("tsp", 5.0),
    ("scoop", 30.0),
    ("g", 1.0),
    ("gram", 1.0),
    ("grams", 1.0),
    ("kg", 1000.0),
    ("ml", 1.0),
    ("l", 1000.0),
    ("liter", 1000.0),
]

def seed_database():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    print(f"Creating tables in: {DB_PATH}")
    create_tables(cur)

    # 1. Insert Ingredients
    ingredient_id_map = {}
    for name, cal, prot, carb, fat, src, can, rank in INGREDIENTS_DATA:
        cur.execute("""
            INSERT INTO ingredients (name, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, source, is_canonical_default, popularity_rank)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (name, cal, prot, carb, fat, src, can, rank))
        ingredient_id_map[name] = cur.lastrowid

    # 2. Insert Recipes & Recipe Ingredients
    recipe_id_map = {}
    for name, unit, grams, can, rank, ingredients_used in RECIPES_DATA:
        cur.execute("""
            INSERT INTO recipes (name, standard_serving_unit, standard_serving_grams, source, is_canonical_default, popularity_rank)
            VALUES (?, ?, ?, 'NIN_ICMR', ?, ?)
        """, (name, unit, grams, can, rank))
        rec_id = cur.lastrowid
        recipe_id_map[name] = rec_id

        for ing_name, ing_grams in ingredients_used:
            ing_id = ingredient_id_map.get(ing_name)
            if not ing_id:
                raise ValueError(f"Unknown ingredient '{ing_name}' in recipe '{name}'")
            cur.execute("""
                INSERT INTO recipe_ingredients (recipe_id, ingredient_id, grams_used)
                VALUES (?, ?, ?)
            """, (rec_id, ing_id, ing_grams))

    # 3. Insert Food Aliases
    aliases_by_entity = {} # key: (type, id) -> list of aliases
    for alias, ent_type, ent_name in ALIASES_DATA:
        if ent_type == "RECIPE":
            ent_id = recipe_id_map.get(ent_name)
        else:
            ent_id = ingredient_id_map.get(ent_name)

        if not ent_id:
            raise ValueError(f"Unknown target entity '{ent_name}' of type {ent_type}")

        cur.execute("""
            INSERT OR IGNORE INTO food_aliases (alias, entity_type, entity_id)
            VALUES (?, ?, ?)
        """, (alias.lower().strip(), ent_type, ent_id))

        key = (ent_type, ent_id)
        aliases_by_entity.setdefault(key, []).append(alias.lower().strip())

    # 4. Insert Standard Unit Conversions
    for unit, grams in UNIT_CONVERSIONS_DATA:
        cur.execute("""
            INSERT INTO unit_conversions (unit_name, default_grams)
            VALUES (?, ?)
        """, (unit.lower(), grams))

    # 5. Populate FTS5 Virtual Table
    # Add all ingredients to FTS
    for name, cal, prot, carb, fat, src, can, rank in INGREDIENTS_DATA:
        ing_id = ingredient_id_map[name]
        aliases = " ".join(aliases_by_entity.get(("INGREDIENT", ing_id), []))
        cur.execute("""
            INSERT INTO entity_fts (name, aliases, entity_type, entity_id, is_custom)
            VALUES (?, ?, 'INGREDIENT', ?, 0)
        """, (name, aliases, ing_id))

    # Add all recipes to FTS
    for name, unit, grams, can, rank, ingredients_used in RECIPES_DATA:
        rec_id = recipe_id_map[name]
        aliases = " ".join(aliases_by_entity.get(("RECIPE", rec_id), []))
        cur.execute("""
            INSERT INTO entity_fts (name, aliases, entity_type, entity_id, is_custom)
            VALUES (?, ?, 'RECIPE', ?, 0)
        """, (name, aliases, rec_id))

    conn.commit()

    # Optimization: vacuum and analyze to minimize footprint and index query performance
    cur.execute("PRAGMA optimize;")
    cur.execute("VACUUM;")
    conn.commit()
    conn.close()

    # Verify size
    size_bytes = os.path.getsize(DB_PATH)
    size_mb = size_bytes / (1024 * 1024)
    print(f"\n[SUCCESS] SQLite Nutrition Database Generated!")
    print(f"Path: {DB_PATH}")
    print(f"Total Size: {size_bytes} bytes ({size_mb:.2f} MB)")
    print(f"Ingredients count: {len(INGREDIENTS_DATA)}")
    print(f"Recipes count: {len(RECIPES_DATA)}")
    print(f"Aliases count: {len(ALIASES_DATA)}")
    print(f"Unit conversions count: {len(UNIT_CONVERSIONS_DATA)}")

    assert size_mb < 20.0, f"Error: Database size {size_mb} MB exceeds strict 20 MB limit!"
    print("Database size verification: PASSED (< 20 MB).\n")

if __name__ == "__main__":
    seed_database()
