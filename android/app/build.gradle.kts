plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
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
    val asFile = file(path)
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
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fr.podavio.podavio"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
    // MediaBrowserServiceCompat + MediaSessionCompat pour Android Auto.
    implementation("androidx.media:media:1.7.1")
}
