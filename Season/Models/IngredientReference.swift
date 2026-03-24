import Foundation

struct IngredientReference: Identifiable, Hashable, Codable {
    enum IngredientType: String, Codable, Hashable {
        case produce
        case basic
        case custom
    }

    let id: String
    let type: IngredientType
    let produceID: String?
    let name: String
    let isCustom: Bool

    init(
        id: String,
        type: IngredientType,
        produceID: String?,
        name: String,
        isCustom: Bool
    ) {
        self.id = id
        self.type = type
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
            produceID: produceID,
            name: name,
            isCustom: false
        )
    }

    static func fromFridgeBasicID(_ basicID: String, name: String) -> IngredientReference {
        IngredientReference(
            id: "basic:\(basicID)",
            type: .basic,
            produceID: nil,
            name: name,
            isCustom: false
        )
    }
}

extension RecipeIngredient {
    var ingredientReference: IngredientReference {
        if let produceID, !produceID.isEmpty {
            return IngredientReference(
                id: "produce:\(produceID)",
                type: .produce,
                produceID: produceID,
                name: name,
                isCustom: false
            )
        }

        if let basicIngredientID, !basicIngredientID.isEmpty {
            return IngredientReference(
                id: "basic:\(basicIngredientID)",
                type: .basic,
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
                produceID: produceID,
                name: name,
                isCustom: false
            )
        }

        if let basicIngredientID, !basicIngredientID.isEmpty {
            return IngredientReference(
                id: id,
                type: .basic,
                produceID: nil,
                name: name,
                isCustom: false
            )
        }

        return IngredientReference(
            id: id,
            type: .custom,
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
            produceID: nil,
            name: name,
            isCustom: true
        )
    }
}
