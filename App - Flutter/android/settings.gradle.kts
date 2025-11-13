// android/settings.gradle.kts

pluginManagement {
    // Cargar flutter.sdk desde local.properties (sin imports)
    val localProperties = java.util.Properties()
    val localPropertiesFile = java.io.File(settingsDir, "local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { localProperties.load(it) }
    }
    val flutterSdkPath: String = localProperties.getProperty("flutter.sdk")
        ?: throw org.gradle.api.GradleException("flutter.sdk not set in local.properties")

    // Necesario para resolver el plugin de Flutter
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.6.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.0" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
