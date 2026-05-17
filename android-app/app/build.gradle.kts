plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

fun secretOrEmpty(name: String): String {
    return providers
        .gradleProperty(name)
        .orElse(providers.environmentVariable(name))
        .orElse("")
        .get()
}

android {
    namespace = "it.seasonapp.season"
    compileSdk = 36

    defaultConfig {
        applicationId = "it.seasonapp.season"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }

    buildFeatures {
        buildConfig = true
        compose = true
    }

    buildTypes {
        getByName("debug") {
            isDebuggable = true
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            buildConfigField("String", "SEASON_ENVIRONMENT", "\"local-debug\"")
            buildConfigField("String", "SEASON_SUPABASE_URL", "\"\"")
            buildConfigField("String", "SEASON_SUPABASE_ANON_KEY", "\"\"")
        }

        create("debugDev") {
            initWith(getByName("debug"))
            matchingFallbacks += listOf("debug")
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            buildConfigField("String", "SEASON_ENVIRONMENT", "\"dev\"")
            buildConfigField("String", "SEASON_SUPABASE_URL", "\"https://gyuedxycbnqljryenapx.supabase.co\"")
            buildConfigField("String", "SEASON_SUPABASE_ANON_KEY", "\"${secretOrEmpty("SEASON_SUPABASE_DEV_ANON_KEY")}\"")
        }

        create("internalStaging") {
            initWith(getByName("debug"))
            matchingFallbacks += listOf("debug")
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            buildConfigField("String", "SEASON_ENVIRONMENT", "\"staging\"")
            buildConfigField("String", "SEASON_SUPABASE_URL", "\"https://czdsnnsizyhldiurlmxd.supabase.co\"")
            buildConfigField("String", "SEASON_SUPABASE_ANON_KEY", "\"${secretOrEmpty("SEASON_SUPABASE_STAGING_ANON_KEY")}\"")
        }

        getByName("release") {
            isMinifyEnabled = false
            buildConfigField("String", "SEASON_ENVIRONMENT", "\"production\"")
            buildConfigField("String", "SEASON_SUPABASE_URL", "\"\"")
            buildConfigField("String", "SEASON_SUPABASE_ANON_KEY", "\"\"")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.foundation)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.runtime)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.kotlinx.coroutines.android)

    debugImplementation(libs.androidx.compose.ui.tooling)
}

