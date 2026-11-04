plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.File
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun signingValue(envName: String, propName: String): String? {
    val fromEnv = System.getenv(envName)?.takeIf { it.isNotBlank() }
    if (fromEnv != null) return fromEnv
    return keystoreProperties.getProperty(propName)?.takeIf { it.isNotBlank() }
}

val releaseStoreFile = signingValue("ANDROID_KEYSTORE_PATH", "storeFile")?.let { path ->
    // file() rend toujours un chemin absolu, donc isAbsolute ne distingue plus
    // un chemin relatif à android/ (upload-keystore.jks).
    val asFile = File(path)
    if (asFile.isAbsolute) asFile else rootProject.file(path)
}
val hasReleaseSigning =
    releaseStoreFile != null &&
        releaseStoreFile.exists() &&
        !signingValue("ANDROID_KEY_ALIAS", "keyAlias").isNullOrBlank() &&
        !signingValue("ANDROID_KEYSTORE_PASSWORD", "storePassword").isNullOrBlank() &&
        !signingValue("ANDROID_KEY_PASSWORD", "keyPassword").isNullOrBlank()

android {
    namespace = "fr.podavio.podavio"
    // Flutter reste à 36 ; flutter_local_notifications et androidx.core exigent 37.
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        multiDexEnabled = true
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fr.podavio.podavio"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // versionName = tag CalVer, mois sans zéro (2026.9.12).
        // versionCode = AAAAMMNN, identique sur chaque APK.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appName"] = "Podavio"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = signingValue("ANDROID_KEYSTORE_PASSWORD", "storePassword")
                keyAlias = signingValue("ANDROID_KEY_ALIAS", "keyAlias")
                keyPassword = signingValue("ANDROID_KEY_PASSWORD", "keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // À côté de la version finale : flutter run n’écrase pas l’APK publié.
            applicationIdSuffix = ".debug"
            manifestPlaceholders["appName"] = "Podavio debug"
        }
        getByName("profile") {
            applicationIdSuffix = ".debug"
            manifestPlaceholders["appName"] = "Podavio debug"
        }
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // Local / sans secrets : debug (pas pour une release publique).
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // MediaBrowserServiceCompat + MediaSessionCompat pour Android Auto.
    implementation("androidx.media:media:1.7.1")
}
