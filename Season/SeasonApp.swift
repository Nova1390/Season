//
//  SeasonApp.swift
//  Season
//
//  Created by Rocco D'Affuso on 17/03/26.
//

import SwiftUI

@main
struct SeasonApp: App {
    var body: some Scene {
        WindowGroup {
            AuthGateView()
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
