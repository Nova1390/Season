//
//  SeasonApp.swift
//  Season
//
//  Created by Rocco D'Affuso on 17/03/26.
//

import SwiftUI

@main
struct SeasonApp: App {
    init() {
        DS.Font.logRegistrationStatus()
    }

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .onOpenURL { url in
                    SupabaseService.shared.handleAuthCallbackURL(url)
                }
                .task {
                    #if DEBUG
                    await runSmartImportBatchAuditIfRequested()
                    await CreateRecipeView.runSmartImportCaptionHarnessIfRequested()
                    await CreateRecipeView.runSmartImportRealFlowAuditIfRequested()
                    await CreateRecipeView.runSmartImportSpecificityAuditIfRequested()
                    #endif
                }
        }
    }
}
