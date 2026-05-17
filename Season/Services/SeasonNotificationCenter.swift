import Foundation

enum SeasonNotificationCenter {
    static func notifications(
        produceViewModel: ProduceViewModel,
        fridgeViewModel: FridgeViewModel,
        shoppingListViewModel: ShoppingListViewModel,
        socialNotifications: [SeasonInboxNotification] = []
    ) -> [SeasonInboxNotification] {
        var items: [SeasonInboxNotification] = []
        let languageCode = produceViewModel.localizer.languageCode

        items.append(contentsOf: socialNotifications)

        if let seasonal = seasonalNotification(
            produceViewModel: produceViewModel,
            languageCode: languageCode
        ) {
            items.append(seasonal)
        }

        if let shopping = shoppingListNotification(
            count: shoppingListViewModel.items.count,
            languageCode: languageCode
        ) {
            items.append(shopping)
        }

        if let fridge = fridgeNotification(
            count: fridgeViewModel.allItemCount,
            languageCode: languageCode
        ) {
            items.append(fridge)
        }

        return items
    }

    private static func seasonalNotification(
        produceViewModel: ProduceViewModel,
        languageCode: String
    ) -> SeasonInboxNotification? {
        guard let topPick = produceViewModel.bestPicksToday(limit: 1).first else { return nil }
        let itemName = topPick.item.displayName(languageCode: languageCode)
        let month = produceViewModel.currentMonthName.lowercased()
        let title = localized(
            it: "\(itemName) è al meglio ora",
            en: "\(itemName) is at its best now",
            languageCode: languageCode
        )
        let body = localized(
            it: "È tra gli ingredienti più interessanti di \(month): apri Oggi per abbinarlo bene.",
            en: "It is one of the strongest seasonal picks for \(month): open Today to pair it well.",
            languageCode: languageCode
        )

        return SeasonInboxNotification(
            id: "seasonal:\(topPick.item.id):\(produceViewModel.currentMonth)",
            kind: .seasonalPeak,
            title: title,
            body: body,
            systemImage: "leaf",
            destination: .today,
            createdAt: Date()
        )
    }

    private static func shoppingListNotification(
        count: Int,
        languageCode: String
    ) -> SeasonInboxNotification? {
        guard count > 0 else { return nil }
        let title = localized(
            it: "Lista della spesa pronta",
            en: "Shopping list ready",
            languageCode: languageCode
        )
        let body = localized(
            it: count == 1 ? "Hai 1 ingrediente da controllare prima di cucinare." : "Hai \(count) ingredienti da controllare prima di cucinare.",
            en: count == 1 ? "You have 1 ingredient to check before cooking." : "You have \(count) ingredients to check before cooking.",
            languageCode: languageCode
        )

        return SeasonInboxNotification(
            id: "shopping-list:\(count)",
            kind: .shoppingList,
            title: title,
            body: body,
            systemImage: "bag",
            destination: .shoppingList,
            createdAt: Date()
        )
    }

    private static func fridgeNotification(
        count: Int,
        languageCode: String
    ) -> SeasonInboxNotification? {
        guard count < 3 else { return nil }

        let title = localized(
            it: count == 0 ? "Il frigo è vuoto" : "Pochi ingredienti nel frigo",
            en: count == 0 ? "Your fridge is empty" : "Your fridge is running low",
            languageCode: languageCode
        )
        let body = localized(
            it: count == 0 ? "Aggiungi ciò che hai in casa per ricevere ricette più precise." : "Aggiungi qualche ingrediente in più per migliorare i suggerimenti.",
            en: count == 0 ? "Add what you have at home to unlock better recipe suggestions." : "Add a few more ingredients to improve recommendations.",
            languageCode: languageCode
        )

        return SeasonInboxNotification(
            id: "fridge-count:\(count)",
            kind: .fridgeSetup,
            title: title,
            body: body,
            systemImage: "snowflake",
            destination: .fridge,
            createdAt: Date()
        )
    }

    private static func localized(it: String, en: String, languageCode: String) -> String {
        languageCode.lowercased().hasPrefix("it") ? it : en
    }
}
