import Foundation

enum BasicIngredientCatalog {
    static let all: [BasicIngredient] = [
        // Proteins
        make(
            id: "chicken",
            en: "Chicken breast",
            it: "Petto di pollo",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 165, protein: 31.0, carbs: 0.0, fat: 3.6, fiber: 0.0, vitaminC: 0.0, potassium: 256.0),
            nutritionReference: "USDA FDC: Chicken, broilers or fryers, breast, meat only, raw",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 120, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "turkey",
            en: "Turkey breast",
            it: "Petto di tacchino",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 114, protein: 24.0, carbs: 0.0, fat: 1.4, fiber: 0.0, vitaminC: 0.0, potassium: 239.0),
            nutritionReference: "USDA FDC: Turkey, all classes, breast, meat only, raw",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 120, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "beef",
            en: "Beef",
            it: "Manzo",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 250, protein: 26.0, carbs: 0.0, fat: 15.0, fiber: 0.0, vitaminC: 0.0, potassium: 318.0),
            nutritionReference: "USDA FDC: Beef, ground, 85% lean meat / 15% fat, raw",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 150], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "pork",
            en: "Pork",
            it: "Maiale",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 242, protein: 27.0, carbs: 0.0, fat: 14.0, fiber: 0.0, vitaminC: 0.0, potassium: 423.0),
            nutritionReference: "USDA FDC: Pork, fresh, loin, raw",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 150], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "salmon",
            en: "Salmon",
            it: "Salmone",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 208, protein: 20.4, carbs: 0.0, fat: 13.4, fiber: 0.0, vitaminC: 0.0, potassium: 363.0),
            nutritionReference: "USDA FDC: Fish, salmon, Atlantic, farmed, raw",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 150], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "tuna",
            en: "Tuna",
            it: "Tonno",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 132, protein: 28.0, carbs: 0.0, fat: 1.3, fiber: 0.0, vitaminC: 0.0, potassium: 252.0),
            nutritionReference: "USDA FDC: Fish, tuna, light, canned in water, drained solids",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 80], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "eggs",
            en: "Eggs",
            it: "Uova",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 143, protein: 12.6, carbs: 0.7, fat: 9.5, fiber: 0.0, vitaminC: 0.0, potassium: 138.0),
            nutritionReference: "USDA FDC: Egg, whole, raw, fresh",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 50, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),

        // Dairy
        make(
            id: "milk",
            en: "Milk",
            it: "Latte",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 61, protein: 3.2, carbs: 4.8, fat: 3.3, fiber: 0.0, vitaminC: 0.0, potassium: 150.0),
            nutritionReference: "USDA FDC: Milk, whole, 3.25% milkfat",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .tbsp, .tsp, .g], gramsPerUnit: [.g: 1], mlPerUnit: [.ml: 1, .tbsp: 15, .tsp: 5], gramsPerMl: 1.03),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "yogurt",
            en: "Yogurt",
            it: "Yogurt",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 59, protein: 3.5, carbs: 4.7, fat: 3.3, fiber: 0.0, vitaminC: 0.8, potassium: 141.0),
            nutritionReference: "USDA FDC: Yogurt, plain, whole milk",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .ml, .tbsp], gramsPerUnit: [.g: 1], mlPerUnit: [.ml: 1, .tbsp: 15], gramsPerMl: 1.04),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "greek_yogurt",
            en: "Greek yogurt",
            it: "Yogurt greco",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 97, protein: 9.0, carbs: 3.9, fat: 5.0, fiber: 0.0, vitaminC: 0.5, potassium: 141.0),
            nutritionReference: "USDA FDC: Yogurt, Greek, plain, whole milk",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .ml, .tbsp], gramsPerUnit: [.g: 1], mlPerUnit: [.ml: 1, .tbsp: 15], gramsPerMl: 1.05),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "parmesan",
            en: "Parmesan",
            it: "Parmigiano",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 431, protein: 38.0, carbs: 4.1, fat: 29.0, fiber: 0.0, vitaminC: 0.0, potassium: 92.0),
            nutritionReference: "USDA FDC: Cheese, parmesan, grated",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 5, .tsp: 2], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "mozzarella",
            en: "Mozzarella",
            it: "Mozzarella",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 280, protein: 28.0, carbs: 3.1, fat: 17.0, fiber: 0.0, vitaminC: 0.0, potassium: 95.0),
            nutritionReference: "USDA FDC: Cheese, mozzarella, whole milk",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 125], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "ricotta",
            en: "Ricotta",
            it: "Ricotta",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 174, protein: 11.3, carbs: 3.0, fat: 13.0, fiber: 0.0, vitaminC: 0.0, potassium: 151.0),
            nutritionReference: "USDA FDC: Cheese, ricotta, whole milk",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 15], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "cream_cheese",
            en: "Cream cheese",
            it: "Formaggio spalmabile",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 342, protein: 6.2, carbs: 4.1, fat: 34.4, fiber: 0.0, vitaminC: 0.0, potassium: 132.0),
            nutritionReference: "USDA FDC: Cheese, cream",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 14], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "butter",
            en: "Butter",
            it: "Burro",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 717, protein: 0.9, carbs: 0.1, fat: 81.0, fiber: 0.0, vitaminC: 0.0, potassium: 24.0),
            nutritionReference: "USDA FDC: Butter, salted",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 14, .tsp: 5], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),

        // Grains, pasta, rice
        make(
            id: "pasta",
            en: "Pasta (dry)",
            it: "Pasta secca",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 371, protein: 13.0, carbs: 75.0, fat: 1.5, fiber: 3.0, vitaminC: 0.0, potassium: 223.0),
            nutritionReference: "USDA FDC: Pasta, dry, unenriched",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 8], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: false, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "rice",
            en: "Rice (dry)",
            it: "Riso secco",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 360, protein: 6.6, carbs: 79.0, fat: 0.6, fiber: 1.3, vitaminC: 0.0, potassium: 115.0),
            nutritionReference: "USDA FDC: Rice, white, long-grain, regular, raw, unenriched",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 12], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "bread",
            en: "Bread",
            it: "Pane",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 265, protein: 9.0, carbs: 49.0, fat: 3.2, fiber: 2.7, vitaminC: 0.0, potassium: 115.0),
            nutritionReference: "USDA FDC: Bread, white, commercially prepared",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 30, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: false, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "flour",
            en: "Wheat flour",
            it: "Farina di grano",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 364, protein: 10.3, carbs: 76.0, fat: 1.0, fiber: 2.7, vitaminC: 0.0, potassium: 107.0),
            nutritionReference: "USDA FDC: Wheat flour, white, all-purpose, enriched",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 8], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: false, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "oats",
            en: "Oats",
            it: "Avena",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 389, protein: 16.9, carbs: 66.3, fat: 6.9, fiber: 10.6, vitaminC: 0.0, potassium: 429.0),
            nutritionReference: "USDA FDC: Oats",
            nutritionMappingNote: "May vary by rolled/steel-cut processing.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 5], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: true)
        ),

        // Pantry staples
        make(
            id: "olive_oil",
            en: "Olive oil",
            it: "Olio d'oliva",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 884, protein: 0.0, carbs: 0.0, fat: 100.0, fiber: 0.0, vitaminC: 0.0, potassium: 1.0),
            nutritionReference: "USDA FDC: Oil, olive, salad or cooking",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .tbsp, .tsp, .g], gramsPerUnit: [.g: 1, .tbsp: 13.5, .tsp: 4.5], mlPerUnit: [.ml: 1, .tbsp: 15, .tsp: 5], gramsPerMl: 0.91),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "salt",
            en: "Salt",
            it: "Sale",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 0, protein: 0.0, carbs: 0.0, fat: 0.0, fiber: 0.0, vitaminC: 0.0, potassium: 8.0),
            nutritionReference: "USDA FDC: Salt, table",
            unitProfile: IngredientUnitProfile(defaultUnit: .tsp, supportedUnits: [.g, .tsp, .tbsp], gramsPerUnit: [.g: 1, .tsp: 6, .tbsp: 18], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "black_pepper",
            en: "Black pepper",
            it: "Pepe nero",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 251, protein: 10.4, carbs: 64.8, fat: 3.3, fiber: 25.0, vitaminC: 21.0, potassium: 1259.0),
            nutritionReference: "USDA FDC: Spices, pepper, black",
            unitProfile: IngredientUnitProfile(defaultUnit: .tsp, supportedUnits: [.g, .tsp], gramsPerUnit: [.g: 1, .tsp: 2], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "sugar",
            en: "Sugar",
            it: "Zucchero",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 387, protein: 0.0, carbs: 100.0, fat: 0.0, fiber: 0.0, vitaminC: 0.0, potassium: 2.0),
            nutritionReference: "USDA FDC: Sugars, granulated",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tsp, .tbsp], gramsPerUnit: [.g: 1, .tsp: 4, .tbsp: 12], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "honey",
            en: "Honey",
            it: "Miele",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 304, protein: 0.3, carbs: 82.4, fat: 0.0, fiber: 0.2, vitaminC: 0.5, potassium: 52.0),
            nutritionReference: "USDA FDC: Honey",
            unitProfile: IngredientUnitProfile(defaultUnit: .tbsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 21, .tsp: 7], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "broth",
            en: "Broth",
            it: "Brodo",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 5, protein: 0.4, carbs: 0.5, fat: 0.2, fiber: 0.0, vitaminC: 0.0, potassium: 20.0),
            nutritionReference: "USDA FDC: Soup, stock, chicken, home-prepared",
            nutritionMappingNote: "Broth composition varies by preparation.",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .tbsp, .tsp], gramsPerUnit: [:], mlPerUnit: [.ml: 1, .tbsp: 15, .tsp: 5], gramsPerMl: 1.0),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: nil, isVegan: nil)
        ),
        make(
            id: "water",
            en: "Water",
            it: "Acqua",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 0, protein: 0.0, carbs: 0.0, fat: 0.0, fiber: 0.0, vitaminC: 0.0, potassium: 0.0),
            nutritionReference: "USDA FDC: Water, bottled",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .tbsp, .tsp], gramsPerUnit: [:], mlPerUnit: [.ml: 1, .tbsp: 15, .tsp: 5], gramsPerMl: 1.0),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),

        // Condiments and aromatics
        make(
            id: "vinegar",
            en: "Vinegar",
            it: "Aceto",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 21, protein: 0.0, carbs: 0.0, fat: 0.0, fiber: 0.0, vitaminC: 0.0, potassium: 2.0),
            nutritionReference: "USDA FDC: Vinegar, cider",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .tbsp, .tsp], gramsPerUnit: [:], mlPerUnit: [.ml: 1, .tbsp: 15, .tsp: 5], gramsPerMl: 1.0),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "balsamic_vinegar",
            en: "Balsamic vinegar",
            it: "Aceto balsamico",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 88, protein: 0.5, carbs: 17.0, fat: 0.0, fiber: 0.0, vitaminC: 0.0, potassium: 112.0),
            nutritionReference: "USDA FDC: Vinegar, balsamic",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .tbsp, .tsp], gramsPerUnit: [:], mlPerUnit: [.ml: 1, .tbsp: 15, .tsp: 5], gramsPerMl: 1.04),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "tomato_sauce",
            en: "Tomato sauce",
            it: "Salsa di pomodoro",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 29, protein: 1.4, carbs: 5.6, fat: 0.2, fiber: 1.5, vitaminC: 9.0, potassium: 237.0),
            nutritionReference: "USDA FDC: Sauce, tomato, canned",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .ml, .tbsp], gramsPerUnit: [.g: 1], mlPerUnit: [.ml: 1, .tbsp: 15], gramsPerMl: 1.02),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "passata",
            en: "Passata",
            it: "Passata",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 33, protein: 1.6, carbs: 6.0, fat: 0.2, fiber: 1.8, vitaminC: 12.0, potassium: 250.0),
            nutritionReference: "USDA FDC: Tomatoes, crushed, canned",
            nutritionMappingNote: "Passata mapped to plain crushed/canned tomato preparations.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .ml, .tbsp], gramsPerUnit: [.g: 1], mlPerUnit: [.ml: 1, .tbsp: 15], gramsPerMl: 1.03),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "pesto",
            en: "Pesto",
            it: "Pesto",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 480, protein: 4.0, carbs: 6.0, fat: 49.0, fiber: 2.0, vitaminC: 3.0, potassium: 180.0),
            nutritionReference: "USDA FDC: Pesto-style sauce, generic",
            nutritionMappingNote: "Pesto varies by recipe (oil/cheese/nuts ratios).",
            unitProfile: IngredientUnitProfile(defaultUnit: .tbsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 16, .tsp: 5], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: nil)
        ),

        // Aromatics
        make(
            id: "garlic",
            en: "Garlic",
            it: "Aglio",
            category: .herbsAromatics,
            nutrition: ProduceNutrition(calories: 149, protein: 6.4, carbs: 33.0, fat: 0.5, fiber: 2.1, vitaminC: 31.0, potassium: 401.0),
            nutritionReference: "USDA FDC: Garlic, raw",
            unitProfile: IngredientUnitProfile(defaultUnit: .clove, supportedUnits: [.clove, .g, .piece], gramsPerUnit: [.clove: 3, .piece: 3, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "onion_basic",
            en: "Onion",
            it: "Cipolla",
            category: .herbsAromatics,
            nutrition: ProduceNutrition(calories: 40, protein: 1.1, carbs: 9.3, fat: 0.1, fiber: 1.7, vitaminC: 7.4, potassium: 146.0),
            nutritionReference: "USDA FDC: Onions, raw",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 110, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        )
    ]

    private static func make(
        id: String,
        en: String,
        it: String,
        category: BasicIngredientCategory,
        nutrition: ProduceNutrition,
        nutritionReference: String?,
        nutritionMappingNote: String? = nil,
        unitProfile: IngredientUnitProfile,
        dietary: BasicIngredientDietaryFlags
    ) -> BasicIngredient {
        BasicIngredient(
            id: id,
            localizedNames: ["en": en, "it": it],
            category: category,
            ingredientQualityLevel: .basic,
            nutrition: nutrition,
            nutritionSource: "USDA FoodData Central",
            nutritionBasis: .per100g,
            nutritionReference: nutritionReference,
            nutritionMappingNote: nutritionMappingNote,
            unitProfile: unitProfile,
            dietaryFlags: dietary
        )
    }
}
