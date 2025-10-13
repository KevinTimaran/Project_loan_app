plugins {
    id("com.android.application")
    id("kotlin-android")
    // El plugin de Flutter debe aplicarse después de los plugins de Android y Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.loan_app" // Asegúrate que sea correcto
    compileSdk = flutter.compileSdkVersion

    // <-- Versión NDK fijada para compatibilidad con plugins nativos
    ndkVersion = "27.0.12077973" // <-- Asegúrate de que esta línea esté

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8 // o VERSION_11
        targetCompatibility = JavaVersion.VERSION_1_8 // o VERSION_11
        // ✅ AÑADIDO ESTO PARA DESUGARING
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString() // o VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html  ).
        applicationId = "com.example.loan_app" // Asegúrate que sea correcto
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

dependencies {
    // ✅ AÑADIDO ESTO PARA DESUGARING
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Puedes añadir otras dependencias aquí si es necesario
}

flutter {
    source = "../.."
}