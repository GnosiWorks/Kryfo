import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    lint {
        // release lint pulls its own dependency tree, useless for us and it
        // was the last thing standing between the offline cache and a build
        checkReleaseBuilds = false
    }

    namespace = "app.kryfo"

    packaging {
        jniLibs {
            keepDebugSymbols += "**/libhalo.so"
        }
    }
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.kryfo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            // real key when key.properties exists; debug fallback keeps
            // day-to-day debug installs working without the keystore.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
   dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// libhalo.so is gitignored, so a tree that has never run engine/build.sh
// still assembles a valid apk - one that dies on launch with "dlopen failed"
// and never reaches a screen. fail here, where we can say what to run.
tasks.named("preBuild") {
    doFirst {
        val missing = listOf("arm64-v8a", "x86_64").filter {
            !file("src/main/jniLibs/$it/libhalo.so").exists()
        }
        if (missing.isNotEmpty()) {
            throw GradleException(
                "libhalo.so missing for ${missing.joinToString(", ")}.\n" +
                    "the go engine has not been built. run:\n" +
                    "    cd engine && ./build.sh\n" +
                    "see BUILDING.md."
            )
        }
    }
}

// one apk per abi, each with its own version code. f-droid needs to tell
// them apart, and a shared code means only one of them is ever offered.
val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiVersionCode =
            abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride =
                variant.versionCode * 10 + abiVersionCode
        }
    }
}
