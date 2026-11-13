pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.4.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
    id("io.sentry.android.gradle") version "6.24.0" apply false
}

include(":app")
include(":wear-protocol")

// Télécommande Wear OS. Absent du build F-Droid : pas de SDK Wear, pas de
// Play Services. La release GitHub pose ORG_GRADLE_PROJECT_podavioWear=true.
val podavioWear = providers.gradleProperty("podavioWear").orNull == "true"
if (podavioWear) {
    include(":wear")
}
