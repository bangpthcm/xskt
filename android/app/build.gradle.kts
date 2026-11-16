import com.android.build.api.dsl.ApplicationExtension
plugins {
    id("com.android.application")
    // Kotlin được AGP 9 tích hợp sẵn (Built-in Kotlin) -> không apply kotlin-android nữa.
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

extensions.configure<ApplicationExtension> {
    namespace = "com.example.xsktbot"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.xsktbot"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// AGP 9 đã bỏ applicationVariants -> copy APK release thành xskt.apk sau khi build
// (giữ nguyên app-release.apk để Flutter vẫn tìm thấy file output)
val outputsDir = layout.buildDirectory.dir("outputs")
tasks.matching { it.name == "assembleRelease" }.configureEach {
    doLast {
        val dir = outputsDir.get().asFile
        val src = dir.resolve("apk/release/app-release.apk")
        if (src.exists()) src.copyTo(dir.resolve("flutter-apk/xskt.apk"), overwrite = true)
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}
