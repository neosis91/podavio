import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.20"
}

fun publishedVersion(): Pair<String, Int>? {
    val changelog = rootProject.file("../CHANGELOG.md")
    if (!changelog.isFile) return null
    val match =
        Regex(
            """^## \[?(\d{4})\.(\d+)\.(\d+)\]?(?:\s+-\s+\d{4}-\d{2}-\d{2})?\s*$""",
            RegexOption.MULTILINE,
        ).find(changelog.readText()) ?: return null
    val year = match.groupValues[1].toInt()
    val month = match.groupValues[2].toInt()
    val patch = match.groupValues[3].toInt()
    if (month !in 1..12 || patch > 99) return null
    val name = "${match.groupValues[1]}.${match.groupValues[2]}.${match.groupValues[3]}"
    return name to (year * 10000 + month * 100 + patch)
}

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

val releaseStoreFile =
    signingValue("ANDROID_KEYSTORE_PATH", "storeFile")?.let { path ->
        val asFile = File(path)
        if (asFile.isAbsolute) asFile else rootProject.file(path)
    }
val hasReleaseSigning =
    releaseStoreFile != null &&
        releaseStoreFile.exists() &&
        !signingValue("ANDROID_KEY_ALIAS", "keyAlias").isNullOrBlank() &&
        !signingValue("ANDROID_KEYSTORE_PASSWORD", "storePassword").isNullOrBlank() &&
        !signingValue("ANDROID_KEY_PASSWORD", "keyPassword").isNullOrBlank()

val published = publishedVersion()

android {
    namespace = "fr.podavio.podavio"
    compileSdk = 37

    defaultConfig {
        // Même identifiant que le téléphone : la couche Wear exige les deux,
        // sur deux appareils. Le suffixe debug suit celui de l’app téléphone.
        applicationId = "fr.podavio.podavio"
        minSdk = 30
        targetSdk = 35
        versionCode = published?.second ?: 1
        versionName = published?.first ?: "0.1.0"
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
            applicationIdSuffix = ".debug"
        }
        release {
            signingConfig =
                if (hasReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(project(":wear-protocol"))
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.wear.compose:compose-foundation:1.7.1")
    implementation("androidx.wear.compose:compose-material:1.7.1")
    implementation("androidx.wear:wear-ongoing:1.1.0")
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2")
}
