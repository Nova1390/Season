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

        // Expanded proteins and seafood
        make(
            id: "lamb",
            en: "Lamb",
            it: "Agnello",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 294, protein: 25.6, carbs: 0.0, fat: 20.8, fiber: 0.0, vitaminC: 0.0, potassium: 274.0),
            nutritionReference: "USDA FDC: Lamb, domestic, leg, separable lean and fat, raw",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 150], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "veal",
            en: "Veal",
            it: "Vitello",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 172, protein: 24.4, carbs: 0.0, fat: 7.6, fiber: 0.0, vitaminC: 0.0, potassium: 331.0),
            nutritionReference: "USDA FDC: Veal, leg (top round), separable lean and fat, raw",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 140], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "duck",
            en: "Duck",
            it: "Anatra",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 337, protein: 19.0, carbs: 0.0, fat: 28.0, fiber: 0.0, vitaminC: 0.0, potassium: 204.0),
            nutritionReference: "USDA FDC: Duck, domesticated, meat and skin, raw",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 180], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "shrimp",
            en: "Shrimp",
            it: "Gamberi",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 99, protein: 24.0, carbs: 0.2, fat: 0.3, fiber: 0.0, vitaminC: 0.0, potassium: 264.0),
            nutritionReference: "USDA FDC: Crustaceans, shrimp, mixed species, raw",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 12], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "cod",
            en: "Cod",
            it: "Merluzzo",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 82, protein: 17.8, carbs: 0.0, fat: 0.7, fiber: 0.0, vitaminC: 0.9, potassium: 413.0),
            nutritionReference: "USDA FDC: Fish, cod, Atlantic, raw",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 150], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "sardines",
            en: "Sardines",
            it: "Sardine",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 208, protein: 24.6, carbs: 0.0, fat: 11.5, fiber: 0.0, vitaminC: 0.0, potassium: 397.0),
            nutritionReference: "USDA FDC: Fish, sardine, Atlantic, canned in oil, drained solids with bone",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 35], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "anchovies",
            en: "Anchovies",
            it: "Acciughe",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 210, protein: 29.1, carbs: 0.0, fat: 9.7, fiber: 0.0, vitaminC: 0.0, potassium: 383.0),
            nutritionReference: "USDA FDC: Fish, anchovy, european, canned in oil, drained solids",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 4], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "mackerel",
            en: "Mackerel",
            it: "Sgombro",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 205, protein: 18.6, carbs: 0.0, fat: 13.9, fiber: 0.0, vitaminC: 1.6, potassium: 314.0),
            nutritionReference: "USDA FDC: Fish, mackerel, Atlantic, raw",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 140], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "prosciutto_crudo",
            en: "Prosciutto crudo",
            it: "Prosciutto crudo",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 269, protein: 26.0, carbs: 0.3, fat: 18.0, fiber: 0.0, vitaminC: 0.0, potassium: 395.0),
            nutritionReference: "USDA FDC: Pork, cured, ham, separable lean and fat",
            nutritionMappingNote: "Mapped to cured ham profile; values vary by aging and salt level.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 8], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "prosciutto_cotto",
            en: "Prosciutto cotto",
            it: "Prosciutto cotto",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 145, protein: 20.9, carbs: 1.0, fat: 6.1, fiber: 0.0, vitaminC: 0.0, potassium: 287.0),
            nutritionReference: "USDA FDC: Pork, cured, ham, extra lean and regular, roasted",
            nutritionMappingNote: "Mapped to cooked ham profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 20], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "bacon",
            en: "Bacon",
            it: "Pancetta affumicata",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 417, protein: 12.4, carbs: 1.4, fat: 39.7, fiber: 0.0, vitaminC: 0.0, potassium: 565.0),
            nutritionReference: "USDA FDC: Pork, cured, bacon, cooked, pan-fried",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 8], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "sausage",
            en: "Sausage",
            it: "Salsiccia",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 301, protein: 13.7, carbs: 1.8, fat: 26.0, fiber: 0.0, vitaminC: 0.0, potassium: 254.0),
            nutritionReference: "USDA FDC: Sausage, pork, fresh, raw",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 85], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),

        // Expanded dairy
        make(
            id: "kefir",
            en: "Kefir",
            it: "Kefir",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 55, protein: 3.3, carbs: 4.5, fat: 2.0, fiber: 0.0, vitaminC: 0.0, potassium: 146.0),
            nutritionReference: "USDA FDC: Kefir, lowfat, plain",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .g, .tbsp], gramsPerUnit: [.g: 1], mlPerUnit: [.ml: 1, .tbsp: 15], gramsPerMl: 1.03),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "feta",
            en: "Feta",
            it: "Feta",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 265, protein: 14.2, carbs: 3.9, fat: 21.3, fiber: 0.0, vitaminC: 0.0, potassium: 62.0),
            nutritionReference: "USDA FDC: Cheese, feta",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 30], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "pecorino",
            en: "Pecorino",
            it: "Pecorino",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 387, protein: 25.6, carbs: 3.6, fat: 31.9, fiber: 0.0, vitaminC: 0.0, potassium: 86.0),
            nutritionReference: "USDA FDC: Cheese, romano",
            nutritionMappingNote: "Pecorino mapped to romano sheep cheese profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 5, .tsp: 2], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "provolone",
            en: "Provolone",
            it: "Provolone",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 351, protein: 25.6, carbs: 2.1, fat: 26.6, fiber: 0.0, vitaminC: 0.0, potassium: 138.0),
            nutritionReference: "USDA FDC: Cheese, provolone",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 25], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "gorgonzola",
            en: "Gorgonzola",
            it: "Gorgonzola",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 353, protein: 21.4, carbs: 2.3, fat: 28.7, fiber: 0.0, vitaminC: 0.0, potassium: 256.0),
            nutritionReference: "USDA FDC: Cheese, blue",
            nutritionMappingNote: "Gorgonzola mapped to generic blue cheese profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 20], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "mascarpone",
            en: "Mascarpone",
            it: "Mascarpone",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 435, protein: 4.6, carbs: 4.0, fat: 44.0, fiber: 0.0, vitaminC: 0.0, potassium: 80.0),
            nutritionReference: "USDA FDC: Cheese, mascarpone",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 15], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),

        // Expanded carbs and bakery
        make(
            id: "quinoa",
            en: "Quinoa (dry)",
            it: "Quinoa secca",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 368, protein: 14.1, carbs: 64.2, fat: 6.1, fiber: 7.0, vitaminC: 0.0, potassium: 563.0),
            nutritionReference: "USDA FDC: Quinoa, uncooked",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 12], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "barley",
            en: "Barley (dry)",
            it: "Orzo perlato",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 354, protein: 12.5, carbs: 73.5, fat: 2.3, fiber: 17.3, vitaminC: 0.0, potassium: 452.0),
            nutritionReference: "USDA FDC: Barley, hulled",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 10], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: false, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "couscous",
            en: "Couscous (dry)",
            it: "Couscous secco",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 376, protein: 12.8, carbs: 77.4, fat: 0.6, fiber: 5.0, vitaminC: 0.0, potassium: 166.0),
            nutritionReference: "USDA FDC: Couscous, dry",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 10], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: false, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "cornmeal",
            en: "Cornmeal",
            it: "Farina di mais",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 370, protein: 8.1, carbs: 79.4, fat: 3.6, fiber: 7.3, vitaminC: 0.0, potassium: 142.0),
            nutritionReference: "USDA FDC: Cornmeal, yellow, degermed, enriched",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 8], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "breadcrumbs",
            en: "Breadcrumbs",
            it: "Pangrattato",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 395, protein: 13.4, carbs: 72.5, fat: 5.3, fiber: 4.5, vitaminC: 0.0, potassium: 227.0),
            nutritionReference: "USDA FDC: Bread crumbs, dry, grated, plain",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 7, .tsp: 2], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: false, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "tortillas",
            en: "Tortillas",
            it: "Tortillas",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 310, protein: 8.0, carbs: 52.0, fat: 8.0, fiber: 3.8, vitaminC: 0.0, potassium: 186.0),
            nutritionReference: "USDA FDC: Tortillas, ready-to-bake or -fry, flour",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 45, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: false, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "crackers",
            en: "Crackers",
            it: "Cracker",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 430, protein: 8.7, carbs: 72.0, fat: 11.0, fiber: 3.2, vitaminC: 0.0, potassium: 154.0),
            nutritionReference: "USDA FDC: Crackers, plain",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 7, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: false, isVegetarian: true, isVegan: true)
        ),

        // Expanded oils and condiments
        make(
            id: "sunflower_oil",
            en: "Sunflower oil",
            it: "Olio di semi di girasole",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 884, protein: 0.0, carbs: 0.0, fat: 100.0, fiber: 0.0, vitaminC: 0.0, potassium: 0.0),
            nutritionReference: "USDA FDC: Oil, sunflower, linoleic",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .tbsp, .tsp, .g], gramsPerUnit: [.g: 1, .tbsp: 13.6, .tsp: 4.5], mlPerUnit: [.ml: 1, .tbsp: 15, .tsp: 5], gramsPerMl: 0.92),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "canola_oil",
            en: "Canola oil",
            it: "Olio di colza",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 884, protein: 0.0, carbs: 0.0, fat: 100.0, fiber: 0.0, vitaminC: 0.0, potassium: 0.0),
            nutritionReference: "USDA FDC: Oil, canola",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .tbsp, .tsp, .g], gramsPerUnit: [.g: 1, .tbsp: 13.6, .tsp: 4.5], mlPerUnit: [.ml: 1, .tbsp: 15, .tsp: 5], gramsPerMl: 0.92),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "sesame_oil",
            en: "Sesame oil",
            it: "Olio di sesamo",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 884, protein: 0.0, carbs: 0.0, fat: 100.0, fiber: 0.0, vitaminC: 0.0, potassium: 0.0),
            nutritionReference: "USDA FDC: Oil, sesame, salad or cooking",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .tbsp, .tsp, .g], gramsPerUnit: [.g: 1, .tbsp: 13.6, .tsp: 4.5], mlPerUnit: [.ml: 1, .tbsp: 15, .tsp: 5], gramsPerMl: 0.92),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "peanut_butter",
            en: "Peanut butter",
            it: "Burro di arachidi",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 588, protein: 25.1, carbs: 19.6, fat: 50.4, fiber: 6.0, vitaminC: 0.0, potassium: 649.0),
            nutritionReference: "USDA FDC: Peanut butter, smooth style, without salt",
            unitProfile: IngredientUnitProfile(defaultUnit: .tbsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 16, .tsp: 5], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "soy_sauce",
            en: "Soy sauce",
            it: "Salsa di soia",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 53, protein: 8.1, carbs: 4.9, fat: 0.6, fiber: 0.8, vitaminC: 0.0, potassium: 435.0),
            nutritionReference: "USDA FDC: Sauce, soy, made from soy and wheat",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .tbsp, .tsp], gramsPerUnit: [:], mlPerUnit: [.ml: 1, .tbsp: 15, .tsp: 5], gramsPerMl: 1.2),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "mustard",
            en: "Mustard",
            it: "Senape",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 66, protein: 4.4, carbs: 5.8, fat: 3.3, fiber: 4.0, vitaminC: 0.5, potassium: 138.0),
            nutritionReference: "USDA FDC: Mustard, prepared, yellow",
            unitProfile: IngredientUnitProfile(defaultUnit: .tbsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 15, .tsp: 5], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "mayonnaise",
            en: "Mayonnaise",
            it: "Maionese",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 680, protein: 1.0, carbs: 0.6, fat: 75.0, fiber: 0.0, vitaminC: 0.0, potassium: 20.0),
            nutritionReference: "USDA FDC: Salad dressing, mayonnaise, regular",
            unitProfile: IngredientUnitProfile(defaultUnit: .tbsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 14, .tsp: 5], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "ketchup",
            en: "Ketchup",
            it: "Ketchup",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 112, protein: 1.3, carbs: 25.8, fat: 0.2, fiber: 0.3, vitaminC: 4.1, potassium: 264.0),
            nutritionReference: "USDA FDC: Catsup",
            unitProfile: IngredientUnitProfile(defaultUnit: .tbsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 17, .tsp: 6], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "worcestershire_sauce",
            en: "Worcestershire sauce",
            it: "Salsa Worcestershire",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 78, protein: 0.9, carbs: 19.4, fat: 0.0, fiber: 0.0, vitaminC: 0.0, potassium: 58.0),
            nutritionReference: "USDA FDC: Sauce, worcestershire",
            unitProfile: IngredientUnitProfile(defaultUnit: .tsp, supportedUnits: [.ml, .tbsp, .tsp], gramsPerUnit: [:], mlPerUnit: [.ml: 1, .tbsp: 15, .tsp: 5], gramsPerMl: 1.04),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: nil, isVegan: nil)
        ),
        make(
            id: "paprika",
            en: "Paprika",
            it: "Paprika",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 282, protein: 14.1, carbs: 54.9, fat: 12.9, fiber: 34.9, vitaminC: 0.9, potassium: 2280.0),
            nutritionReference: "USDA FDC: Spices, paprika",
            unitProfile: IngredientUnitProfile(defaultUnit: .tsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 7, .tsp: 2], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "cumin",
            en: "Cumin",
            it: "Cumino",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 375, protein: 17.8, carbs: 44.2, fat: 22.3, fiber: 10.5, vitaminC: 7.7, potassium: 1788.0),
            nutritionReference: "USDA FDC: Spices, cumin seed",
            unitProfile: IngredientUnitProfile(defaultUnit: .tsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 6, .tsp: 2], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "curry_powder",
            en: "Curry powder",
            it: "Curry in polvere",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 325, protein: 14.3, carbs: 58.2, fat: 14.0, fiber: 53.2, vitaminC: 0.7, potassium: 1170.0),
            nutritionReference: "USDA FDC: Spices, curry powder",
            unitProfile: IngredientUnitProfile(defaultUnit: .tsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 6, .tsp: 2], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "cinnamon",
            en: "Cinnamon",
            it: "Cannella",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 247, protein: 4.0, carbs: 80.6, fat: 1.2, fiber: 53.1, vitaminC: 3.8, potassium: 431.0),
            nutritionReference: "USDA FDC: Spices, cinnamon, ground",
            unitProfile: IngredientUnitProfile(defaultUnit: .tsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 8, .tsp: 3], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "chili_flakes",
            en: "Chili flakes",
            it: "Peperoncino in fiocchi",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 318, protein: 12.0, carbs: 56.6, fat: 17.3, fiber: 27.2, vitaminC: 76.4, potassium: 1870.0),
            nutritionReference: "USDA FDC: Peppers, red or cayenne, dried",
            unitProfile: IngredientUnitProfile(defaultUnit: .tsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 5, .tsp: 1.8], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),

        // Priority family 1: deli meats / salumi
        make(
            id: "bresaola",
            en: "Bresaola",
            it: "Bresaola",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 151, protein: 32.0, carbs: 1.0, fat: 2.0, fiber: 0.0, vitaminC: 0.0, potassium: 620.0),
            nutritionReference: "USDA FDC: Beef, cured, dried",
            nutritionMappingNote: "Bresaola mapped to cured dried beef profile; salt and fat vary by producer.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 8], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "speck",
            en: "Speck",
            it: "Speck",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 301, protein: 29.0, carbs: 0.8, fat: 20.0, fiber: 0.0, vitaminC: 0.0, potassium: 500.0),
            nutritionReference: "USDA FDC: Pork, cured, ham",
            nutritionMappingNote: "Speck mapped to smoked cured ham profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 10], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "mortadella",
            en: "Mortadella",
            it: "Mortadella",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 311, protein: 16.0, carbs: 1.5, fat: 27.0, fiber: 0.0, vitaminC: 0.0, potassium: 260.0),
            nutritionReference: "USDA FDC: Bologna, beef and pork",
            nutritionMappingNote: "Mortadella mapped to bologna-style cooked sausage profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 20], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "salame",
            en: "Salami",
            it: "Salame",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 407, protein: 22.0, carbs: 1.6, fat: 34.0, fiber: 0.0, vitaminC: 0.0, potassium: 480.0),
            nutritionReference: "USDA FDC: Salami, dry or hard, pork, beef",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 8], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "coppa",
            en: "Coppa",
            it: "Coppa",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 351, protein: 25.0, carbs: 0.5, fat: 28.0, fiber: 0.0, vitaminC: 0.0, potassium: 420.0),
            nutritionReference: "USDA FDC: Pork, cured, dried",
            nutritionMappingNote: "Coppa mapped to generic cured pork shoulder profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 10], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "guanciale",
            en: "Guanciale",
            it: "Guanciale",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 655, protein: 10.0, carbs: 0.0, fat: 69.0, fiber: 0.0, vitaminC: 0.0, potassium: 210.0),
            nutritionReference: "USDA FDC: Pork, cured, fatback",
            nutritionMappingNote: "Guanciale mapped to cured pork jowl/fatback profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 12], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "diced_pancetta",
            en: "Diced pancetta",
            it: "Pancetta a cubetti",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 458, protein: 14.1, carbs: 1.4, fat: 45.0, fiber: 0.0, vitaminC: 0.0, potassium: 320.0),
            nutritionReference: "USDA FDC: Pork, cured, bacon, uncooked",
            nutritionMappingNote: "Diced pancetta mapped to uncooked cured pork belly profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 8], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "sliced_roast_beef",
            en: "Sliced roast beef",
            it: "Roast beef affettato",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 170, protein: 28.0, carbs: 1.0, fat: 6.0, fiber: 0.0, vitaminC: 0.0, potassium: 370.0),
            nutritionReference: "USDA FDC: Beef, roast beef, deli style",
            nutritionMappingNote: "Mapped to deli roast beef profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 15], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "sliced_turkey_breast",
            en: "Sliced turkey breast",
            it: "Fesa di tacchino",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 104, protein: 17.0, carbs: 1.5, fat: 2.5, fiber: 0.0, vitaminC: 0.0, potassium: 280.0),
            nutritionReference: "USDA FDC: Turkey breast, deli meat",
            nutritionMappingNote: "Mapped to deli turkey breast profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 18], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "turkey_ham",
            en: "Turkey ham",
            it: "Prosciutto di tacchino",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 124, protein: 16.0, carbs: 1.8, fat: 5.2, fiber: 0.0, vitaminC: 0.0, potassium: 260.0),
            nutritionReference: "USDA FDC: Turkey ham, deli meat",
            nutritionMappingNote: "Mapped to turkey-based ham deli profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 18], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),

        // Priority family 2: canned / jarred pantry
        make(
            id: "canned_chickpeas",
            en: "Canned chickpeas",
            it: "Ceci in scatola",
            category: .legumes,
            nutrition: ProduceNutrition(calories: 139, protein: 7.0, carbs: 22.5, fat: 2.0, fiber: 6.0, vitaminC: 1.0, potassium: 240.0),
            nutritionReference: "USDA FDC: Chickpeas, mature seeds, canned, drained solids",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 15], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "canned_lentils",
            en: "Canned lentils",
            it: "Lenticchie in scatola",
            category: .legumes,
            nutrition: ProduceNutrition(calories: 111, protein: 8.8, carbs: 18.7, fat: 0.4, fiber: 7.3, vitaminC: 1.5, potassium: 350.0),
            nutritionReference: "USDA FDC: Lentils, mature seeds, canned, drained solids",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 15], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "canned_cannellini",
            en: "Canned cannellini beans",
            it: "Cannellini in scatola",
            category: .legumes,
            nutrition: ProduceNutrition(calories: 114, protein: 7.0, carbs: 18.8, fat: 0.4, fiber: 6.3, vitaminC: 0.8, potassium: 330.0),
            nutritionReference: "USDA FDC: Beans, white, mature seeds, canned, drained solids",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 15], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "canned_borlotti",
            en: "Canned borlotti beans",
            it: "Borlotti in scatola",
            category: .legumes,
            nutrition: ProduceNutrition(calories: 116, protein: 7.1, carbs: 19.0, fat: 0.5, fiber: 6.5, vitaminC: 0.8, potassium: 320.0),
            nutritionReference: "USDA FDC: Beans, cranberry (roman), canned, drained solids",
            nutritionMappingNote: "Mapped to canned cranberry/roman bean profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 15], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "canned_corn",
            en: "Canned corn",
            it: "Mais in scatola",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 81, protein: 2.3, carbs: 18.7, fat: 1.2, fiber: 2.6, vitaminC: 2.7, potassium: 218.0),
            nutritionReference: "USDA FDC: Corn, sweet, yellow, canned, drained solids",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 14], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "green_olives",
            en: "Green olives",
            it: "Olive verdi",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 145, protein: 1.0, carbs: 3.8, fat: 15.3, fiber: 3.3, vitaminC: 0.9, potassium: 42.0),
            nutritionReference: "USDA FDC: Olives, green, pickled",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 4, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "black_olives",
            en: "Black olives",
            it: "Olive nere",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 116, protein: 0.8, carbs: 6.0, fat: 10.9, fiber: 1.6, vitaminC: 0.0, potassium: 8.0),
            nutritionReference: "USDA FDC: Olives, ripe, canned",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 3.8, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "capers",
            en: "Capers",
            it: "Capperi",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 23, protein: 2.4, carbs: 4.9, fat: 0.9, fiber: 3.2, vitaminC: 4.3, potassium: 40.0),
            nutritionReference: "USDA FDC: Capers, canned",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tsp, .tbsp], gramsPerUnit: [.g: 1, .tsp: 3, .tbsp: 9], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "pickled_gherkins",
            en: "Pickled gherkins",
            it: "Cetriolini",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 11, protein: 0.3, carbs: 2.3, fat: 0.2, fiber: 1.2, vitaminC: 2.1, potassium: 23.0),
            nutritionReference: "USDA FDC: Cucumber, pickled, with salt",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 15, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "artichokes_in_oil",
            en: "Artichokes in oil",
            it: "Carciofini sott'olio",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 89, protein: 2.0, carbs: 5.0, fat: 7.0, fiber: 3.5, vitaminC: 2.0, potassium: 180.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: preserved-artichoke products vary strongly by oil and brine.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 20], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "eggplant_in_oil",
            en: "Eggplant in oil",
            it: "Melanzane sott'olio",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 95, protein: 1.3, carbs: 4.0, fat: 8.5, fiber: 2.0, vitaminC: 2.0, potassium: 120.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: preserved-eggplant products vary by preparation and oil ratio.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 12], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "grilled_peppers_jar",
            en: "Jarred grilled peppers",
            it: "Peperoni grigliati in vasetto",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 48, protein: 1.1, carbs: 5.0, fat: 2.5, fiber: 2.2, vitaminC: 35.0, potassium: 140.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: jarred grilled peppers vary by oil and marinade.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 25], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: true)
        ),

        // Priority family 3: frozen family
        make(
            id: "frozen_peas",
            en: "Frozen peas",
            it: "Piselli surgelati",
            category: .legumes,
            nutrition: ProduceNutrition(calories: 84, protein: 5.4, carbs: 15.0, fat: 0.4, fiber: 5.5, vitaminC: 14.0, potassium: 271.0),
            nutritionReference: "USDA FDC: Peas, green, frozen, unprepared",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 11], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "frozen_spinach",
            en: "Frozen spinach",
            it: "Spinaci surgelati",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 23, protein: 3.8, carbs: 3.8, fat: 0.3, fiber: 2.5, vitaminC: 12.0, potassium: 390.0),
            nutritionReference: "USDA FDC: Spinach, frozen, unprepared",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 100], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "frozen_broccoli",
            en: "Frozen broccoli",
            it: "Broccoli surgelati",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 34, protein: 2.8, carbs: 7.0, fat: 0.4, fiber: 3.0, vitaminC: 65.0, potassium: 293.0),
            nutritionReference: "USDA FDC: Broccoli, frozen, unprepared",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 80], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "frozen_minestrone",
            en: "Frozen minestrone mix",
            it: "Minestrone surgelato",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 45, protein: 2.1, carbs: 7.2, fat: 0.7, fiber: 2.8, vitaminC: 12.0, potassium: 210.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: minestrone mixes vary by vegetable and legume composition.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g], gramsPerUnit: [.g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "frozen_green_beans",
            en: "Frozen green beans",
            it: "Fagiolini surgelati",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 31, protein: 1.8, carbs: 7.0, fat: 0.1, fiber: 3.4, vitaminC: 12.0, potassium: 209.0),
            nutritionReference: "USDA FDC: Beans, snap, green, frozen, unprepared",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g], gramsPerUnit: [.g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "frozen_shrimp",
            en: "Frozen shrimp",
            it: "Gamberi surgelati",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 91, protein: 20.0, carbs: 0.2, fat: 1.2, fiber: 0.0, vitaminC: 0.0, potassium: 259.0),
            nutritionReference: "USDA FDC: Crustaceans, shrimp, frozen, unprepared",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 12], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "frozen_fish_fillets",
            en: "Frozen fish fillets",
            it: "Filetti di pesce surgelati",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 95, protein: 19.0, carbs: 0.0, fat: 1.8, fiber: 0.0, vitaminC: 0.0, potassium: 360.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: frozen fish fillets vary by species and breading.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 150], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "frozen_chicken_breast",
            en: "Frozen chicken breast",
            it: "Petto di pollo surgelato",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 120, protein: 23.0, carbs: 0.0, fat: 2.6, fiber: 0.0, vitaminC: 0.0, potassium: 250.0),
            nutritionReference: "USDA FDC: Chicken breast, frozen, raw",
            nutritionMappingNote: "Mapped to frozen raw chicken breast profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 120], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: false, isVegan: false)
        ),
        make(
            id: "frozen_pizza",
            en: "Frozen pizza",
            it: "Pizza surgelata",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 260, protein: 10.0, carbs: 31.0, fat: 10.0, fiber: 2.0, vitaminC: 1.0, potassium: 180.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: frozen pizzas vary significantly by toppings and dough.",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 350, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: nil, isVegan: nil)
        ),
        make(
            id: "frozen_potatoes",
            en: "Frozen potatoes",
            it: "Patate surgelate",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 150, protein: 2.8, carbs: 26.0, fat: 4.5, fiber: 3.0, vitaminC: 4.0, potassium: 380.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: frozen potatoes vary by cut and pre-frying process.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g], gramsPerUnit: [.g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: true)
        ),

        // Priority family 4: breakfast
        make(
            id: "granola",
            en: "Granola",
            it: "Granola",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 471, protein: 10.0, carbs: 64.0, fat: 20.0, fiber: 6.0, vitaminC: 0.0, potassium: 350.0),
            nutritionReference: "USDA FDC: Cereal, granola, homemade",
            nutritionMappingNote: "Granola compositions vary by nuts, oils, and sweeteners.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 8], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: nil)
        ),
        make(
            id: "muesli",
            en: "Muesli",
            it: "Muesli",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 370, protein: 11.0, carbs: 64.0, fat: 8.0, fiber: 8.0, vitaminC: 0.0, potassium: 360.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: muesli blends vary by grains and dried fruit content.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 8], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "corn_flakes",
            en: "Corn flakes",
            it: "Corn flakes",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 357, protein: 7.5, carbs: 84.0, fat: 0.4, fiber: 3.0, vitaminC: 0.0, potassium: 120.0),
            nutritionReference: "USDA FDC: Cereals ready-to-eat, corn flakes, plain",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 2.5], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "rusks",
            en: "Rusks",
            it: "Fette biscottate",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 400, protein: 11.0, carbs: 74.0, fat: 6.0, fiber: 4.0, vitaminC: 0.0, potassium: 150.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: rusks vary by flour blend and added fats.",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 11, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "jam",
            en: "Jam",
            it: "Marmellata",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 250, protein: 0.3, carbs: 65.0, fat: 0.1, fiber: 0.7, vitaminC: 1.0, potassium: 45.0),
            nutritionReference: "USDA FDC: Jam, preserves, fruit, low sugar",
            nutritionMappingNote: "Mapped to generic fruit jam preserve profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .tbsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 20, .tsp: 7], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "chocolate_spread",
            en: "Chocolate spread",
            it: "Crema spalmabile",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 539, protein: 6.0, carbs: 57.0, fat: 31.0, fiber: 4.0, vitaminC: 0.0, potassium: 300.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: cocoa-hazelnut spreads vary by sugar and fat content.",
            unitProfile: IngredientUnitProfile(defaultUnit: .tbsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 15, .tsp: 5], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: nil)
        ),
        make(
            id: "pancake_mix",
            en: "Pancake mix",
            it: "Preparato per pancake",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 360, protein: 8.0, carbs: 72.0, fat: 3.5, fiber: 2.2, vitaminC: 0.0, potassium: 160.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: pancake mixes differ by recipe and added sugars.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 8], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: nil)
        ),
        make(
            id: "breakfast_biscuits",
            en: "Breakfast biscuits",
            it: "Biscotti da colazione",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 440, protein: 7.0, carbs: 70.0, fat: 14.0, fiber: 3.0, vitaminC: 0.0, potassium: 180.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: breakfast biscuits vary by grain and fat content.",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 12, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: nil)
        ),

        // Priority family 5: beverages
        make(
            id: "sparkling_water",
            en: "Sparkling water",
            it: "Acqua frizzante",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 0, protein: 0.0, carbs: 0.0, fat: 0.0, fiber: 0.0, vitaminC: 0.0, potassium: 0.0),
            nutritionReference: "USDA FDC: Water, carbonated, unsweetened",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml], gramsPerUnit: [:], mlPerUnit: [.ml: 1], gramsPerMl: 1.0),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "orange_juice",
            en: "Orange juice",
            it: "Succo d'arancia",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 45, protein: 0.7, carbs: 10.4, fat: 0.2, fiber: 0.2, vitaminC: 50.0, potassium: 200.0),
            nutritionReference: "USDA FDC: Orange juice, chilled, includes from concentrate",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .tbsp, .tsp], gramsPerUnit: [:], mlPerUnit: [.ml: 1, .tbsp: 15, .tsp: 5], gramsPerMl: 1.04),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "apple_juice",
            en: "Apple juice",
            it: "Succo di mela",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 46, protein: 0.1, carbs: 11.3, fat: 0.1, fiber: 0.2, vitaminC: 0.9, potassium: 101.0),
            nutritionReference: "USDA FDC: Apple juice, canned or bottled, unsweetened",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .tbsp, .tsp], gramsPerUnit: [:], mlPerUnit: [.ml: 1, .tbsp: 15, .tsp: 5], gramsPerMl: 1.04),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "cola",
            en: "Cola",
            it: "Cola",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 42, protein: 0.0, carbs: 10.6, fat: 0.0, fiber: 0.0, vitaminC: 0.0, potassium: 1.0),
            nutritionReference: "USDA FDC: Carbonated beverage, cola, regular",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml], gramsPerUnit: [:], mlPerUnit: [.ml: 1], gramsPerMl: 1.04),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "black_tea",
            en: "Black tea",
            it: "Te nero",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 1, protein: 0.0, carbs: 0.3, fat: 0.0, fiber: 0.0, vitaminC: 0.0, potassium: 37.0),
            nutritionReference: "USDA FDC: Tea, black, brewed, prepared with tap water",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml], gramsPerUnit: [:], mlPerUnit: [.ml: 1], gramsPerMl: 1.0),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "green_tea",
            en: "Green tea",
            it: "Te verde",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 1, protein: 0.2, carbs: 0.0, fat: 0.0, fiber: 0.0, vitaminC: 0.0, potassium: 8.0),
            nutritionReference: "USDA FDC: Tea, green, brewed, prepared with tap water",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml], gramsPerUnit: [:], mlPerUnit: [.ml: 1], gramsPerMl: 1.0),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "ground_coffee",
            en: "Ground coffee",
            it: "Caffe macinato",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 2, protein: 0.1, carbs: 0.0, fat: 0.0, fiber: 0.0, vitaminC: 0.0, potassium: 49.0),
            nutritionReference: "USDA FDC: Coffee, brewed from grounds, prepared with tap water",
            nutritionMappingNote: "Ground coffee mapped to brewed beverage profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .tsp, supportedUnits: [.g, .tsp, .tbsp], gramsPerUnit: [.g: 1, .tsp: 2, .tbsp: 6], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "instant_coffee",
            en: "Instant coffee",
            it: "Caffe solubile",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 353, protein: 12.2, carbs: 75.4, fat: 0.5, fiber: 0.0, vitaminC: 0.0, potassium: 3535.0),
            nutritionReference: "USDA FDC: Coffee, instant, regular, powder",
            unitProfile: IngredientUnitProfile(defaultUnit: .tsp, supportedUnits: [.g, .tsp], gramsPerUnit: [.g: 1, .tsp: 2], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),

        // Priority family 6: ready meals / convenience
        make(
            id: "ready_soup",
            en: "Ready-to-eat soup",
            it: "Zuppa pronta",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 48, protein: 1.8, carbs: 6.0, fat: 1.8, fiber: 1.2, vitaminC: 2.0, potassium: 120.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: ready soups vary by recipe and brand.",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .g], gramsPerUnit: [.g: 1], mlPerUnit: [.ml: 1], gramsPerMl: 1.02),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: nil, isVegan: nil)
        ),
        make(
            id: "ready_veloute",
            en: "Ready-to-eat veloute",
            it: "Vellutata pronta",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 55, protein: 1.9, carbs: 7.1, fat: 2.2, fiber: 1.5, vitaminC: 2.0, potassium: 150.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: ready veloute soups vary by ingredients and added cream.",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .g], gramsPerUnit: [.g: 1], mlPerUnit: [.ml: 1], gramsPerMl: 1.03),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: nil, isVegan: nil)
        ),
        make(
            id: "ready_salad",
            en: "Ready-to-eat salad",
            it: "Insalata pronta",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 20, protein: 1.2, carbs: 2.8, fat: 0.3, fiber: 1.6, vitaminC: 8.0, potassium: 180.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: ready salad mixes vary by leaf blend.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g], gramsPerUnit: [.g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "ready_rice",
            en: "Ready rice",
            it: "Riso pronto",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 145, protein: 3.0, carbs: 30.0, fat: 1.0, fiber: 1.0, vitaminC: 0.0, potassium: 35.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: ready rice products vary by seasoning and oil.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 250], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: nil, isVegan: nil)
        ),
        make(
            id: "packaged_sushi",
            en: "Ready-to-eat sushi",
            it: "Sushi confezionato",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 155, protein: 5.5, carbs: 27.0, fat: 2.7, fiber: 1.1, vitaminC: 1.0, potassium: 120.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: ready-to-eat sushi varies by fillings and sauces.",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 28, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: nil, isVegan: nil)
        ),
        make(
            id: "triangle_sandwich",
            en: "Ready-to-eat sandwich",
            it: "Tramezzino",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 250, protein: 9.0, carbs: 28.0, fat: 11.0, fiber: 2.0, vitaminC: 0.0, potassium: 180.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: tramezzino profiles are brand and filling dependent.",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 120, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: nil, isVegan: nil)
        ),
        make(
            id: "packaged_panino",
            en: "Ready-to-eat panino",
            it: "Panino confezionato",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 275, protein: 11.0, carbs: 31.0, fat: 11.5, fiber: 2.2, vitaminC: 0.0, potassium: 200.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: ready-to-eat panini vary strongly by fillings.",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 150, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: nil, isVegan: nil)
        ),
        make(
            id: "stuffed_piadina",
            en: "Ready-to-eat stuffed piadina",
            it: "Piadina farcita",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 285, protein: 10.0, carbs: 30.0, fat: 13.0, fiber: 2.0, vitaminC: 0.0, potassium: 210.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: stuffed piadina values depend on fillings.",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 180, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: nil, isVegan: nil)
        ),

        // Priority family 7: international pantry
        make(
            id: "noodles",
            en: "Noodles",
            it: "Noodles",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 470, protein: 9.5, carbs: 60.0, fat: 22.0, fiber: 3.0, vitaminC: 0.0, potassium: 150.0),
            nutritionReference: "USDA FDC: Noodles, egg, dry, enriched",
            nutritionMappingNote: "Noodles can vary by flour and pre-frying process.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 70], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: nil)
        ),
        make(
            id: "instant_ramen",
            en: "Instant ramen",
            it: "Ramen istantaneo",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 436, protein: 9.0, carbs: 62.0, fat: 17.0, fiber: 2.9, vitaminC: 0.0, potassium: 170.0),
            nutritionReference: "USDA FDC: Noodles, japanese, soba, dry",
            nutritionMappingNote: "Instant ramen mapped to dry noodle profile; seasoning packets vary.",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 85, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: nil, isVegan: nil)
        ),
        make(
            id: "miso_paste",
            en: "Miso paste",
            it: "Miso",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 199, protein: 12.0, carbs: 26.0, fat: 6.0, fiber: 5.0, vitaminC: 0.0, potassium: 210.0),
            nutritionReference: "USDA FDC: Soybean paste",
            nutritionMappingNote: "Miso mapped to fermented soybean paste profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .tbsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 17, .tsp: 6], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "panko",
            en: "Panko",
            it: "Panko",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 365, protein: 13.0, carbs: 72.0, fat: 4.0, fiber: 4.0, vitaminC: 0.0, potassium: 180.0),
            nutritionReference: "USDA FDC: Bread crumbs, panko style",
            nutritionMappingNote: "Mapped to panko-style breadcrumb profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 4], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: false, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "curry_paste",
            en: "Curry paste",
            it: "Pasta di curry",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 110, protein: 2.0, carbs: 12.0, fat: 6.0, fiber: 2.0, vitaminC: 5.0, potassium: 220.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: curry pastes vary widely by style and ingredients.",
            unitProfile: IngredientUnitProfile(defaultUnit: .tbsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 15, .tsp: 5], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: nil, isVegan: nil)
        ),
        make(
            id: "jalapenos_pickled",
            en: "Pickled jalapenos",
            it: "Jalapenos",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 27, protein: 0.9, carbs: 5.7, fat: 0.4, fiber: 2.8, vitaminC: 12.0, potassium: 150.0),
            nutritionReference: "USDA FDC: Peppers, jalapeno, canned",
            nutritionMappingNote: "Mapped to canned jalapeno peppers profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 8], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "harissa",
            en: "Harissa",
            it: "Harissa",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 170, protein: 4.0, carbs: 12.0, fat: 12.0, fiber: 4.0, vitaminC: 10.0, potassium: 260.0),
            nutritionReference: nil,
            nutritionMappingNote: "Unmapped: harissa products vary by pepper and oil ratio.",
            unitProfile: IngredientUnitProfile(defaultUnit: .tbsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 15, .tsp: 5], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: nil, isVegetarian: true, isVegan: true)
        ),

        // Expanded plant proteins, nuts, seeds, and extras
        make(
            id: "tofu",
            en: "Tofu",
            it: "Tofu",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 76, protein: 8.1, carbs: 1.9, fat: 4.8, fiber: 0.3, vitaminC: 0.1, potassium: 121.0),
            nutritionReference: "USDA FDC: Tofu, raw, regular, prepared with calcium sulfate",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 100], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "tempeh",
            en: "Tempeh",
            it: "Tempeh",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 192, protein: 20.3, carbs: 7.6, fat: 10.8, fiber: 1.4, vitaminC: 0.0, potassium: 412.0),
            nutritionReference: "USDA FDC: Tempeh",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 100], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "seitan",
            en: "Seitan",
            it: "Seitan",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 143, protein: 24.0, carbs: 4.0, fat: 2.0, fiber: 0.6, vitaminC: 0.0, potassium: 58.0),
            nutritionReference: "USDA FDC: Meat substitute, wheat protein (seitan), prepared",
            nutritionMappingNote: "Seitan mapped to wheat gluten meat substitute profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 90], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: false, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "almonds",
            en: "Almonds",
            it: "Mandorle",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 579, protein: 21.2, carbs: 21.6, fat: 49.9, fiber: 12.5, vitaminC: 0.0, potassium: 733.0),
            nutritionReference: "USDA FDC: Nuts, almonds",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece, .tbsp], gramsPerUnit: [.g: 1, .piece: 1.2, .tbsp: 9], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "walnuts",
            en: "Walnuts",
            it: "Noci",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 654, protein: 15.2, carbs: 13.7, fat: 65.2, fiber: 6.7, vitaminC: 1.3, potassium: 441.0),
            nutritionReference: "USDA FDC: Nuts, walnuts, english",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece, .tbsp], gramsPerUnit: [.g: 1, .piece: 2.0, .tbsp: 7], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "hazelnuts",
            en: "Hazelnuts",
            it: "Nocciole",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 628, protein: 15.0, carbs: 16.7, fat: 60.8, fiber: 9.7, vitaminC: 6.3, potassium: 680.0),
            nutritionReference: "USDA FDC: Nuts, hazelnuts or filberts",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece, .tbsp], gramsPerUnit: [.g: 1, .piece: 1.3, .tbsp: 9], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "pumpkin_seeds",
            en: "Pumpkin seeds",
            it: "Semi di zucca",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 559, protein: 30.2, carbs: 10.7, fat: 49.0, fiber: 6.0, vitaminC: 1.9, potassium: 809.0),
            nutritionReference: "USDA FDC: Seeds, pumpkin and squash seed kernels, dried",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 10, .tsp: 3], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "chia_seeds",
            en: "Chia seeds",
            it: "Semi di chia",
            category: .proteins,
            nutrition: ProduceNutrition(calories: 486, protein: 16.5, carbs: 42.1, fat: 30.7, fiber: 34.4, vitaminC: 1.6, potassium: 407.0),
            nutritionReference: "USDA FDC: Seeds, chia seeds, dried",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 12, .tsp: 4], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "cottage_cheese",
            en: "Cottage cheese",
            it: "Fiocchi di latte",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 98, protein: 11.1, carbs: 3.4, fat: 4.3, fiber: 0.0, vitaminC: 0.0, potassium: 104.0),
            nutritionReference: "USDA FDC: Cheese, cottage, lowfat, 2% milkfat",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 14], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "scamorza",
            en: "Scamorza",
            it: "Scamorza",
            category: .dairy,
            nutrition: ProduceNutrition(calories: 334, protein: 25.0, carbs: 1.0, fat: 26.0, fiber: 0.0, vitaminC: 0.0, potassium: 120.0),
            nutritionReference: "USDA FDC: Cheese, provolone",
            nutritionMappingNote: "Scamorza mapped to stretched-curd semi-hard cheese profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .piece], gramsPerUnit: [.g: 1, .piece: 120], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: false)
        ),
        make(
            id: "bulgur",
            en: "Bulgur",
            it: "Bulgur",
            category: .carbs,
            nutrition: ProduceNutrition(calories: 342, protein: 12.3, carbs: 75.9, fat: 1.3, fiber: 18.3, vitaminC: 0.0, potassium: 410.0),
            nutritionReference: "USDA FDC: Bulgur, dry",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp], gramsPerUnit: [.g: 1, .tbsp: 12], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: false, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "coconut_oil",
            en: "Coconut oil",
            it: "Olio di cocco",
            category: .pantry,
            nutrition: ProduceNutrition(calories: 892, protein: 0.0, carbs: 0.0, fat: 100.0, fiber: 0.0, vitaminC: 0.0, potassium: 0.0),
            nutritionReference: "USDA FDC: Oil, coconut",
            unitProfile: IngredientUnitProfile(defaultUnit: .ml, supportedUnits: [.ml, .tbsp, .tsp, .g], gramsPerUnit: [.g: 1, .tbsp: 13.6, .tsp: 4.5], mlPerUnit: [.ml: 1, .tbsp: 15, .tsp: 5], gramsPerMl: 0.92),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "tahini",
            en: "Tahini",
            it: "Tahina",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 595, protein: 17.0, carbs: 21.2, fat: 53.8, fiber: 9.3, vitaminC: 0.0, potassium: 414.0),
            nutritionReference: "USDA FDC: Tahini, sesame butter, from kernels",
            unitProfile: IngredientUnitProfile(defaultUnit: .tbsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 15, .tsp: 5], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "tomato_paste",
            en: "Tomato paste",
            it: "Concentrato di pomodoro",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 82, protein: 4.3, carbs: 19.1, fat: 0.5, fiber: 4.1, vitaminC: 22.0, potassium: 1014.0),
            nutritionReference: "USDA FDC: Tomato products, canned, paste, without salt added",
            unitProfile: IngredientUnitProfile(defaultUnit: .g, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 16, .tsp: 5], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "bay_leaf",
            en: "Bay leaf",
            it: "Alloro",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 313, protein: 7.6, carbs: 74.9, fat: 8.4, fiber: 26.3, vitaminC: 46.5, potassium: 529.0),
            nutritionReference: "USDA FDC: Spices, bay leaf",
            nutritionMappingNote: "Fresh bay leaf mapped to dried bay leaf profile.",
            unitProfile: IngredientUnitProfile(defaultUnit: .piece, supportedUnits: [.piece, .g], gramsPerUnit: [.piece: 0.5, .g: 1], mlPerUnit: [:], gramsPerMl: nil),
            dietary: BasicIngredientDietaryFlags(isGlutenFree: true, isVegetarian: true, isVegan: true)
        ),
        make(
            id: "nutmeg",
            en: "Nutmeg",
            it: "Noce moscata",
            category: .condiments,
            nutrition: ProduceNutrition(calories: 525, protein: 5.8, carbs: 49.3, fat: 36.3, fiber: 20.8, vitaminC: 3.0, potassium: 350.0),
            nutritionReference: "USDA FDC: Spices, nutmeg, ground",
            unitProfile: IngredientUnitProfile(defaultUnit: .tsp, supportedUnits: [.g, .tbsp, .tsp], gramsPerUnit: [.g: 1, .tbsp: 7, .tsp: 2.2], mlPerUnit: [:], gramsPerMl: nil),
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
        let confidence: NutritionMappingConfidence
        if nutritionReference == nil {
            confidence = .unmapped
        } else if nutritionMappingNote != nil {
            confidence = .approximate
        } else {
            confidence = .high
        }

        return BasicIngredient(
            id: id,
            localizedNames: ["en": en, "it": it],
            category: category,
            ingredientQualityLevel: .basic,
            nutrition: nutrition,
            nutritionSource: "USDA FoodData Central",
            nutritionBasis: .per100g,
            nutritionReference: nutritionReference,
            nutritionMappingNote: nutritionMappingNote,
            nutritionMappingConfidence: confidence,
            unitProfile: unitProfile,
            dietaryFlags: dietary
        )
    }
}
