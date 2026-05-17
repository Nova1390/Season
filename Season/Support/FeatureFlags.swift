enum FeatureFlags {
    static let appleAuthenticationEnabled = true

    #if DEBUG
    static let googleAuthenticationEnabled = true
    #else
    static let googleAuthenticationEnabled = false
    #endif
}
