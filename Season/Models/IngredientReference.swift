import Foundation

struct IngredientReference: Identifiable, Hashable, Codable {
    enum IngredientType: String, Codable, Hashable {
        case produce
        case basic
        case catalog
        case custom
    }

    let id: String
    let type: IngredientType
    let ingredientID: String?
    let produceID: String?
    let name: String
    let isCustom: Bool

    init(
        id: String,
        type: IngredientType,
        ingredientID: String? = nil,
        produceID: String?,
        name: String,
        isCustom: Bool
    ) {
        self.id = id
        self.type = type
        self.ingredientID = ingredientID
        self.produceID = produceID
        self.name = name
        self.isCustom = isCustom
    }
}

extension IngredientReference {
    static func fromFridgeProduceID(_ produceID: String, name: String) -> IngredientReference {
        IngredientReference(
            id: "produce:\(produceID)",
            type: .produce,
            ingredientID: nil,
            produceID: produceID,
            name: name,
            isCustom: false
        )
    }

    static func fromFridgeBasicID(_ basicID: String, name: String) -> IngredientReference {
        IngredientReference(
            id: "basic:\(basicID)",
            type: .basic,
            ingredientID: nil,
            produceID: nil,
            name: name,
            isCustom: false
        )
    }
}

extension RecipeIngredient {
    var ingredientReference: IngredientReference {
        if let ingredientID, !ingredientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let normalizedID = ingredientID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return IngredientReference(
                id: "ingredient:\(normalizedID)",
                type: .catalog,
                ingredientID: normalizedID,
                produceID: nil,
                name: name,
                isCustom: false
            )
        }

        if let produceID, !produceID.isEmpty {
            return IngredientReference(
                id: "produce:\(produceID)",
                type: .produce,
                ingredientID: nil,
                produceID: produceID,
                name: name,
                isCustom: false
            )
        }

        if let basicIngredientID, !basicIngredientID.isEmpty {
            return IngredientReference(
                id: "basic:\(basicIngredientID)",
                type: .basic,
                ingredientID: nil,
                produceID: nil,
                name: name,
                isCustom: false
            )
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let stableName = trimmed.isEmpty ? "custom" : trimmed.lowercased()
        return IngredientReference(
            id: "custom:\(stableName)",
            type: .custom,
            ingredientID: nil,
            produceID: nil,
            name: trimmed.isEmpty ? name : trimmed,
            isCustom: true
        )
    }
}

extension ShoppingListEntry {
    var ingredientReference: IngredientReference {
        if let produceID, !produceID.isEmpty {
            return IngredientReference(
                id: id,
                type: .produce,
                ingredientID: nil,
                produceID: produceID,
                name: name,
                isCustom: false
            )
        }

        if let basicIngredientID, !basicIngredientID.isEmpty {
            return IngredientReference(
                id: id,
                type: .basic,
                ingredientID: nil,
                produceID: nil,
                name: name,
                isCustom: false
            )
        }

        if let ingredientID, !ingredientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let normalizedID = ingredientID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return IngredientReference(
                id: id,
                type: .catalog,
                ingredientID: normalizedID,
                produceID: nil,
                name: name,
                isCustom: false
            )
        }

        return IngredientReference(
            id: id,
            type: .custom,
            ingredientID: nil,
            produceID: nil,
            name: name,
            isCustom: true
        )
    }
}

extension ProduceItem {
    func ingredientReference(languageCode: String = "en") -> IngredientReference {
        IngredientReference(
            id: "produce:\(id)",
            type: .produce,
            ingredientID: nil,
            produceID: id,
            name: displayName(languageCode: languageCode),
            isCustom: false
        )
    }
}

extension BasicIngredient {
    func ingredientReference(languageCode: String = "en") -> IngredientReference {
        IngredientReference(
            id: "basic:\(id)",
            type: .basic,
            ingredientID: nil,
            produceID: nil,
            name: displayName(languageCode: languageCode),
            isCustom: false
        )
    }
}

extension FridgeCustomItem {
    var ingredientReference: IngredientReference {
        IngredientReference(
            id: id,
            type: .custom,
            ingredientID: nil,
            produceID: nil,
            name: name,
            isCustom: true
        )
    }
}

extension FridgeCatalogItem {
    var ingredientReference: IngredientReference {
        IngredientReference(
            id: id,
            type: .catalog,
            ingredientID: ingredientID,
            produceID: nil,
            name: name,
            isCustom: false
        )
    }
}
