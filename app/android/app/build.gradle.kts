plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.slipapp.slip"
    compileSdk = flutter.compileSdkVersion
    // No native C/C++ code in this app, so the NDK is not required.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.slipapp.slip"
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

    // Two apps from one codebase, installable side by side:
    //   ai   -> "Slip"      com.slipapp.slip       reads receipts with AI
    //   free -> "Slip Free" com.slipapp.slip.free  everything typed by hand
    // Build with --flavor and the matching --dart-define=SLIP_EDITION (see tool/).
    buildFeatures {
        resValues = true // app_name is set per flavor below
    }
    flavorDimensions += "edition"
    productFlavors {
        create("ai") {
            dimension = "edition"
            resValue("string", "app_name", "Slip")
        }
        create("free") {
            dimension = "edition"
            applicationIdSuffix = ".free"
            resValue("string", "app_name", "Slip Free")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
