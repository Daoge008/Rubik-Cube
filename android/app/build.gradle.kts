plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.daoge.rubik_cube"
    compileSdk = flutter.compileSdkVersion

    // Plugins that ship native code (jni, jni_flutter, audioplayers_android,
    // camera_android, ...) declare ndkVersion = flutter.ndkVersion. Pinning a
    // lower NDK here makes :plugin:checkDebugAarMetadata fail, so track Flutter's
    // own default (it is installed locally).
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.daoge.rubik_cube"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // NOTE: do NOT add `ndk { abiFilters += ... }` here. The Flutter Gradle
        // plugin already sets abiFilters programmatically to the platform ABI list
        // (armeabi-v7a, arm64-v8a, x86_64) whenever `--split-per-abi` is NOT used.
        // Hardcoding it here overrides that logic and makes `--split-per-abi` fail
        // with "ndk abiFilters cannot be present when splits abi filters are set".

        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++17", "-O3", "-frtti", "-fexceptions")
                arguments += listOf("-DANDROID_STL=c++_shared")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
