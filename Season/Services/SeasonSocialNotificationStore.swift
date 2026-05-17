import Foundation
import Combine

@MainActor
final class SeasonSocialNotificationStore: ObservableObject {
    static let shared = SeasonSocialNotificationStore(supabaseService: SupabaseService.shared)

    @Published private(set) var notifications: [SeasonInboxNotification] = []

    private let supabaseService: SupabaseService
    private var lastRefreshAt: Date?
    private var refreshInProgress = false

    private init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    func refreshIfNeeded(
        produceViewModel: ProduceViewModel,
        force: Bool = false
    ) async {
        guard !refreshInProgress else { return }
        if !force,
           let lastRefreshAt,
           Date().timeIntervalSince(lastRefreshAt) < 90 {
            return
        }

        guard let currentUserID = supabaseService.currentAuthenticatedUserID()?.uuidString.lowercased() else {
            notifications = []
            return
        }

        refreshInProgress = true
        defer {
            refreshInProgress = false
            lastRefreshAt = Date()
        }

        let ownedRecipes = produceViewModel.recipes.filter { recipe in
            recipe.canonicalCreatorID?.lowercased() == currentUserID
        }

        let signals = await supabaseService.fetchSocialNotificationSignals(
            currentUserID: currentUserID,
            ownedRecipes: ownedRecipes
        )

        notifications = buildNotifications(
            followerSignals: signals.followers,
            crispySignals: signals.crispies,
            languageCode: produceViewModel.localizer.languageCode
        )
    }

    private func buildNotifications(
        followerSignals: [SeasonFollowerNotificationSignal],
        crispySignals: [SeasonRecipeCrispyNotificationSignal],
        languageCode: String
    ) -> [SeasonInboxNotification] {
        var result: [SeasonInboxNotification] = []

        if let latestFollower = followerSignals.sorted(by: { $0.createdAt > $1.createdAt }).first {
            let count = followerSignals.count
            let title = localized(
                it: count == 1 ? "Hai un nuovo follower" : "Hai \(count) nuovi follower",
                en: count == 1 ? "You have a new follower" : "You have \(count) new followers",
                languageCode: languageCode
            )
            let body = localized(
                it: "Qualcuno ha iniziato a seguire il tuo profilo Season.",
                en: "Someone started following your Season profile.",
                languageCode: languageCode
            )
            result.append(
                SeasonInboxNotification(
                    id: "social:follower:\(count):\(Int(latestFollower.createdAt.timeIntervalSince1970))",
                    kind: .newFollower,
                    title: title,
                    body: body,
                    systemImage: "person.crop.circle.badge.plus",
                    destination: .none,
                    createdAt: latestFollower.createdAt
                )
            )
        }

        result.append(contentsOf: crispySignals.map { signal in
            let title = localized(
                it: "Nuovo crispy su una tua ricetta",
                en: "New crispy on your recipe",
                languageCode: languageCode
            )
            let body = localized(
                it: signal.count == 1 ? "\"\(signal.recipeTitle)\" ha ricevuto 1 crispy." : "\"\(signal.recipeTitle)\" ha ricevuto \(signal.count) crispy.",
                en: signal.count == 1 ? "\"\(signal.recipeTitle)\" received 1 crispy." : "\"\(signal.recipeTitle)\" received \(signal.count) crispies.",
                languageCode: languageCode
            )

            return SeasonInboxNotification(
                id: "social:crispy:\(signal.recipeID):\(signal.count):\(Int(signal.latestAt.timeIntervalSince1970))",
                kind: .recipeCrispied,
                title: title,
                body: body,
                systemImage: "flame",
                destination: .recipe(signal.recipeID),
                createdAt: signal.latestAt
            )
        })

        return result.sorted { $0.createdAt > $1.createdAt }
    }

    private func localized(it: String, en: String, languageCode: String) -> String {
        languageCode.lowercased().hasPrefix("it") ? it : en
    }
}
