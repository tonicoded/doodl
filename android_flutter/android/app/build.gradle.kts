plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val hasReleaseKeystore = keystorePropertiesFile.exists()
        && (keystoreProperties["storePassword"] as String?)?.isNotBlank() == true
        && (keystoreProperties["keyPassword"] as String?)?.isNotBlank() == true
        && (keystoreProperties["keyAlias"] as String?)?.isNotBlank() == true
        && (keystoreProperties["storeFile"] as String?)?.isNotBlank() == true
        && (keystoreProperties["storePassword"] as String?) != "REPLACE_ME"
        && (keystoreProperties["keyPassword"] as String?) != "REPLACE_ME"

android {
    namespace = "com.anthonyverruijt.doodl"
    compileSdk = flutter.compileSdkVersion
    // Use the highest required NDK across plugins (backward compatible).
    // Flutter tooling will prompt downloads if this is lower than plugin requirements.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.anthonyverruijt.doodl"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Allow installs on older Android devices (Flutter defaults can be higher).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Use upload signing when `android/key.properties` exists, otherwise fall back to debug.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // Needed for native FirebaseMessagingService used for background widget updates.
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging-ktx")
}

flutter {
    source = "../.."
}
