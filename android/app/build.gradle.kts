import com.flutter.gradle.FlutterExtension

val releaseTargetPlatforms = "android-arm,android-arm64"
val releaseAbiFilters = listOf("armeabi-v7a", "arm64-v8a")

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") apply false
}

if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }) {
    gradle.startParameter.projectProperties =
        gradle.startParameter.projectProperties.toMutableMap().apply {
            this["target-platform"] = releaseTargetPlatforms
        }
    extensions.extraProperties["target-platform"] = releaseTargetPlatforms
}

// The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
apply(plugin = "dev.flutter.flutter-gradle-plugin")

val flutterExtension = extensions.getByType<FlutterExtension>()

android {
    namespace = "com.example.encryvault"
    compileSdk = flutterExtension.compileSdkVersion
    ndkVersion = flutterExtension.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.encryvault"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutterExtension.minSdkVersion
        targetSdk = flutterExtension.targetSdkVersion
        versionCode = flutterExtension.versionCode
        versionName = flutterExtension.versionName
    }

    buildTypes {
        release {
            ndk {
                abiFilters.clear()
                abiFilters += releaseAbiFilters
            }
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutterExtension.source = "../.."
