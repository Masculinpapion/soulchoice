import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.soulchoice.soulchoice"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        getByName("debug") {
            keyAlias = keyProperties.getProperty("keyAlias", "androiddebugkey")
            keyPassword = keyProperties.getProperty("keyPassword", "android")
            storeFile = keyProperties.getProperty("storeFile")?.let { file(it) }
                ?: file("${System.getProperty("user.home")}/.android/debug.keystore")
            storePassword = keyProperties.getProperty("storePassword", "android")
        }
        create("release") {
            keyAlias = keyProperties.getProperty("keyAlias", "")
            keyPassword = keyProperties.getProperty("keyPassword", "")
            storeFile = keyProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keyProperties.getProperty("storePassword", "")
        }
    }

    defaultConfig {
        applicationId = "com.soulchoice.soulchoice"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
}

// RuStore 27.08 duyurusu: SDK Push güncel sürüm 7.4.0 (eski uluslararası SSL
// sertifikaları iptal edilince eski sürümler kopabilir). Flutter eklentisi
// (flutter_rustore_push 7.2.0) natife 7.2.0 bağlıyor — burada 7.4.0'a
// zorlanıyor; eklenti API'si minor sürümde uyumlu (E2E emülatör kanıtlı).
configurations.all {
    resolutionStrategy {
        force("ru.rustore.sdk:pushclient:7.4.0")
        // 02.09.2026: Play Console uyarısı — ru.rustore.sdk:coreui:8.0.0'ın getirdiği
        // material:1.6.1, Android 15'te kaldırılan setStatusBarColor/
        // setNavigationBarColor'ı korumasız çağırıyor (datepicker). 1.14.0'da
        // çağrılar SDK<35 korumasında; 1.6.1 → 1.14.0 API uyumlu (yalnız coreui kullanıyor).
        force("com.google.android.material:material:1.14.0")
    }
}
