import Foundation

enum AdminAccessControl {
    static func fetchIsCurrentUserAdmin(
        supabaseService: SupabaseService
    ) async -> Bool {
        let isAdmin = await supabaseService.isCurrentUserCatalogAdmin()
        SeasonLog.debug("[SEASON_CATALOG_ADMIN] phase=admin_access_control_result is_admin=\(isAdmin)")
        return isAdmin
    }
}
