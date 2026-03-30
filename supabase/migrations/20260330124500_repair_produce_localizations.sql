-- Repair migration: populate missing produce localizations in unified ingredient catalog.
-- Keeps Phase A migration immutable and repairs already-applied remote state.

create temp table _repair_produce_seed(payload jsonb) on commit drop;
insert into _repair_produce_seed(payload)
values (
$produce_json$
[
  {
    "id": "apple",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Apple",
      "it": "Mela"
    },
    "imageName": "apple",
    "nutrition": {
      "calories": 52,
      "protein": 0.26,
      "carbs": 13.81,
      "fat": 0.17,
      "fiber": 2.4,
      "vitaminC": 4.6,
      "potassium": 107.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Apples, raw, with skin",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 182.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "pear",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      8,
      9,
      10,
      11
    ],
    "localizedNames": {
      "en": "Pear",
      "it": "Pera"
    },
    "imageName": "pear",
    "nutrition": {
      "calories": 57,
      "protein": 0.36,
      "carbs": 15.23,
      "fat": 0.14,
      "fiber": 3.1,
      "vitaminC": 4.3,
      "potassium": 116.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Pears, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 178.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "banana",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Banana",
      "it": "Banana"
    },
    "imageName": "banana",
    "nutrition": {
      "calories": 89,
      "protein": 1.09,
      "carbs": 22.84,
      "fat": 0.33,
      "fiber": 2.6,
      "vitaminC": 8.7,
      "potassium": 358.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Bananas, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 118.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "orange",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      11,
      12,
      1,
      2,
      3,
      4
    ],
    "localizedNames": {
      "en": "Orange",
      "it": "Arancia"
    },
    "imageName": "orange",
    "nutrition": {
      "calories": 47,
      "protein": 0.94,
      "carbs": 11.75,
      "fat": 0.12,
      "fiber": 2.4,
      "vitaminC": 53.2,
      "potassium": 181.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Oranges, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 140.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "lemon",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Lemon",
      "it": "Limone"
    },
    "imageName": "lemon",
    "nutrition": {
      "calories": 29,
      "protein": 1.1,
      "carbs": 9.32,
      "fat": 0.3,
      "fiber": 2.8,
      "vitaminC": 53.0,
      "potassium": 138.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Lemons, raw, without peel",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 84.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "kiwi",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      11,
      12,
      1,
      2,
      3,
      4
    ],
    "localizedNames": {
      "en": "Kiwi",
      "it": "Kiwi"
    },
    "imageName": "kiwi",
    "nutrition": {
      "calories": 61,
      "protein": 1.14,
      "carbs": 14.66,
      "fat": 0.52,
      "fiber": 3.0,
      "vitaminC": 92.7,
      "potassium": 312.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Kiwifruit, green, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 76.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "grape",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      8,
      9,
      10
    ],
    "localizedNames": {
      "en": "Grape",
      "it": "Uva"
    },
    "imageName": "grapes",
    "nutrition": {
      "calories": 69,
      "protein": 0.72,
      "carbs": 18.1,
      "fat": 0.16,
      "fiber": 0.9,
      "vitaminC": 3.2,
      "potassium": 191.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Grapes, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 5.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "peach",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Peach",
      "it": "Pesca"
    },
    "imageName": "peach",
    "nutrition": {
      "calories": 39,
      "protein": 0.91,
      "carbs": 9.54,
      "fat": 0.25,
      "fiber": 1.5,
      "vitaminC": 6.6,
      "potassium": 190.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Peaches, yellow, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 150.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "apricot",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      5,
      6,
      7
    ],
    "localizedNames": {
      "en": "Apricot",
      "it": "Albicocca"
    },
    "imageName": "apricot",
    "nutrition": {
      "calories": 48,
      "protein": 1.4,
      "carbs": 11.12,
      "fat": 0.39,
      "fiber": 2.0,
      "vitaminC": 10.0,
      "potassium": 259.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Apricots, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 35.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "cherry",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      5,
      6,
      7
    ],
    "localizedNames": {
      "en": "Cherry",
      "it": "Ciliegia"
    },
    "imageName": "cherry",
    "nutrition": {
      "calories": 63,
      "protein": 1.06,
      "carbs": 16.01,
      "fat": 0.2,
      "fiber": 2.1,
      "vitaminC": 7.0,
      "potassium": 222.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Cherries, sweet, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 8.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "strawberry",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      4,
      5,
      6
    ],
    "localizedNames": {
      "en": "Strawberry",
      "it": "Fragola"
    },
    "imageName": "strawberry",
    "nutrition": {
      "calories": 32,
      "protein": 0.67,
      "carbs": 7.68,
      "fat": 0.3,
      "fiber": 2.0,
      "vitaminC": 58.8,
      "potassium": 153.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Strawberries, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 12.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "blueberry",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8
    ],
    "localizedNames": {
      "en": "Blueberry",
      "it": "Mirtillo"
    },
    "imageName": "blueberry",
    "nutrition": {
      "calories": 57,
      "protein": 0.74,
      "carbs": 14.49,
      "fat": 0.33,
      "fiber": 2.4,
      "vitaminC": 9.7,
      "potassium": 77.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Blueberries, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 2.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "tomato",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Tomato",
      "it": "Pomodoro"
    },
    "imageName": "tomato",
    "nutrition": {
      "calories": 18,
      "protein": 0.88,
      "carbs": 3.89,
      "fat": 0.2,
      "fiber": 1.2,
      "vitaminC": 13.7,
      "potassium": 237.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Tomatoes, red, ripe, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 123.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "zucchini",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      5,
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Zucchini",
      "it": "Zucchina"
    },
    "imageName": "zucchini",
    "nutrition": {
      "calories": 17,
      "protein": 1.21,
      "carbs": 3.11,
      "fat": 0.32,
      "fiber": 1.0,
      "vitaminC": 17.9,
      "potassium": 261.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Squash, summer, zucchini, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 196.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "eggplant",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Eggplant",
      "it": "Melanzana"
    },
    "imageName": "eggplant",
    "nutrition": {
      "calories": 25,
      "protein": 0.98,
      "carbs": 5.88,
      "fat": 0.18,
      "fiber": 3.0,
      "vitaminC": 2.2,
      "potassium": 229.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Eggplant, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 458.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "cucumber",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      5,
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Cucumber",
      "it": "Cetriolo"
    },
    "imageName": "cucumber",
    "nutrition": {
      "calories": 15,
      "protein": 0.65,
      "carbs": 3.63,
      "fat": 0.11,
      "fiber": 0.5,
      "vitaminC": 2.8,
      "potassium": 147.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Cucumber, with peel, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 201.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "bell_pepper",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9,
      10
    ],
    "localizedNames": {
      "en": "Bell pepper",
      "it": "Peperone"
    },
    "imageName": "bell_pepper",
    "nutrition": {
      "calories": 31,
      "protein": 1.0,
      "carbs": 6.03,
      "fat": 0.3,
      "fiber": 2.1,
      "vitaminC": 127.7,
      "potassium": 211.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Peppers, sweet, red, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 119.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "spinach",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      2,
      3,
      4,
      5,
      9,
      10,
      11
    ],
    "localizedNames": {
      "en": "Spinach",
      "it": "Spinaci"
    },
    "imageName": "spinach",
    "nutrition": {
      "calories": 23,
      "protein": 2.86,
      "carbs": 3.63,
      "fat": 0.39,
      "fiber": 2.2,
      "vitaminC": 28.1,
      "potassium": 558.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Spinach, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 30.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "lettuce",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10
    ],
    "localizedNames": {
      "en": "Lettuce",
      "it": "Lattuga"
    },
    "imageName": "lettuce",
    "nutrition": {
      "calories": 15,
      "protein": 1.36,
      "carbs": 2.87,
      "fat": 0.15,
      "fiber": 1.3,
      "vitaminC": 9.2,
      "potassium": 194.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Lettuce, green leaf, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 40.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "rocket",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11
    ],
    "localizedNames": {
      "en": "Rocket",
      "it": "Rucola"
    },
    "imageName": "arugula",
    "nutrition": {
      "calories": 25,
      "protein": 2.58,
      "carbs": 3.65,
      "fat": 0.66,
      "fiber": 1.6,
      "vitaminC": 15.0,
      "potassium": 369.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Arugula, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 30.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "carrot",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      1,
      2,
      3,
      4,
      5,
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Carrot",
      "it": "Carota"
    },
    "imageName": "carrot",
    "nutrition": {
      "calories": 41,
      "protein": 0.93,
      "carbs": 9.58,
      "fat": 0.24,
      "fiber": 2.8,
      "vitaminC": 5.9,
      "potassium": 320.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Carrots, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 61.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "onion",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Onion",
      "it": "Cipolla"
    },
    "imageName": "onion",
    "nutrition": {
      "calories": 40,
      "protein": 1.1,
      "carbs": 9.34,
      "fat": 0.1,
      "fiber": 1.7,
      "vitaminC": 7.4,
      "potassium": 146.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Onions, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 110.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "garlic",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9,
      10,
      11
    ],
    "localizedNames": {
      "en": "Garlic",
      "it": "Aglio"
    },
    "imageName": "garlic",
    "nutrition": {
      "calories": 149,
      "protein": 6.36,
      "carbs": 33.06,
      "fat": 0.5,
      "fiber": 2.1,
      "vitaminC": 31.2,
      "potassium": 401.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Garlic, raw",
    "defaultUnit": "clove",
    "supportedUnits": [
      "clove",
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "clove": 3.0,
      "g": 1.0,
      "piece": 3.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "celery",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      9,
      10,
      11,
      12,
      1,
      2,
      3
    ],
    "localizedNames": {
      "en": "Celery",
      "it": "Sedano"
    },
    "imageName": "celery",
    "nutrition": {
      "calories": 14,
      "protein": 0.69,
      "carbs": 2.97,
      "fat": 0.17,
      "fiber": 1.6,
      "vitaminC": 3.1,
      "potassium": 260.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Celery, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 40.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "broccoli",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      10,
      11,
      12,
      1,
      2,
      3
    ],
    "localizedNames": {
      "en": "Broccoli",
      "it": "Broccoli"
    },
    "imageName": "broccoli",
    "nutrition": {
      "calories": 34,
      "protein": 2.82,
      "carbs": 6.64,
      "fat": 0.37,
      "fiber": 2.6,
      "vitaminC": 89.2,
      "potassium": 316.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Broccoli, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 150.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "cauliflower",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      10,
      11,
      12,
      1,
      2,
      3
    ],
    "localizedNames": {
      "en": "Cauliflower",
      "it": "Cavolfiore"
    },
    "imageName": "cauliflower",
    "nutrition": {
      "calories": 25,
      "protein": 1.92,
      "carbs": 4.97,
      "fat": 0.28,
      "fiber": 2.0,
      "vitaminC": 48.2,
      "potassium": 299.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Cauliflower, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 575.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "cabbage",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      10,
      11,
      12,
      1,
      2,
      3
    ],
    "localizedNames": {
      "en": "Cabbage",
      "it": "Cavolo"
    },
    "imageName": "cabbage",
    "nutrition": {
      "calories": 25,
      "protein": 1.28,
      "carbs": 5.8,
      "fat": 0.1,
      "fiber": 2.5,
      "vitaminC": 36.6,
      "potassium": 170.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Cabbage, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 900.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "leek",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      10,
      11,
      12,
      1,
      2,
      3
    ],
    "localizedNames": {
      "en": "Leek",
      "it": "Porro"
    },
    "imageName": "leek",
    "nutrition": {
      "calories": 61,
      "protein": 1.5,
      "carbs": 14.15,
      "fat": 0.3,
      "fiber": 1.8,
      "vitaminC": 12.0,
      "potassium": 180.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Leeks, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 89.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "fennel",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      10,
      11,
      12,
      1,
      2,
      3,
      4
    ],
    "localizedNames": {
      "en": "Fennel",
      "it": "Finocchio"
    },
    "nutrition": {
      "calories": 31,
      "protein": 1.24,
      "carbs": 7.3,
      "fat": 0.2,
      "fiber": 3.1,
      "vitaminC": 12.0,
      "potassium": 414.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Fennel, bulb, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 234.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "pumpkin",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Pumpkin",
      "it": "Zucca"
    },
    "imageName": "pumpkin",
    "nutrition": {
      "calories": 26,
      "protein": 1.0,
      "carbs": 6.5,
      "fat": 0.1,
      "fiber": 0.5,
      "vitaminC": 9.0,
      "potassium": 340.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Pumpkin, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 1000.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "asparagus",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      3,
      4,
      5,
      6
    ],
    "localizedNames": {
      "en": "Asparagus",
      "it": "Asparagi"
    },
    "nutrition": {
      "calories": 20,
      "protein": 2.2,
      "carbs": 3.88,
      "fat": 0.12,
      "fiber": 2.1,
      "vitaminC": 5.6,
      "potassium": 202.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Asparagus, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 12.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "artichoke",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      11,
      12,
      1,
      2,
      3,
      4,
      5
    ],
    "localizedNames": {
      "en": "Artichoke",
      "it": "Carciofo"
    },
    "imageName": "artichoke",
    "nutrition": {
      "calories": 47,
      "protein": 3.27,
      "carbs": 10.51,
      "fat": 0.15,
      "fiber": 5.4,
      "vitaminC": 11.7,
      "potassium": 370.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Artichokes, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 128.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "mushroom",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      9,
      10,
      11
    ],
    "localizedNames": {
      "en": "Mushroom",
      "it": "Fungo"
    },
    "imageName": "mushroom",
    "nutrition": {
      "calories": 22,
      "protein": 3.09,
      "carbs": 3.26,
      "fat": 0.34,
      "fiber": 1.0,
      "vitaminC": 2.1,
      "potassium": 318.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Mushrooms, white, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 18.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "potato",
    "category": "tuber",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Potato",
      "it": "Patata"
    },
    "imageName": "potato",
    "nutrition": {
      "calories": 77,
      "protein": 2.05,
      "carbs": 17.58,
      "fat": 0.09,
      "fiber": 2.1,
      "vitaminC": 19.7,
      "potassium": 425.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Potatoes, flesh and skin, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 173.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "sweet_potato",
    "category": "tuber",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      9,
      10,
      11,
      12,
      1,
      2
    ],
    "localizedNames": {
      "en": "Sweet potato",
      "it": "Patata dolce"
    },
    "imageName": "sweet_potato",
    "nutrition": {
      "calories": 86,
      "protein": 1.57,
      "carbs": 20.12,
      "fat": 0.05,
      "fiber": 3.0,
      "vitaminC": 2.4,
      "potassium": 337.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Sweet potato, raw, unprepared",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 130.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "green_beans",
    "category": "legume",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Green beans",
      "it": "Fagiolini"
    },
    "nutrition": {
      "calories": 31,
      "protein": 1.83,
      "carbs": 6.97,
      "fat": 0.22,
      "fiber": 2.7,
      "vitaminC": 12.2,
      "potassium": 209.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Beans, snap, green, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 5.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "peas",
    "category": "legume",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      4,
      5,
      6
    ],
    "localizedNames": {
      "en": "Peas",
      "it": "Piselli"
    },
    "imageName": "peas",
    "nutrition": {
      "calories": 81,
      "protein": 5.42,
      "carbs": 14.45,
      "fat": 0.4,
      "fiber": 5.1,
      "vitaminC": 40.0,
      "potassium": 244.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Peas, green, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 0.4
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "chickpeas",
    "category": "legume",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Chickpeas",
      "it": "Ceci"
    },
    "nutrition": {
      "calories": 164,
      "protein": 8.86,
      "carbs": 27.42,
      "fat": 2.59,
      "fiber": 7.6,
      "vitaminC": 1.3,
      "potassium": 291.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Chickpeas (garbanzo beans), mature seeds, cooked, boiled",
    "nutritionMappingNote": "Mapped to cooked chickpeas for everyday use; dry values differ significantly.",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "tbsp": 10.0
    },
    "nutritionMappingConfidence": "approximate"
  },
  {
    "id": "lentils",
    "category": "legume",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Lentils",
      "it": "Lenticchie"
    },
    "nutrition": {
      "calories": 116,
      "protein": 9.02,
      "carbs": 20.13,
      "fat": 0.38,
      "fiber": 7.9,
      "vitaminC": 1.5,
      "potassium": 369.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Lentils, mature seeds, cooked, boiled",
    "nutritionMappingNote": "Mapped to cooked lentils for practicality; dry values are higher.",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "tbsp": 12.0
    },
    "nutritionMappingConfidence": "approximate"
  },
  {
    "id": "beans",
    "category": "legume",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Beans",
      "it": "Fagioli"
    },
    "nutrition": {
      "calories": 127,
      "protein": 8.67,
      "carbs": 22.8,
      "fat": 0.54,
      "fiber": 6.4,
      "vitaminC": 0.0,
      "potassium": 405.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Beans, kidney, all types, mature seeds, cooked, boiled",
    "nutritionMappingNote": "Generic bean entry mapped to cooked kidney bean profile.",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "tbsp": 12.0
    },
    "nutritionMappingConfidence": "approximate"
  },
  {
    "id": "basil",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      5,
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Basil",
      "it": "Basilico"
    },
    "nutrition": {
      "calories": 23,
      "protein": 3.15,
      "carbs": 2.65,
      "fat": 0.64,
      "fiber": 1.6,
      "vitaminC": 18.0,
      "potassium": 295.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Basil, fresh",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "tbsp",
      "tsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "tbsp": 2.5,
      "tsp": 0.8
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "parsley",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Parsley",
      "it": "Prezzemolo"
    },
    "nutrition": {
      "calories": 36,
      "protein": 2.97,
      "carbs": 6.33,
      "fat": 0.79,
      "fiber": 3.3,
      "vitaminC": 133.0,
      "potassium": 554.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Parsley, fresh",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "tbsp",
      "tsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "tbsp": 3.8,
      "tsp": 1.2
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "rosemary",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Rosemary",
      "it": "Rosmarino"
    },
    "nutrition": {
      "calories": 131,
      "protein": 3.31,
      "carbs": 20.7,
      "fat": 5.86,
      "fiber": 14.1,
      "vitaminC": 21.8,
      "potassium": 668.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Rosemary, dried",
    "nutritionMappingNote": "Fresh rosemary is more common in recipes; mapped using dried rosemary profile as conservative fallback.",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "tsp",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "tsp": 1.0,
      "tbsp": 3.0
    },
    "nutritionMappingConfidence": "approximate"
  },
  {
    "id": "thyme",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Thyme",
      "it": "Timo"
    },
    "nutrition": {
      "calories": 101,
      "protein": 5.56,
      "carbs": 24.45,
      "fat": 1.68,
      "fiber": 14.0,
      "vitaminC": 160.1,
      "potassium": 609.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Thyme, dried",
    "nutritionMappingNote": "Fresh thyme is common in home cooking; mapped to dried thyme USDA entry due clearer reference.",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "tsp",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "tsp": 1.0,
      "tbsp": 3.0
    },
    "nutritionMappingConfidence": "approximate"
  },
  {
    "id": "mandarin",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      11,
      12,
      1,
      2
    ],
    "localizedNames": {
      "en": "Mandarin",
      "it": "Mandarino"
    },
    "nutrition": {
      "calories": 53,
      "protein": 0.81,
      "carbs": 13.34,
      "fat": 0.31,
      "fiber": 1.8,
      "vitaminC": 26.7,
      "potassium": 166.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Tangerines, (mandarin oranges), raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 88.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "grapefruit",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      11,
      12,
      1,
      2,
      3
    ],
    "localizedNames": {
      "en": "Grapefruit",
      "it": "Pompelmo"
    },
    "nutrition": {
      "calories": 42,
      "protein": 0.77,
      "carbs": 10.66,
      "fat": 0.14,
      "fiber": 1.6,
      "vitaminC": 31.2,
      "potassium": 135.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Grapefruit, raw, pink and red, all areas",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 246.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "lime",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      5,
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Lime",
      "it": "Lime"
    },
    "nutrition": {
      "calories": 30,
      "protein": 0.7,
      "carbs": 10.5,
      "fat": 0.2,
      "fiber": 2.8,
      "vitaminC": 29.1,
      "potassium": 102.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Limes, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 67.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "mango",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      5,
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Mango",
      "it": "Mango"
    },
    "nutrition": {
      "calories": 60,
      "protein": 0.82,
      "carbs": 14.98,
      "fat": 0.38,
      "fiber": 1.6,
      "vitaminC": 36.4,
      "potassium": 168.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Mangos, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 200.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "pineapple",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      3,
      4,
      5,
      6,
      7,
      8
    ],
    "localizedNames": {
      "en": "Pineapple",
      "it": "Ananas"
    },
    "nutrition": {
      "calories": 50,
      "protein": 0.54,
      "carbs": 13.12,
      "fat": 0.12,
      "fiber": 1.4,
      "vitaminC": 47.8,
      "potassium": 109.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Pineapple, raw, all varieties",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 905.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "watermelon",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Watermelon",
      "it": "Anguria"
    },
    "nutrition": {
      "calories": 30,
      "protein": 0.61,
      "carbs": 7.55,
      "fat": 0.15,
      "fiber": 0.4,
      "vitaminC": 8.1,
      "potassium": 112.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Watermelon, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 2860.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "melon",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Melon",
      "it": "Melone"
    },
    "nutrition": {
      "calories": 34,
      "protein": 0.84,
      "carbs": 8.16,
      "fat": 0.19,
      "fiber": 0.9,
      "vitaminC": 36.7,
      "potassium": 267.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Melons, cantaloupe, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 552.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "plum",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Plum",
      "it": "Prugna"
    },
    "nutrition": {
      "calories": 46,
      "protein": 0.7,
      "carbs": 11.4,
      "fat": 0.28,
      "fiber": 1.4,
      "vitaminC": 9.5,
      "potassium": 157.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Plums, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 66.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "fig",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      8,
      9,
      10
    ],
    "localizedNames": {
      "en": "Fig",
      "it": "Fico"
    },
    "nutrition": {
      "calories": 74,
      "protein": 0.75,
      "carbs": 19.18,
      "fat": 0.3,
      "fiber": 2.9,
      "vitaminC": 2.0,
      "potassium": 232.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Figs, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 50.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "pomegranate",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Pomegranate",
      "it": "Melograno"
    },
    "nutrition": {
      "calories": 83,
      "protein": 1.67,
      "carbs": 18.7,
      "fat": 1.17,
      "fiber": 4.0,
      "vitaminC": 10.2,
      "potassium": 236.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Pomegranates, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 282.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "raspberry",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      5,
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Raspberry",
      "it": "Lampone"
    },
    "nutrition": {
      "calories": 52,
      "protein": 1.2,
      "carbs": 11.9,
      "fat": 0.65,
      "fiber": 6.5,
      "vitaminC": 26.2,
      "potassium": 151.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Raspberries, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 4.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "blackberry",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Blackberry",
      "it": "Mora"
    },
    "nutrition": {
      "calories": 43,
      "protein": 1.39,
      "carbs": 9.61,
      "fat": 0.49,
      "fiber": 5.3,
      "vitaminC": 21.0,
      "potassium": 162.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Blackberries, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 5.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "persimmon",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Persimmon",
      "it": "Cachi"
    },
    "nutrition": {
      "calories": 70,
      "protein": 0.58,
      "carbs": 18.59,
      "fat": 0.19,
      "fiber": 3.6,
      "vitaminC": 7.5,
      "potassium": 161.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Persimmons, japanese, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 168.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "avocado",
    "category": "fruit",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      1,
      2,
      3,
      4,
      5
    ],
    "localizedNames": {
      "en": "Avocado",
      "it": "Avocado"
    },
    "nutrition": {
      "calories": 160,
      "protein": 2.0,
      "carbs": 8.53,
      "fat": 14.66,
      "fiber": 6.7,
      "vitaminC": 10.0,
      "potassium": 485.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Avocados, raw, all commercial varieties",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 201.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "kale",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      10,
      11,
      12,
      1,
      2,
      3
    ],
    "localizedNames": {
      "en": "Kale",
      "it": "Cavolo riccio"
    },
    "nutrition": {
      "calories": 49,
      "protein": 4.28,
      "carbs": 8.75,
      "fat": 0.93,
      "fiber": 3.6,
      "vitaminC": 120.0,
      "potassium": 491.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Kale, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 67.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "swiss_chard",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      9,
      10,
      11,
      12,
      1,
      2,
      3,
      4
    ],
    "localizedNames": {
      "en": "Swiss chard",
      "it": "Bietola"
    },
    "nutrition": {
      "calories": 19,
      "protein": 1.8,
      "carbs": 3.74,
      "fat": 0.2,
      "fiber": 1.6,
      "vitaminC": 30.0,
      "potassium": 379.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Chard, swiss, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 48.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "radicchio",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      10,
      11,
      12,
      1,
      2,
      3
    ],
    "localizedNames": {
      "en": "Radicchio",
      "it": "Radicchio"
    },
    "nutrition": {
      "calories": 23,
      "protein": 1.43,
      "carbs": 4.48,
      "fat": 0.25,
      "fiber": 0.9,
      "vitaminC": 8.0,
      "potassium": 302.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Radicchio, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 150.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "endive",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      10,
      11,
      12,
      1,
      2,
      3,
      4
    ],
    "localizedNames": {
      "en": "Endive",
      "it": "Indivia"
    },
    "nutrition": {
      "calories": 17,
      "protein": 1.25,
      "carbs": 3.35,
      "fat": 0.2,
      "fiber": 3.1,
      "vitaminC": 6.5,
      "potassium": 314.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Endive, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 513.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "beetroot",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      9,
      10,
      11,
      12,
      1,
      2,
      3
    ],
    "localizedNames": {
      "en": "Beetroot",
      "it": "Barbabietola"
    },
    "nutrition": {
      "calories": 43,
      "protein": 1.61,
      "carbs": 9.56,
      "fat": 0.17,
      "fiber": 2.8,
      "vitaminC": 4.9,
      "potassium": 325.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Beets, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 82.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "radish",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      3,
      4,
      5,
      6,
      9,
      10
    ],
    "localizedNames": {
      "en": "Radish",
      "it": "Ravanello"
    },
    "nutrition": {
      "calories": 16,
      "protein": 0.68,
      "carbs": 3.4,
      "fat": 0.1,
      "fiber": 1.6,
      "vitaminC": 14.8,
      "potassium": 233.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Radishes, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 4.5,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "turnip",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      10,
      11,
      12,
      1,
      2,
      3
    ],
    "localizedNames": {
      "en": "Turnip",
      "it": "Rapa"
    },
    "nutrition": {
      "calories": 28,
      "protein": 0.9,
      "carbs": 6.43,
      "fat": 0.1,
      "fiber": 1.8,
      "vitaminC": 21.0,
      "potassium": 191.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Turnips, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 122.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "brussels_sprouts",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      10,
      11,
      12,
      1,
      2
    ],
    "localizedNames": {
      "en": "Brussels sprouts",
      "it": "Cavolini di Bruxelles"
    },
    "nutrition": {
      "calories": 43,
      "protein": 3.38,
      "carbs": 8.95,
      "fat": 0.3,
      "fiber": 3.8,
      "vitaminC": 85.0,
      "potassium": 389.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Brussels sprouts, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 19.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "savoy_cabbage",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      10,
      11,
      12,
      1,
      2,
      3
    ],
    "localizedNames": {
      "en": "Savoy cabbage",
      "it": "Verza"
    },
    "nutrition": {
      "calories": 27,
      "protein": 2.0,
      "carbs": 6.1,
      "fat": 0.1,
      "fiber": 3.1,
      "vitaminC": 31.0,
      "potassium": 230.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Cabbage, savoy, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 900.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "red_cabbage",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      10,
      11,
      12,
      1,
      2,
      3,
      4
    ],
    "localizedNames": {
      "en": "Red cabbage",
      "it": "Cavolo rosso"
    },
    "nutrition": {
      "calories": 31,
      "protein": 1.43,
      "carbs": 7.37,
      "fat": 0.16,
      "fiber": 2.1,
      "vitaminC": 57.0,
      "potassium": 243.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Cabbage, red, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 900.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "pak_choi",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      9,
      10,
      11,
      12,
      1,
      2,
      3
    ],
    "localizedNames": {
      "en": "Pak choi",
      "it": "Pak choi"
    },
    "nutrition": {
      "calories": 13,
      "protein": 1.5,
      "carbs": 2.2,
      "fat": 0.2,
      "fiber": 1.0,
      "vitaminC": 45.0,
      "potassium": 252.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Cabbage, chinese (pak-choi), raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 150.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "shallot",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9,
      10
    ],
    "localizedNames": {
      "en": "Shallot",
      "it": "Scalogno"
    },
    "nutrition": {
      "calories": 72,
      "protein": 2.5,
      "carbs": 16.8,
      "fat": 0.1,
      "fiber": 3.2,
      "vitaminC": 8.0,
      "potassium": 334.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Shallots, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 25.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "chili_pepper",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9,
      10
    ],
    "localizedNames": {
      "en": "Chili pepper",
      "it": "Peperoncino"
    },
    "nutrition": {
      "calories": 40,
      "protein": 1.87,
      "carbs": 8.8,
      "fat": 0.44,
      "fiber": 1.5,
      "vitaminC": 143.0,
      "potassium": 322.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Peppers, hot chili, red, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 15.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "ginger",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Ginger",
      "it": "Zenzero"
    },
    "nutrition": {
      "calories": 80,
      "protein": 1.82,
      "carbs": 17.77,
      "fat": 0.75,
      "fiber": 2.0,
      "vitaminC": 5.0,
      "potassium": 415.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Ginger root, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece",
      "tbsp",
      "tsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 5.0,
      "tbsp": 6.0,
      "tsp": 2.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "okra",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Okra",
      "it": "Okra"
    },
    "nutrition": {
      "calories": 33,
      "protein": 1.93,
      "carbs": 7.45,
      "fat": 0.19,
      "fiber": 3.2,
      "vitaminC": 23.0,
      "potassium": 299.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Okra, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 12.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "corn",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Sweet corn",
      "it": "Mais dolce"
    },
    "nutrition": {
      "calories": 86,
      "protein": 3.27,
      "carbs": 18.7,
      "fat": 1.35,
      "fiber": 2.0,
      "vitaminC": 6.8,
      "potassium": 270.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Corn, sweet, yellow, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 103.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "oyster_mushroom",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      9,
      10,
      11,
      12,
      1,
      2
    ],
    "localizedNames": {
      "en": "Oyster mushroom",
      "it": "Pleurotus"
    },
    "nutrition": {
      "calories": 33,
      "protein": 3.31,
      "carbs": 6.1,
      "fat": 0.41,
      "fiber": 2.3,
      "vitaminC": 0.0,
      "potassium": 420.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Mushrooms, oyster, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 15.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "porcini_mushroom",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      8,
      9,
      10
    ],
    "localizedNames": {
      "en": "Porcini mushroom",
      "it": "Porcino"
    },
    "nutrition": {
      "calories": 22,
      "protein": 3.1,
      "carbs": 3.3,
      "fat": 0.3,
      "fiber": 1.0,
      "vitaminC": 2.1,
      "potassium": 318.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Mushrooms, mixed species, raw",
    "nutritionMappingNote": "Porcini mapped to mixed wild mushroom profile due USDA taxonomy granularity.",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 20.0
    },
    "nutritionMappingConfidence": "approximate"
  },
  {
    "id": "shiitake",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      9,
      10,
      11,
      12,
      1,
      2,
      3
    ],
    "localizedNames": {
      "en": "Shiitake mushroom",
      "it": "Shiitake"
    },
    "nutrition": {
      "calories": 34,
      "protein": 2.24,
      "carbs": 6.79,
      "fat": 0.49,
      "fiber": 2.5,
      "vitaminC": 3.5,
      "potassium": 304.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Mushrooms, shiitake, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 12.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "yam",
    "category": "tuber",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      9,
      10,
      11,
      12,
      1
    ],
    "localizedNames": {
      "en": "Yam",
      "it": "Igname"
    },
    "nutrition": {
      "calories": 118,
      "protein": 1.53,
      "carbs": 27.88,
      "fat": 0.17,
      "fiber": 4.1,
      "vitaminC": 17.1,
      "potassium": 816.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Yam, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 300.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "cassava",
    "category": "tuber",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Cassava",
      "it": "Manioca"
    },
    "nutrition": {
      "calories": 160,
      "protein": 1.36,
      "carbs": 38.06,
      "fat": 0.28,
      "fiber": 1.8,
      "vitaminC": 20.6,
      "potassium": 271.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Cassava, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 400.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "parsnip",
    "category": "tuber",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      10,
      11,
      12,
      1,
      2,
      3
    ],
    "localizedNames": {
      "en": "Parsnip",
      "it": "Pastinaca"
    },
    "nutrition": {
      "calories": 75,
      "protein": 1.2,
      "carbs": 17.99,
      "fat": 0.3,
      "fiber": 4.9,
      "vitaminC": 17.0,
      "potassium": 375.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Parsnips, raw",
    "defaultUnit": "piece",
    "supportedUnits": [
      "piece",
      "g"
    ],
    "gramsPerUnit": {
      "piece": 133.0,
      "g": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "fava_beans",
    "category": "legume",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      3,
      4,
      5,
      6
    ],
    "localizedNames": {
      "en": "Fava beans",
      "it": "Fave"
    },
    "nutrition": {
      "calories": 88,
      "protein": 7.6,
      "carbs": 18.7,
      "fat": 0.7,
      "fiber": 5.4,
      "vitaminC": 1.4,
      "potassium": 332.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Broadbeans, immature seeds, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "tbsp": 10.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "edamame",
    "category": "legume",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Edamame",
      "it": "Edamame"
    },
    "nutrition": {
      "calories": 121,
      "protein": 11.9,
      "carbs": 8.9,
      "fat": 5.2,
      "fiber": 5.2,
      "vitaminC": 6.1,
      "potassium": 436.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Soybeans, green, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "tbsp": 11.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "black_beans",
    "category": "legume",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Black beans",
      "it": "Fagioli neri"
    },
    "nutrition": {
      "calories": 341,
      "protein": 21.6,
      "carbs": 62.4,
      "fat": 1.4,
      "fiber": 15.5,
      "vitaminC": 0.0,
      "potassium": 1483.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Beans, black, mature seeds, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "tbsp": 11.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "kidney_beans",
    "category": "legume",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Kidney beans",
      "it": "Fagioli rossi"
    },
    "nutrition": {
      "calories": 333,
      "protein": 23.6,
      "carbs": 60.0,
      "fat": 0.8,
      "fiber": 24.9,
      "vitaminC": 4.5,
      "potassium": 1406.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Beans, kidney, all types, mature seeds, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "tbsp": 11.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "cannellini_beans",
    "category": "legume",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12
    ],
    "localizedNames": {
      "en": "Cannellini beans",
      "it": "Fagioli cannellini"
    },
    "nutrition": {
      "calories": 333,
      "protein": 23.4,
      "carbs": 60.3,
      "fat": 0.8,
      "fiber": 15.2,
      "vitaminC": 0.0,
      "potassium": 1400.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Beans, white, mature seeds, raw",
    "nutritionMappingNote": "Cannellini mapped to white bean profile.",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "tbsp": 11.0
    },
    "nutritionMappingConfidence": "approximate"
  },
  {
    "id": "borlotti_beans",
    "category": "legume",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      8,
      9,
      10
    ],
    "localizedNames": {
      "en": "Borlotti beans",
      "it": "Fagioli borlotti"
    },
    "nutrition": {
      "calories": 333,
      "protein": 23.0,
      "carbs": 60.0,
      "fat": 0.8,
      "fiber": 15.0,
      "vitaminC": 0.0,
      "potassium": 1370.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Beans, cranberry (roman), mature seeds, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "tbsp": 11.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "mint",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      4,
      5,
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Mint",
      "it": "Menta"
    },
    "nutrition": {
      "calories": 44,
      "protein": 3.29,
      "carbs": 8.41,
      "fat": 0.73,
      "fiber": 6.8,
      "vitaminC": 13.3,
      "potassium": 458.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Mint, fresh",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 0.5,
      "tbsp": 1.5
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "sage",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      4,
      5,
      6,
      7,
      8,
      9,
      10
    ],
    "localizedNames": {
      "en": "Sage",
      "it": "Salvia"
    },
    "nutrition": {
      "calories": 315,
      "protein": 10.6,
      "carbs": 60.7,
      "fat": 12.8,
      "fiber": 40.3,
      "vitaminC": 32.4,
      "potassium": 1070.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Spices, sage, ground",
    "nutritionMappingNote": "Fresh sage mapped to USDA dried sage profile; values can be higher than fresh leaves.",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece",
      "tbsp",
      "tsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 0.4,
      "tbsp": 2.0,
      "tsp": 0.7
    },
    "nutritionMappingConfidence": "approximate"
  },
  {
    "id": "oregano",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      4,
      5,
      6,
      7,
      8,
      9,
      10
    ],
    "localizedNames": {
      "en": "Oregano",
      "it": "Origano"
    },
    "nutrition": {
      "calories": 265,
      "protein": 9.0,
      "carbs": 68.9,
      "fat": 4.3,
      "fiber": 42.5,
      "vitaminC": 2.3,
      "potassium": 1260.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Spices, oregano, dried",
    "nutritionMappingNote": "Fresh oregano mapped to USDA dried oregano profile; values can be higher than fresh leaves.",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece",
      "tbsp",
      "tsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 0.3,
      "tbsp": 1.0,
      "tsp": 0.4
    },
    "nutritionMappingConfidence": "approximate"
  },
  {
    "id": "dill",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      4,
      5,
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Dill",
      "it": "Aneto"
    },
    "nutrition": {
      "calories": 43,
      "protein": 3.5,
      "carbs": 7.0,
      "fat": 1.1,
      "fiber": 2.1,
      "vitaminC": 85.0,
      "potassium": 738.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Dill weed, fresh",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 0.5,
      "tbsp": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "coriander",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      4,
      5,
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Coriander",
      "it": "Coriandolo"
    },
    "nutrition": {
      "calories": 23,
      "protein": 2.13,
      "carbs": 3.67,
      "fat": 0.52,
      "fiber": 2.8,
      "vitaminC": 27.0,
      "potassium": 521.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Coriander (cilantro) leaves, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 0.5,
      "tbsp": 1.0
    },
    "nutritionMappingConfidence": "high"
  },
  {
    "id": "chives",
    "category": "vegetable",
    "ingredientQualityLevel": "core",
    "seasonMonths": [
      4,
      5,
      6,
      7,
      8,
      9
    ],
    "localizedNames": {
      "en": "Chives",
      "it": "Erba cipollina"
    },
    "nutrition": {
      "calories": 30,
      "protein": 3.27,
      "carbs": 4.35,
      "fat": 0.73,
      "fiber": 2.5,
      "vitaminC": 58.1,
      "potassium": 296.0
    },
    "nutritionSource": "USDA FoodData Central",
    "nutritionBasis": "per_100g",
    "nutritionReference": "USDA FDC: Chives, raw",
    "defaultUnit": "g",
    "supportedUnits": [
      "g",
      "piece",
      "tbsp"
    ],
    "gramsPerUnit": {
      "g": 1.0,
      "piece": 0.4,
      "tbsp": 3.0
    },
    "nutritionMappingConfidence": "high"
  }
]
$produce_json$
::jsonb
);

with produce_seed as (
  select
    nullif(trim(item->>'id'), '') as slug,
    nullif(trim(item#>>'{localizedNames,en}'), '') as en_name,
    nullif(trim(item#>>'{localizedNames,it}'), '') as it_name
  from _repair_produce_seed s,
  lateral jsonb_array_elements(s.payload) as item
),
produce_localizations as (
  select
    i.id as ingredient_id,
    'en'::text as language_code,
    p.en_name as display_name
  from produce_seed p
  join public.ingredients i
    on i.slug = p.slug
   and i.ingredient_type = 'produce'
  where p.slug is not null
    and p.en_name is not null

  union all

  select
    i.id as ingredient_id,
    'it'::text as language_code,
    p.it_name as display_name
  from produce_seed p
  join public.ingredients i
    on i.slug = p.slug
   and i.ingredient_type = 'produce'
  where p.slug is not null
    and p.it_name is not null
)
insert into public.ingredient_localizations (
  ingredient_id,
  language_code,
  display_name,
  created_at,
  updated_at
)
select
  ingredient_id,
  language_code,
  display_name,
  now(),
  now()
from produce_localizations
on conflict (ingredient_id, language_code)
do update set
  display_name = excluded.display_name,
  updated_at = now();
