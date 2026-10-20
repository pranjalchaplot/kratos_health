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
    ("Masoor Dal / Red Lentil (Raw)", 343.0, 25.1, 59.0, 0.7, "IFCT_2017", 0, 75),
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
    ("Bottle Gourd / Lauki (Raw)", 14.0, 0.6, 3.4, 0.1, "IFCT_2017", 0, 70),
    ("Cabbage / Patta Gobi (Raw)", 25.0, 1.3, 5.8, 0.1, "IFCT_2017", 0, 70),

    # Extended Ingredients for Beverages, Sandwiches, and Global Fast Food
    ("Black Coffee Brew (Unsweetened)", 1.5, 0.2, 0.2, 0.0, "USDA", 1, 95),
    ("Green Tea Brew (Unsweetened)", 1.0, 0.1, 0.2, 0.0, "USDA", 1, 95),
    ("Tea Brew / Decoction (Unsweetened)", 1.0, 0.1, 0.2, 0.0, "USDA", 1, 95),
    ("Dark Chocolate (70% Cocoa)", 598.0, 7.8, 45.9, 42.6, "USDA", 1, 90),
    ("Milk Chocolate", 535.0, 7.7, 59.4, 29.7, "USDA", 0, 75),
    ("Cocoa Powder (Unsweetened)", 228.0, 19.6, 57.9, 13.7, "USDA", 0, 70),
    ("Cheddar / Processed Cheese", 403.0, 24.9, 1.3, 33.1, "USDA", 1, 85),
    ("Mozzarella Cheese", 300.0, 22.2, 2.2, 22.4, "USDA", 1, 85),
    ("Mayonnaise", 680.0, 1.0, 0.6, 75.0, "USDA", 0, 75),
    ("Burger Bun", 270.0, 9.0, 49.0, 4.0, "USDA", 1, 80),
    ("French Fries (Cooked)", 312.0, 3.4, 41.4, 14.7, "USDA", 1, 85),
    ("Pizza Crust / Base", 266.0, 8.0, 52.0, 2.5, "USDA", 1, 80),
    ("Pasta (Durum Wheat Semolina)", 371.0, 13.0, 74.0, 1.5, "USDA", 1, 85),
    ("Tender Coconut Water", 19.0, 0.7, 3.7, 0.2, "IFCT_2017", 1, 90),
    ("Fresh Orange Juice", 45.0, 0.7, 10.4, 0.2, "USDA", 1, 85),
    ("Sugarcane Juice", 39.0, 0.2, 9.5, 0.1, "IFCT_2017", 1, 80),
    ("Cola / Carbonated Soft Drink", 42.0, 0.0, 10.6, 0.0, "USDA", 0, 80),
    ("Diet Cola / Zero Calorie Soda", 0.0, 0.0, 0.0, 0.0, "USDA", 1, 85),
    ("Energy Drink (Caffeinated)", 45.0, 0.0, 11.0, 0.0, "USDA", 0, 75),
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
        "Urad Dal (Cooked / Tadka)", "katori", 150.0, 1, 92,
        [
            ("Urad Dal (Black Gram Split)", 35.0),
            ("Desi Ghee (Clarified Butter)", 5.0),
            ("Tomato (Ripe Raw)", 20.0),
            ("Onion (Raw)", 15.0),
        ]
    ),
    (
        "Chana Dal (Cooked / Tadka)", "katori", 150.0, 1, 90,
        [
            ("Chana Dal (Split Chickpeas)", 35.0),
            ("Desi Ghee (Clarified Butter)", 5.0),
            ("Tomato (Ripe Raw)", 20.0),
            ("Onion (Raw)", 15.0),
        ]
    ),
    (
        "Masoor Dal (Cooked / Red Lentil)", "katori", 150.0, 1, 90,
        [
            ("Masoor Dal / Red Lentil (Raw)", 35.0),
            ("Desi Ghee (Clarified Butter)", 5.0),
            ("Tomato (Ripe Raw)", 20.0),
            ("Onion (Raw)", 15.0),
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
    (
        "Mixed Vegetable Sabzi (Cooked)", "katori", 150.0, 1, 95,
        [
            ("Cauliflower (Gobi)", 35.0),
            ("Green Peas (Raw)", 25.0),
            ("Potato (Raw)", 25.0),
            ("Carrot (Gajar Raw)", 25.0),
            ("Vegetable Cooking Oil", 8.0),
            ("Tomato (Ripe Raw)", 20.0),
        ]
    ),
    (
        "Jeera Aloo (Dry Potato Sabzi)", "katori", 150.0, 1, 92,
        [
            ("Potato (Raw)", 120.0),
            ("Vegetable Cooking Oil", 10.0),
            ("Desi Ghee (Clarified Butter)", 2.0),
        ]
    ),
    (
        "Aloo Matar (Curry)", "katori", 150.0, 1, 92,
        [
            ("Potato (Raw)", 60.0),
            ("Green Peas (Raw)", 50.0),
            ("Tomato (Ripe Raw)", 25.0),
            ("Onion (Raw)", 20.0),
            ("Vegetable Cooking Oil", 8.0),
        ]
    ),
    (
        "Aloo Shimla Mirch (Cooked Sabzi)", "katori", 150.0, 1, 90,
        [
            ("Potato (Raw)", 60.0),
            ("Capsicum / Green Bell Pepper (Raw)", 60.0),
            ("Tomato (Ripe Raw)", 20.0),
            ("Vegetable Cooking Oil", 8.0),
        ]
    ),
    (
        "Gobi Ki Sabzi / Cauliflower Fry", "katori", 150.0, 1, 90,
        [
            ("Cauliflower (Gobi)", 120.0),
            ("Tomato (Ripe Raw)", 20.0),
            ("Vegetable Cooking Oil", 8.0),
        ]
    ),
    (
        "Lauki Ki Sabzi (Bottle Gourd Curry)", "katori", 150.0, 1, 90,
        [
            ("Bottle Gourd / Lauki (Raw)", 130.0),
            ("Tomato (Ripe Raw)", 20.0),
            ("Vegetable Cooking Oil", 6.0),
        ]
    ),
    (
        "Palak Ki Sabzi / Saag (Cooked)", "katori", 150.0, 1, 90,
        [
            ("Spinach (Palak Raw)", 130.0),
            ("Onion (Raw)", 20.0),
            ("Desi Ghee (Clarified Butter)", 8.0),
        ]
    ),
    (
        "Matar Paneer (Curry)", "bowl", 200.0, 1, 92,
        [
            ("Paneer (Fresh Cottage Cheese)", 60.0),
            ("Green Peas (Raw)", 50.0),
            ("Tomato (Ripe Raw)", 40.0),
            ("Onion (Raw)", 25.0),
            ("Vegetable Cooking Oil", 10.0),
        ]
    ),
    (
        "Cabbage Sabzi / Patta Gobi", "katori", 150.0, 1, 90,
        [
            ("Cabbage / Patta Gobi (Raw)", 120.0),
            ("Green Peas (Raw)", 20.0),
            ("Vegetable Cooking Oil", 8.0),
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

    # Beverages & Cold Drinks
    (
        "Black Coffee (Espresso / Americano)", "cup", 150.0, 1, 95,
        [
            ("Black Coffee Brew (Unsweetened)", 150.0),
        ]
    ),
    (
        "Green Tea / Black Tea (Unsweetened)", "cup", 150.0, 1, 95,
        [
            ("Green Tea Brew (Unsweetened)", 150.0),
        ]
    ),
    (
        "Masala Chai / Indian Milk Tea", "cup", 150.0, 1, 98,
        [
            ("Cow Milk (Toned 3% Fat)", 80.0),
            ("Sugar (Granulated)", 8.0),
            ("Tea Brew / Decoction (Unsweetened)", 62.0),
        ]
    ),
    (
        "Cold Coffee (Iced Blended)", "glass", 300.0, 1, 92,
        [
            ("Cow Milk (Toned 3% Fat)", 220.0),
            ("Sugar (Granulated)", 16.0),
            ("Cocoa Powder (Unsweetened)", 5.0),
        ]
    ),
    (
        "Cappuccino / Cafe Latte", "cup", 200.0, 1, 92,
        [
            ("Cow Milk (Toned 3% Fat)", 160.0),
            ("Sugar (Granulated)", 6.0),
            ("Black Coffee Brew (Unsweetened)", 34.0),
        ]
    ),
    (
        "Lemon Iced Tea", "glass", 250.0, 1, 88,
        [
            ("Tea Brew / Decoction (Unsweetened)", 220.0),
            ("Sugar (Granulated)", 18.0),
            ("Honey", 4.0),
        ]
    ),
    (
        "Tender Coconut Water (Fresh)", "glass", 250.0, 1, 95,
        [
            ("Tender Coconut Water", 250.0),
        ]
    ),
    (
        "Fresh Orange Juice (Glass)", "glass", 250.0, 1, 90,
        [
            ("Fresh Orange Juice", 250.0),
        ]
    ),
    (
        "Fresh Sugarcane Juice", "glass", 250.0, 1, 88,
        [
            ("Sugarcane Juice", 250.0),
        ]
    ),
    (
        "Cola / Carbonated Soft Drink (Can)", "can", 330.0, 1, 90,
        [
            ("Cola / Carbonated Soft Drink", 330.0),
        ]
    ),
    (
        "Diet Coke / Coke Zero (Can)", "can", 330.0, 1, 95,
        [
            ("Diet Cola / Zero Calorie Soda", 330.0),
        ]
    ),
    (
        "Energy Drink (Red Bull Style)", "can", 250.0, 1, 85,
        [
            ("Energy Drink (Caffeinated)", 250.0),
        ]
    ),

    # Sandwiches
    (
        "Dark Chocolate Sandwich", "piece", 140.0, 1, 95,
        [
            ("Bread (White)", 60.0),
            ("Dark Chocolate (70% Cocoa)", 35.0),
            ("Butter (Salted)", 10.0),
        ]
    ),
    (
        "Veg Grilled Sandwich (Bombay Style)", "piece", 180.0, 1, 95,
        [
            ("Bread (White)", 60.0),
            ("Potato (Raw)", 35.0),
            ("Tomato (Ripe Raw)", 25.0),
            ("Onion (Raw)", 20.0),
            ("Capsicum / Green Bell Pepper (Raw)", 15.0),
            ("Butter (Salted)", 10.0),
        ]
    ),
    (
        "Cheese Grilled Sandwich", "piece", 150.0, 1, 92,
        [
            ("Bread (White)", 60.0),
            ("Cheddar / Processed Cheese", 45.0),
            ("Butter (Salted)", 12.0),
        ]
    ),
    (
        "Chicken Club Sandwich", "piece", 220.0, 1, 92,
        [
            ("Bread (Whole Wheat)", 60.0),
            ("Chicken Breast (Skinless Raw)", 80.0),
            ("Mayonnaise", 15.0),
            ("Tomato (Ripe Raw)", 25.0),
            ("Whole Egg (Raw)", 50.0),
        ]
    ),
    (
        "Egg / Omelette Sandwich", "piece", 160.0, 1, 90,
        [
            ("Bread (White)", 60.0),
            ("Whole Egg (Raw)", 50.0),
            ("Butter (Salted)", 8.0),
            ("Onion (Raw)", 15.0),
        ]
    ),
    (
        "Peanut Butter Sandwich", "piece", 110.0, 1, 90,
        [
            ("Bread (Whole Wheat)", 60.0),
            ("Peanut Butter", 35.0),
            ("Honey", 10.0),
        ]
    ),

    # Global & US/Indian Fast Food
    (
        "Veg Burger / Aloo Tikki Burger", "piece", 180.0, 1, 95,
        [
            ("Burger Bun", 70.0),
            ("Potato (Raw)", 50.0),
            ("Vegetable Cooking Oil", 10.0),
            ("Mayonnaise", 12.0),
            ("Onion (Raw)", 15.0),
            ("Tomato (Ripe Raw)", 15.0),
        ]
    ),
    (
        "Chicken Burger (Crispy)", "piece", 190.0, 1, 95,
        [
            ("Burger Bun", 70.0),
            ("Chicken Breast (Skinless Raw)", 90.0),
            ("Mayonnaise", 15.0),
            ("Vegetable Cooking Oil", 12.0),
        ]
    ),
    (
        "Cheeseburger", "piece", 180.0, 1, 92,
        [
            ("Burger Bun", 70.0),
            ("Chicken Breast (Skinless Raw)", 70.0),
            ("Cheddar / Processed Cheese", 25.0),
            ("Mayonnaise", 10.0),
        ]
    ),
    (
        "French Fries (Medium)", "serving", 120.0, 1, 95,
        [
            ("French Fries (Cooked)", 120.0),
        ]
    ),
    (
        "Margherita Pizza (1 Slice)", "slice", 100.0, 1, 95,
        [
            ("Pizza Crust / Base", 55.0),
            ("Mozzarella Cheese", 30.0),
            ("Tomato (Ripe Raw)", 25.0),
            ("Olive Oil", 5.0),
        ]
    ),
    (
        "Veggie Supreme Pizza (1 Slice)", "slice", 120.0, 1, 90,
        [
            ("Pizza Crust / Base", 55.0),
            ("Mozzarella Cheese", 28.0),
            ("Tomato (Ripe Raw)", 20.0),
            ("Capsicum / Green Bell Pepper (Raw)", 15.0),
            ("Onion (Raw)", 15.0),
            ("Olive Oil", 5.0),
        ]
    ),
    (
        "Chicken Kathi Roll / Frankie", "piece", 180.0, 1, 92,
        [
            ("Refined Wheat Flour (Maida)", 50.0),
            ("Chicken Breast (Skinless Raw)", 80.0),
            ("Vegetable Cooking Oil", 10.0),
            ("Onion (Raw)", 25.0),
            ("Mayonnaise", 10.0),
        ]
    ),
    (
        "Paneer Kathi Roll / Frankie", "piece", 180.0, 1, 90,
        [
            ("Refined Wheat Flour (Maida)", 50.0),
            ("Paneer (Fresh Cottage Cheese)", 70.0),
            ("Vegetable Cooking Oil", 10.0),
            ("Onion (Raw)", 25.0),
            ("Capsicum / Green Bell Pepper (Raw)", 15.0),
        ]
    ),
    (
        "Red Sauce Pasta (Arrabbiata)", "plate", 220.0, 1, 92,
        [
            ("Pasta (Durum Wheat Semolina)", 70.0),
            ("Tomato (Ripe Raw)", 70.0),
            ("Olive Oil", 10.0),
            ("Onion (Raw)", 20.0),
        ]
    ),
    (
        "White Sauce Pasta (Alfredo)", "plate", 240.0, 1, 90,
        [
            ("Pasta (Durum Wheat Semolina)", 70.0),
            ("Cow Milk (Full Cream)", 80.0),
            ("Butter (Salted)", 15.0),
            ("Cheddar / Processed Cheese", 25.0),
            ("Refined Wheat Flour (Maida)", 10.0),
        ]
    ),
    (
        "Steamed Veg Momos (6 Pieces)", "plate", 150.0, 1, 95,
        [
            ("Refined Wheat Flour (Maida)", 45.0),
            ("Onion (Raw)", 40.0),
            ("Carrot (Gajar Raw)", 30.0),
            ("Vegetable Cooking Oil", 5.0),
        ]
    ),
    (
        "Steamed Chicken Momos (6 Pieces)", "plate", 150.0, 1, 95,
        [
            ("Refined Wheat Flour (Maida)", 45.0),
            ("Chicken Breast (Skinless Raw)", 70.0),
            ("Onion (Raw)", 25.0),
            ("Vegetable Cooking Oil", 5.0),
        ]
    ),
    (
        "Chicken Shawarma Roll", "piece", 200.0, 1, 95,
        [
            ("Refined Wheat Flour (Maida)", 55.0),
            ("Chicken Breast (Skinless Raw)", 90.0),
            ("Mayonnaise", 18.0),
            ("Onion (Raw)", 20.0),
            ("Tomato (Ripe Raw)", 20.0),
        ]
    ),
    (
        "Chocolate Chip Cookie", "piece", 35.0, 1, 90,
        [
            ("Refined Wheat Flour (Maida)", 15.0),
            ("Sugar (Granulated)", 10.0),
            ("Butter (Salted)", 8.0),
            ("Dark Chocolate (70% Cocoa)", 6.0),
        ]
    ),
    (
        "Glazed Doughnut / Donut", "piece", 60.0, 1, 90,
        [
            ("Refined Wheat Flour (Maida)", 30.0),
            ("Sugar (Granulated)", 16.0),
            ("Vegetable Cooking Oil", 8.0),
            ("Butter (Salted)", 6.0),
        ]
    ),
    (
        "Chicken Pizza (1 Slice)", "slice", 110.0, 1, 92,
        [
            ("Pizza Crust / Base", 55.0),
            ("Mozzarella Cheese", 30.0),
            ("Chicken Breast (Skinless Raw)", 30.0),
            ("Tomato (Ripe Raw)", 20.0),
        ]
    ),
    (
        "Veg Hakka Noodles / Chowmein", "plate", 220.0, 1, 92,
        [
            ("Pasta (Durum Wheat Semolina)", 70.0),
            ("Vegetable Cooking Oil", 12.0),
            ("Onion (Raw)", 30.0),
            ("Capsicum / Green Bell Pepper (Raw)", 25.0),
            ("Carrot (Gajar Raw)", 25.0),
        ]
    ),
    (
        "Veg Fried Rice", "plate", 250.0, 1, 90,
        [
            ("White Rice (Raw)", 75.0),
            ("Vegetable Cooking Oil", 12.0),
            ("Onion (Raw)", 30.0),
            ("Carrot (Gajar Raw)", 25.0),
            ("Green Peas (Raw)", 20.0),
        ]
    ),
    (
        "Veg Manchurian (Dry/Gravy)", "plate", 180.0, 1, 90,
        [
            ("Refined Wheat Flour (Maida)", 30.0),
            ("Vegetable Cooking Oil", 14.0),
            ("Onion (Raw)", 40.0),
            ("Carrot (Gajar Raw)", 30.0),
            ("Capsicum / Green Bell Pepper (Raw)", 20.0),
        ]
    ),
    (
        "Chicken Nuggets (6 Pieces)", "serving", 120.0, 1, 92,
        [
            ("Chicken Breast (Skinless Raw)", 80.0),
            ("Refined Wheat Flour (Maida)", 20.0),
            ("Vegetable Cooking Oil", 14.0),
        ]
    ),
    (
        "Garlic Bread (3 Slices)", "serving", 90.0, 1, 90,
        [
            ("Bread (White)", 60.0),
            ("Butter (Salted)", 15.0),
            ("Mozzarella Cheese", 15.0),
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
    ("toor daal", "RECIPE", "Dal Tadka (Yellow Lentil Curry)"),
    ("toor", "RECIPE", "Dal Tadka (Yellow Lentil Curry)"),
    ("arhar dal", "RECIPE", "Dal Tadka (Yellow Lentil Curry)"),
    ("arhar daal", "RECIPE", "Dal Tadka (Yellow Lentil Curry)"),
    ("arhar", "RECIPE", "Dal Tadka (Yellow Lentil Curry)"),
    ("tuvar dal", "RECIPE", "Dal Tadka (Yellow Lentil Curry)"),
    ("moong dal", "RECIPE", "Moong Dal (Cooked)"),
    ("moong daal", "RECIPE", "Moong Dal (Cooked)"),
    ("mung dal", "RECIPE", "Moong Dal (Cooked)"),
    ("mung daal", "RECIPE", "Moong Dal (Cooked)"),
    ("moong", "RECIPE", "Moong Dal (Cooked)"),
    ("urad", "RECIPE", "Urad Dal (Cooked / Tadka)"),
    ("urad dal", "RECIPE", "Urad Dal (Cooked / Tadka)"),
    ("urad daal", "RECIPE", "Urad Dal (Cooked / Tadka)"),
    ("urad dal tadka", "RECIPE", "Urad Dal (Cooked / Tadka)"),
    ("urad dal fry", "RECIPE", "Urad Dal (Cooked / Tadka)"),
    ("dhuli urad dal", "RECIPE", "Urad Dal (Cooked / Tadka)"),
    ("dhuli urad", "RECIPE", "Urad Dal (Cooked / Tadka)"),
    ("kali dal", "RECIPE", "Urad Dal (Cooked / Tadka)"),
    ("kaali dal", "RECIPE", "Urad Dal (Cooked / Tadka)"),
    ("maa ki dal", "RECIPE", "Urad Dal (Cooked / Tadka)"),
    ("urad ki dal", "RECIPE", "Urad Dal (Cooked / Tadka)"),
    ("black gram dal", "RECIPE", "Urad Dal (Cooked / Tadka)"),
    ("black gram", "RECIPE", "Urad Dal (Cooked / Tadka)"),
    ("chana dal", "RECIPE", "Chana Dal (Cooked / Tadka)"),
    ("chana daal", "RECIPE", "Chana Dal (Cooked / Tadka)"),
    ("chana dal tadka", "RECIPE", "Chana Dal (Cooked / Tadka)"),
    ("chana dal fry", "RECIPE", "Chana Dal (Cooked / Tadka)"),
    ("masoor dal", "RECIPE", "Masoor Dal (Cooked / Red Lentil)"),
    ("masoor daal", "RECIPE", "Masoor Dal (Cooked / Red Lentil)"),
    ("masoor", "RECIPE", "Masoor Dal (Cooked / Red Lentil)"),
    ("red lentil dal", "RECIPE", "Masoor Dal (Cooked / Red Lentil)"),
    ("masur dal", "RECIPE", "Masoor Dal (Cooked / Red Lentil)"),
    ("raw urad dal", "INGREDIENT", "Urad Dal (Black Gram Split)"),
    ("raw urad", "INGREDIENT", "Urad Dal (Black Gram Split)"),
    ("dry urad dal", "INGREDIENT", "Urad Dal (Black Gram Split)"),
    ("dry urad", "INGREDIENT", "Urad Dal (Black Gram Split)"),
    ("uncooked urad dal", "INGREDIENT", "Urad Dal (Black Gram Split)"),
    ("uncooked urad", "INGREDIENT", "Urad Dal (Black Gram Split)"),
    ("raw black gram", "INGREDIENT", "Urad Dal (Black Gram Split)"),
    ("dry black gram", "INGREDIENT", "Urad Dal (Black Gram Split)"),
    ("raw chana dal", "INGREDIENT", "Chana Dal (Split Chickpeas)"),
    ("raw chana", "INGREDIENT", "Chana Dal (Split Chickpeas)"),
    ("dry chana dal", "INGREDIENT", "Chana Dal (Split Chickpeas)"),
    ("dry chana", "INGREDIENT", "Chana Dal (Split Chickpeas)"),
    ("uncooked chana dal", "INGREDIENT", "Chana Dal (Split Chickpeas)"),
    ("raw moong dal", "INGREDIENT", "Moong Dal (Yellow Split)"),
    ("raw moong", "INGREDIENT", "Moong Dal (Yellow Split)"),
    ("dry moong dal", "INGREDIENT", "Moong Dal (Yellow Split)"),
    ("dry moong", "INGREDIENT", "Moong Dal (Yellow Split)"),
    ("uncooked moong dal", "INGREDIENT", "Moong Dal (Yellow Split)"),
    ("raw toor dal", "INGREDIENT", "Toor Dal (Yellow Pigeon Pea)"),
    ("raw toor", "INGREDIENT", "Toor Dal (Yellow Pigeon Pea)"),
    ("dry toor dal", "INGREDIENT", "Toor Dal (Yellow Pigeon Pea)"),
    ("dry toor", "INGREDIENT", "Toor Dal (Yellow Pigeon Pea)"),
    ("raw arhar dal", "INGREDIENT", "Toor Dal (Yellow Pigeon Pea)"),
    ("raw masoor dal", "INGREDIENT", "Masoor Dal / Red Lentil (Raw)"),
    ("raw masoor", "INGREDIENT", "Masoor Dal / Red Lentil (Raw)"),
    ("dry masoor dal", "INGREDIENT", "Masoor Dal / Red Lentil (Raw)"),

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
    ("baingan", "RECIPE", "Baingan Bharta (Roasted Eggplant Mash)"),
    ("eggplant", "RECIPE", "Baingan Bharta (Roasted Eggplant Mash)"),
    ("brinjal", "RECIPE", "Baingan Bharta (Roasted Eggplant Mash)"),
    ("mixed veg", "RECIPE", "Mixed Vegetable Sabzi (Cooked)"),
    ("mix veg", "RECIPE", "Mixed Vegetable Sabzi (Cooked)"),
    ("mix vegetable", "RECIPE", "Mixed Vegetable Sabzi (Cooked)"),
    ("mixed vegetable", "RECIPE", "Mixed Vegetable Sabzi (Cooked)"),
    ("mix veg sabzi", "RECIPE", "Mixed Vegetable Sabzi (Cooked)"),
    ("sabzi", "RECIPE", "Mixed Vegetable Sabzi (Cooked)"),
    ("sabji", "RECIPE", "Mixed Vegetable Sabzi (Cooked)"),
    ("jeera aloo", "RECIPE", "Jeera Aloo (Dry Potato Sabzi)"),
    ("zeera aloo", "RECIPE", "Jeera Aloo (Dry Potato Sabzi)"),
    ("aloo matar", "RECIPE", "Aloo Matar (Curry)"),
    ("alu matar", "RECIPE", "Aloo Matar (Curry)"),
    ("aloo mutter", "RECIPE", "Aloo Matar (Curry)"),
    ("aloo shimla mirch", "RECIPE", "Aloo Shimla Mirch (Cooked Sabzi)"),
    ("shimla mirch aloo", "RECIPE", "Aloo Shimla Mirch (Cooked Sabzi)"),
    ("gobi sabzi", "RECIPE", "Gobi Ki Sabzi / Cauliflower Fry"),
    ("gobhi sabzi", "RECIPE", "Gobi Ki Sabzi / Cauliflower Fry"),
    ("gobi ki sabzi", "RECIPE", "Gobi Ki Sabzi / Cauliflower Fry"),
    ("gobi", "RECIPE", "Gobi Ki Sabzi / Cauliflower Fry"),
    ("gobhi", "RECIPE", "Gobi Ki Sabzi / Cauliflower Fry"),
    ("cauliflower", "RECIPE", "Gobi Ki Sabzi / Cauliflower Fry"),
    ("lauki", "RECIPE", "Lauki Ki Sabzi (Bottle Gourd Curry)"),
    ("lauki ki sabzi", "RECIPE", "Lauki Ki Sabzi (Bottle Gourd Curry)"),
    ("lauki sabzi", "RECIPE", "Lauki Ki Sabzi (Bottle Gourd Curry)"),
    ("ghiya", "RECIPE", "Lauki Ki Sabzi (Bottle Gourd Curry)"),
    ("doodhi", "RECIPE", "Lauki Ki Sabzi (Bottle Gourd Curry)"),
    ("bottle gourd", "RECIPE", "Lauki Ki Sabzi (Bottle Gourd Curry)"),
    ("palak", "RECIPE", "Palak Ki Sabzi / Saag (Cooked)"),
    ("palak saag", "RECIPE", "Palak Ki Sabzi / Saag (Cooked)"),
    ("palak sabzi", "RECIPE", "Palak Ki Sabzi / Saag (Cooked)"),
    ("spinach", "RECIPE", "Palak Ki Sabzi / Saag (Cooked)"),
    ("saag", "RECIPE", "Palak Ki Sabzi / Saag (Cooked)"),
    ("matar paneer", "RECIPE", "Matar Paneer (Curry)"),
    ("mutter paneer", "RECIPE", "Matar Paneer (Curry)"),
    ("patta gobi", "RECIPE", "Cabbage Sabzi / Patta Gobi"),
    ("patta gobhi", "RECIPE", "Cabbage Sabzi / Patta Gobi"),
    ("band gobi", "RECIPE", "Cabbage Sabzi / Patta Gobi"),
    ("cabbage sabzi", "RECIPE", "Cabbage Sabzi / Patta Gobi"),
    ("cabbage", "RECIPE", "Cabbage Sabzi / Patta Gobi"),
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
    ("raw baingan", "INGREDIENT", "Eggplant / Baingan (Raw)"),
    ("raw eggplant", "INGREDIENT", "Eggplant / Baingan (Raw)"),
    ("raw brinjal", "INGREDIENT", "Eggplant / Baingan (Raw)"),
    ("raw lauki", "INGREDIENT", "Bottle Gourd / Lauki (Raw)"),
    ("raw cabbage", "INGREDIENT", "Cabbage / Patta Gobi (Raw)"),
    ("raw palak", "INGREDIENT", "Spinach (Palak Raw)"),
    ("raw spinach", "INGREDIENT", "Spinach (Palak Raw)"),
    ("raw gobi", "INGREDIENT", "Cauliflower (Gobi)"),
    ("raw cauliflower", "INGREDIENT", "Cauliflower (Gobi)"),
    ("raw bhindi", "INGREDIENT", "Ladyfinger (Bhindi/Okra)"),
    ("raw okra", "INGREDIENT", "Ladyfinger (Bhindi/Okra)"),
    ("capsicum", "INGREDIENT", "Capsicum / Green Bell Pepper (Raw)"),
    ("shimla mirch", "INGREDIENT", "Capsicum / Green Bell Pepper (Raw)"),
    ("sabudana", "INGREDIENT", "Sago / Sabudana (Dry)"),
    ("sago", "INGREDIENT", "Sago / Sabudana (Dry)"),
    ("sev", "INGREDIENT", "Sev / Fried Gram Flour Noodles"),
    ("bhujia", "INGREDIENT", "Sev / Fried Gram Flour Noodles"),
    ("methi", "INGREDIENT", "Fenugreek Leaves (Methi Raw)"),

    # Beverages & Drinks
    ("tea", "RECIPE", "Masala Chai / Indian Milk Tea"),
    ("chai", "RECIPE", "Masala Chai / Indian Milk Tea"),
    ("milk tea", "RECIPE", "Masala Chai / Indian Milk Tea"),
    ("masala chai", "RECIPE", "Masala Chai / Indian Milk Tea"),
    ("masala tea", "RECIPE", "Masala Chai / Indian Milk Tea"),
    ("adrak chai", "RECIPE", "Masala Chai / Indian Milk Tea"),
    ("ginger tea", "RECIPE", "Masala Chai / Indian Milk Tea"),
    ("cutting chai", "RECIPE", "Masala Chai / Indian Milk Tea"),
    ("cup of tea", "RECIPE", "Masala Chai / Indian Milk Tea"),
    ("cup of chai", "RECIPE", "Masala Chai / Indian Milk Tea"),

    ("black coffee", "RECIPE", "Black Coffee (Espresso / Americano)"),
    ("espresso", "RECIPE", "Black Coffee (Espresso / Americano)"),
    ("americano", "RECIPE", "Black Coffee (Espresso / Americano)"),
    ("black coffee without sugar", "RECIPE", "Black Coffee (Espresso / Americano)"),

    ("green tea", "RECIPE", "Green Tea / Black Tea (Unsweetened)"),
    ("black tea", "RECIPE", "Green Tea / Black Tea (Unsweetened)"),
    ("herbal tea", "RECIPE", "Green Tea / Black Tea (Unsweetened)"),

    ("cold coffee", "RECIPE", "Cold Coffee (Iced Blended)"),
    ("iced coffee", "RECIPE", "Cold Coffee (Iced Blended)"),
    ("frappe", "RECIPE", "Cold Coffee (Iced Blended)"),

    ("cappuccino", "RECIPE", "Cappuccino / Cafe Latte"),
    ("latte", "RECIPE", "Cappuccino / Cafe Latte"),
    ("cafe latte", "RECIPE", "Cappuccino / Cafe Latte"),
    ("flat white", "RECIPE", "Cappuccino / Cafe Latte"),
    ("coffee with milk", "RECIPE", "Cappuccino / Cafe Latte"),

    ("iced tea", "RECIPE", "Lemon Iced Tea"),
    ("lemon iced tea", "RECIPE", "Lemon Iced Tea"),
    ("peach iced tea", "RECIPE", "Lemon Iced Tea"),

    ("lassi", "RECIPE", "Sweet Lassi"),
    ("sweet lassi", "RECIPE", "Sweet Lassi"),
    ("punjabi lassi", "RECIPE", "Sweet Lassi"),

    ("chaas", "RECIPE", "Chaas / Salted Buttermilk"),
    ("buttermilk", "RECIPE", "Chaas / Salted Buttermilk"),
    ("mattha", "RECIPE", "Chaas / Salted Buttermilk"),
    ("masala chaas", "RECIPE", "Chaas / Salted Buttermilk"),

    ("coconut water", "RECIPE", "Tender Coconut Water (Fresh)"),
    ("nariyal pani", "RECIPE", "Tender Coconut Water (Fresh)"),
    ("tender coconut water", "RECIPE", "Tender Coconut Water (Fresh)"),
    ("daab", "RECIPE", "Tender Coconut Water (Fresh)"),

    ("orange juice", "RECIPE", "Fresh Orange Juice (Glass)"),
    ("fresh orange juice", "RECIPE", "Fresh Orange Juice (Glass)"),
    ("mosambi juice", "RECIPE", "Fresh Orange Juice (Glass)"),
    ("sweet lime juice", "RECIPE", "Fresh Orange Juice (Glass)"),
    ("juice", "RECIPE", "Fresh Orange Juice (Glass)"),

    ("sugarcane juice", "RECIPE", "Fresh Sugarcane Juice"),
    ("ganna juice", "RECIPE", "Fresh Sugarcane Juice"),
    ("ganne ka ras", "RECIPE", "Fresh Sugarcane Juice"),

    ("cola", "RECIPE", "Cola / Carbonated Soft Drink (Can)"),
    ("coke", "RECIPE", "Cola / Carbonated Soft Drink (Can)"),
    ("coca cola", "RECIPE", "Cola / Carbonated Soft Drink (Can)"),
    ("pepsi", "RECIPE", "Cola / Carbonated Soft Drink (Can)"),
    ("thums up", "RECIPE", "Cola / Carbonated Soft Drink (Can)"),
    ("thumbs up", "RECIPE", "Cola / Carbonated Soft Drink (Can)"),
    ("sprite", "RECIPE", "Cola / Carbonated Soft Drink (Can)"),
    ("fanta", "RECIPE", "Cola / Carbonated Soft Drink (Can)"),
    ("soda", "RECIPE", "Cola / Carbonated Soft Drink (Can)"),
    ("soft drink", "RECIPE", "Cola / Carbonated Soft Drink (Can)"),

    ("diet coke", "RECIPE", "Diet Coke / Coke Zero (Can)"),
    ("coke zero", "RECIPE", "Diet Coke / Coke Zero (Can)"),
    ("diet pepsi", "RECIPE", "Diet Coke / Coke Zero (Can)"),
    ("pepsi black", "RECIPE", "Diet Coke / Coke Zero (Can)"),
    ("zero coke", "RECIPE", "Diet Coke / Coke Zero (Can)"),

    ("red bull", "RECIPE", "Energy Drink (Red Bull Style)"),
    ("energy drink", "RECIPE", "Energy Drink (Red Bull Style)"),
    ("monster", "RECIPE", "Energy Drink (Red Bull Style)"),
    ("sting", "RECIPE", "Energy Drink (Red Bull Style)"),

    # Sandwiches
    ("dark chocolate sandwich", "RECIPE", "Dark Chocolate Sandwich"),
    ("dark chocolate sandwiches", "RECIPE", "Dark Chocolate Sandwich"),
    ("chocolate sandwich", "RECIPE", "Dark Chocolate Sandwich"),
    ("chocolate sandwiches", "RECIPE", "Dark Chocolate Sandwich"),
    ("choco sandwich", "RECIPE", "Dark Chocolate Sandwich"),
    ("nutella sandwich", "RECIPE", "Dark Chocolate Sandwich"),

    ("sandwich", "RECIPE", "Veg Grilled Sandwich (Bombay Style)"),
    ("sandwiches", "RECIPE", "Veg Grilled Sandwich (Bombay Style)"),
    ("veg sandwich", "RECIPE", "Veg Grilled Sandwich (Bombay Style)"),
    ("veg sandwiches", "RECIPE", "Veg Grilled Sandwich (Bombay Style)"),
    ("vegetable sandwich", "RECIPE", "Veg Grilled Sandwich (Bombay Style)"),
    ("bombay sandwich", "RECIPE", "Veg Grilled Sandwich (Bombay Style)"),
    ("grilled veg sandwich", "RECIPE", "Veg Grilled Sandwich (Bombay Style)"),
    ("veg grilled sandwich", "RECIPE", "Veg Grilled Sandwich (Bombay Style)"),

    ("cheese sandwich", "RECIPE", "Cheese Grilled Sandwich"),
    ("cheese sandwiches", "RECIPE", "Cheese Grilled Sandwich"),
    ("cheese grilled sandwich", "RECIPE", "Cheese Grilled Sandwich"),
    ("grilled cheese", "RECIPE", "Cheese Grilled Sandwich"),
    ("grilled cheese sandwich", "RECIPE", "Cheese Grilled Sandwich"),

    ("chicken sandwich", "RECIPE", "Chicken Club Sandwich"),
    ("chicken sandwiches", "RECIPE", "Chicken Club Sandwich"),
    ("chicken club sandwich", "RECIPE", "Chicken Club Sandwich"),
    ("club sandwich", "RECIPE", "Chicken Club Sandwich"),

    ("egg sandwich", "RECIPE", "Egg / Omelette Sandwich"),
    ("egg sandwiches", "RECIPE", "Egg / Omelette Sandwich"),
    ("omelette sandwich", "RECIPE", "Egg / Omelette Sandwich"),
    ("omlet sandwich", "RECIPE", "Egg / Omelette Sandwich"),
    ("anda sandwich", "RECIPE", "Egg / Omelette Sandwich"),

    ("peanut butter sandwich", "RECIPE", "Peanut Butter Sandwich"),
    ("peanut butter sandwiches", "RECIPE", "Peanut Butter Sandwich"),
    ("pb sandwich", "RECIPE", "Peanut Butter Sandwich"),
    ("pb&j sandwich", "RECIPE", "Peanut Butter Sandwich"),
    ("pbj sandwich", "RECIPE", "Peanut Butter Sandwich"),

    # Fast Food & Street Food
    ("burger", "RECIPE", "Veg Burger / Aloo Tikki Burger"),
    ("burgers", "RECIPE", "Veg Burger / Aloo Tikki Burger"),
    ("veg burger", "RECIPE", "Veg Burger / Aloo Tikki Burger"),
    ("veg burgers", "RECIPE", "Veg Burger / Aloo Tikki Burger"),
    ("aloo tikki burger", "RECIPE", "Veg Burger / Aloo Tikki Burger"),
    ("veggie burger", "RECIPE", "Veg Burger / Aloo Tikki Burger"),

    ("chicken burger", "RECIPE", "Chicken Burger (Crispy)"),
    ("chicken burgers", "RECIPE", "Chicken Burger (Crispy)"),
    ("mcchicken", "RECIPE", "Chicken Burger (Crispy)"),
    ("crispy chicken burger", "RECIPE", "Chicken Burger (Crispy)"),
    ("zinger burger", "RECIPE", "Chicken Burger (Crispy)"),

    ("cheeseburger", "RECIPE", "Cheeseburger"),
    ("cheeseburgers", "RECIPE", "Cheeseburger"),
    ("cheese burger", "RECIPE", "Cheeseburger"),

    ("fries", "RECIPE", "French Fries (Medium)"),
    ("french fries", "RECIPE", "French Fries (Medium)"),
    ("french fry", "RECIPE", "French Fries (Medium)"),
    ("finger chips", "RECIPE", "French Fries (Medium)"),
    ("chips", "RECIPE", "French Fries (Medium)"),

    ("pizza", "RECIPE", "Margherita Pizza (1 Slice)"),
    ("pizza slice", "RECIPE", "Margherita Pizza (1 Slice)"),
    ("margherita", "RECIPE", "Margherita Pizza (1 Slice)"),
    ("margherita pizza", "RECIPE", "Margherita Pizza (1 Slice)"),
    ("cheese pizza", "RECIPE", "Margherita Pizza (1 Slice)"),

    ("veg pizza", "RECIPE", "Veggie Supreme Pizza (1 Slice)"),
    ("veggie pizza", "RECIPE", "Veggie Supreme Pizza (1 Slice)"),
    ("veggie supreme pizza", "RECIPE", "Veggie Supreme Pizza (1 Slice)"),
    ("farmhouse pizza", "RECIPE", "Veggie Supreme Pizza (1 Slice)"),

    ("chicken pizza", "RECIPE", "Chicken Pizza (1 Slice)"),
    ("pepperoni pizza", "RECIPE", "Chicken Pizza (1 Slice)"),

    ("chicken roll", "RECIPE", "Chicken Kathi Roll / Frankie"),
    ("chicken kathi roll", "RECIPE", "Chicken Kathi Roll / Frankie"),
    ("chicken frankie", "RECIPE", "Chicken Kathi Roll / Frankie"),

    ("paneer roll", "RECIPE", "Paneer Kathi Roll / Frankie"),
    ("paneer kathi roll", "RECIPE", "Paneer Kathi Roll / Frankie"),
    ("paneer frankie", "RECIPE", "Paneer Kathi Roll / Frankie"),
    ("veg roll", "RECIPE", "Paneer Kathi Roll / Frankie"),
    ("kathi roll", "RECIPE", "Paneer Kathi Roll / Frankie"),
    ("frankie", "RECIPE", "Paneer Kathi Roll / Frankie"),

    ("pasta", "RECIPE", "Red Sauce Pasta (Arrabbiata)"),
    ("red sauce pasta", "RECIPE", "Red Sauce Pasta (Arrabbiata)"),
    ("arrabbiata", "RECIPE", "Red Sauce Pasta (Arrabbiata)"),
    ("arrabbiata pasta", "RECIPE", "Red Sauce Pasta (Arrabbiata)"),
    ("penne arrabbiata", "RECIPE", "Red Sauce Pasta (Arrabbiata)"),
    ("tomato pasta", "RECIPE", "Red Sauce Pasta (Arrabbiata)"),

    ("white sauce pasta", "RECIPE", "White Sauce Pasta (Alfredo)"),
    ("alfredo pasta", "RECIPE", "White Sauce Pasta (Alfredo)"),
    ("alfredo", "RECIPE", "White Sauce Pasta (Alfredo)"),
    ("cheese pasta", "RECIPE", "White Sauce Pasta (Alfredo)"),

    ("momos", "RECIPE", "Steamed Veg Momos (6 Pieces)"),
    ("momo", "RECIPE", "Steamed Veg Momos (6 Pieces)"),
    ("veg momos", "RECIPE", "Steamed Veg Momos (6 Pieces)"),
    ("veg momo", "RECIPE", "Steamed Veg Momos (6 Pieces)"),
    ("steamed momos", "RECIPE", "Steamed Veg Momos (6 Pieces)"),
    ("dim sum", "RECIPE", "Steamed Veg Momos (6 Pieces)"),
    ("dumplings", "RECIPE", "Steamed Veg Momos (6 Pieces)"),

    ("chicken momos", "RECIPE", "Steamed Chicken Momos (6 Pieces)"),
    ("chicken momo", "RECIPE", "Steamed Chicken Momos (6 Pieces)"),
    ("steamed chicken momos", "RECIPE", "Steamed Chicken Momos (6 Pieces)"),

    ("shawarma", "RECIPE", "Chicken Shawarma Roll"),
    ("chicken shawarma", "RECIPE", "Chicken Shawarma Roll"),
    ("shawarma roll", "RECIPE", "Chicken Shawarma Roll"),

    ("noodles", "RECIPE", "Veg Hakka Noodles / Chowmein"),
    ("hakka noodles", "RECIPE", "Veg Hakka Noodles / Chowmein"),
    ("chowmein", "RECIPE", "Veg Hakka Noodles / Chowmein"),
    ("veg noodles", "RECIPE", "Veg Hakka Noodles / Chowmein"),
    ("veg chowmein", "RECIPE", "Veg Hakka Noodles / Chowmein"),

    ("fried rice", "RECIPE", "Veg Fried Rice"),
    ("veg fried rice", "RECIPE", "Veg Fried Rice"),

    ("manchurian", "RECIPE", "Veg Manchurian (Dry/Gravy)"),
    ("veg manchurian", "RECIPE", "Veg Manchurian (Dry/Gravy)"),
    ("gobi manchurian", "RECIPE", "Veg Manchurian (Dry/Gravy)"),

    ("nuggets", "RECIPE", "Chicken Nuggets (6 Pieces)"),
    ("chicken nuggets", "RECIPE", "Chicken Nuggets (6 Pieces)"),

    ("garlic bread", "RECIPE", "Garlic Bread (3 Slices)"),
    ("cheese garlic bread", "RECIPE", "Garlic Bread (3 Slices)"),

    ("cookie", "RECIPE", "Chocolate Chip Cookie"),
    ("cookies", "RECIPE", "Chocolate Chip Cookie"),
    ("chocolate cookie", "RECIPE", "Chocolate Chip Cookie"),
    ("chocochip cookie", "RECIPE", "Chocolate Chip Cookie"),
    ("biscuit", "RECIPE", "Chocolate Chip Cookie"),
    ("biscuits", "RECIPE", "Chocolate Chip Cookie"),

    ("donut", "RECIPE", "Glazed Doughnut / Donut"),
    ("donuts", "RECIPE", "Glazed Doughnut / Donut"),
    ("doughnut", "RECIPE", "Glazed Doughnut / Donut"),
    ("doughnuts", "RECIPE", "Glazed Doughnut / Donut"),

    # Fast food base ingredients aliases
    ("dark chocolate", "INGREDIENT", "Dark Chocolate (70% Cocoa)"),
    ("chocolate", "INGREDIENT", "Milk Chocolate"),
    ("milk chocolate", "INGREDIENT", "Milk Chocolate"),
    ("cocoa powder", "INGREDIENT", "Cocoa Powder (Unsweetened)"),
    ("cheese", "INGREDIENT", "Cheddar / Processed Cheese"),
    ("cheddar", "INGREDIENT", "Cheddar / Processed Cheese"),
    ("cheddar cheese", "INGREDIENT", "Cheddar / Processed Cheese"),
    ("mozzarella", "INGREDIENT", "Mozzarella Cheese"),
    ("mozzarella cheese", "INGREDIENT", "Mozzarella Cheese"),
    ("mayo", "INGREDIENT", "Mayonnaise"),
    ("mayonnaise", "INGREDIENT", "Mayonnaise"),
    ("bun", "INGREDIENT", "Burger Bun"),
    ("burger bun", "INGREDIENT", "Burger Bun"),
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
    ("can", 330.0),
    ("bottle", 500.0),
    ("sandwich", 150.0),
    ("burger", 180.0),
    ("roll", 180.0),
    ("serving", 120.0),
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
