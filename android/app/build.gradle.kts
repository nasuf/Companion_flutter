import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyProperties = Properties()
val releaseKeyPropertiesFile = file(
    System.getenv("BANSHENG_ANDROID_KEY_PROPERTIES")
        ?: "${System.getProperty("user.home")}/.android/bansheng-release-key.properties"
)
val hasReleaseSigning = releaseKeyPropertiesFile.exists()

if (hasReleaseSigning) {
    releaseKeyPropertiesFile.inputStream().use { releaseKeyProperties.load(it) }
}

android {
    namespace = "com.bansheng.companion"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }

    defaultConfig {
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["JPUSH_PKGNAME"] = "\${applicationId}"
        manifestPlaceholders["JPUSH_CHANNEL"] = "developer-default"
        manifestPlaceholders["JPUSH_APPKEY"] = ""
    }

    flavorDimensions += "env"

    productFlavors {
        create("dev") {
            dimension = "env"
            applicationId = "com.bansheng.dev"
            manifestPlaceholders["JPUSH_PKGNAME"] = "com.bansheng.dev"
            manifestPlaceholders["JPUSH_APPKEY"] = providers.gradleProperty("JPUSH_DEV_APPKEY")
                .orElse(providers.environmentVariable("JPUSH_DEV_APPKEY")).getOrElse("")
        }
        create("prod") {
            dimension = "env"
            applicationId = "com.bansheng.prod"
            manifestPlaceholders["JPUSH_PKGNAME"] = "com.bansheng.prod"
            manifestPlaceholders["JPUSH_APPKEY"] = providers.gradleProperty("JPUSH_PROD_APPKEY")
                .orElse(providers.environmentVariable("JPUSH_PROD_APPKEY")).getOrElse("")
        }
    }

    if (hasReleaseSigning) {
        signingConfigs {
            create("release") {
                storeFile = file(releaseKeyProperties.getProperty("storeFile"))
                storePassword = releaseKeyProperties.getProperty("storePassword")
                keyAlias = releaseKeyProperties.getProperty("keyAlias")
                keyPassword = releaseKeyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (hasReleaseSigning) "release" else "debug"
            )
        }
    }
}

// Bind AGP directly to Flutter's generated JNI output, including its producer.
androidComponents {
    onVariants(selector().all()) { variant ->
        val taskName = "copyJniLibsflutterBuild" + variant.name.replaceFirstChar { it.uppercaseChar() }
        afterEvaluate {
            if (taskName in tasks.names) {
                variant.sources.jniLibs?.addGeneratedSourceDirectory(tasks.named<Sync>(taskName)) {
                    objects.directoryProperty().fileValue(it.destinationDir)
                }
                // AGP's incremental JNI folder merger can retain its previous
                // libapp.so even after Flutter's Sync task writes a new one.
                // Recreate this small merge output; downstream tasks can still
                // use their normal content-based incremental checks.
                tasks.named("merge${variant.name.replaceFirstChar { it.uppercaseChar() }}JniLibFolders") {
                    outputs.upToDateWhen { false }
                }
            }
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.16.1")
    implementation("cn.jiguang.sdk:jpush:6.2.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
