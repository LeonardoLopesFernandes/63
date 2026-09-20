plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "amer.papeleta.papeleta63"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "amer.papeleta.papeleta63"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // CI (GitHub Secrets): KEY_ALIAS / KEY_PASSWORD /
            // KEYSTORE_PASSWORD / KEYSTORE_PATH (arquivo decodificado pelo workflow).
            val envAlias = System.getenv("KEY_ALIAS")
            if (!envAlias.isNullOrBlank()) {
                keyAlias = envAlias
                keyPassword = System.getenv("KEY_PASSWORD")
                    ?: error("Secret KEY_PASSWORD ausente")
                storeFile = file(System.getenv("KEYSTORE_PATH") ?: "upload.keystore")
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                    ?: error("Secret KEYSTORE_PASSWORD ausente")
            } else if (file("upload.keystore").exists()) {
                // Build local: usa o keystore do disco (arquivo ignorado pelo git).
                keyAlias = "upload"
                keyPassword = "papeleta63"
                storeFile = file("upload.keystore")
                storePassword = "papeleta63"
            } else {
                error("Keystore não encontrado: configure os Secrets (CI) ou android/app/upload.keystore (local)")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
