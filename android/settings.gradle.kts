pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        val sdkDir = properties.getProperty("sdk.dir")
        // SDK 37 is published as platforms/android-37.0. AGP still resolves
        // integer compileSdk 37 to platforms/android-37 (receive_sharing_intent).
        if (!sdkDir.isNullOrBlank()) {
            val platforms = java.io.File(sdkDir, "platforms")
            val alias = java.io.File(platforms, "android-37")
            val actual = java.io.File(platforms, "android-37.0")
            if (!alias.exists() && actual.isDirectory) {
                try {
                    java.nio.file.Files.createSymbolicLink(
                        alias.toPath(),
                        java.nio.file.Path.of("android-37.0"),
                    )
                } catch (e: Exception) {
                    error(
                        "Android SDK Platform 37 is installed as platforms/android-37.0, " +
                            "but AGP looks for platforms/android-37. Create that alias: " +
                            "ln -s android-37.0 \"$sdkDir/platforms/android-37\""
                    )
                }
            }
        }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
