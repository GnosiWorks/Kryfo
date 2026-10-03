import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import java.io.FileInputStream
import java.util.Base64
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

// the google play build: --dart-define=KRYFO_STORE=play. read from the define
// the dart side reads, so the two halves cannot disagree. every other build
// leaves this false and comes out as before
val playStore = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.any { String(Base64.getDecoder().decode(it)) == "KRYFO_STORE=play" }
    ?: false

android {
    lint {
        // release lint runs. it needs its own artefacts in the gradle cache,
        // so a fresh machine does one online sync before offline builds work
        checkReleaseBuilds = true
        lintConfig = file("lint.xml")
        // a warning is a finding too; the build says so out loud
        warningsAsErrors = true
    }

    namespace = "app.kryfo"

    // the language is chosen inside the app, so a bundle has to carry every
    // language's resources; a split would leave the chosen one out. apks
    // (what ships) have them all anyway
    bundle {
        language {
            enableSplit = false
        }
    }

    packaging {
        jniLibs {
            keepDebugSymbols += "**/libhalo.so"
        }
    }
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "app.kryfo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // play gets one bundle per version, above the per-abi apks (N*10+1
        // to +3, room left to +8) and below the next version's
        versionCode = if (playStore) flutter.versionCode * 10 + 9 else flutter.versionCode
        versionName = flutter.versionName
    }

    if (playStore) {
        sourceSets.getByName("release").manifest.srcFile("src/play/AndroidManifest.xml")
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
            // HALO_UNSIGNED=1 leaves the apk unsigned for the repro container,
            // repro/release.sh signs it outside. otherwise the real key when
            // key.properties exists, else the debug key.
            signingConfig = when {
                System.getenv("HALO_UNSIGNED") == "1" -> null
                keystorePropertiesFile.exists() -> signingConfigs.getByName("release")
                else -> signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // the camera shrink reads the orientation tag. the platform class is
    // banned by lint for old security bugs; this one is the maintained copy
    implementation("androidx.exifinterface:exifinterface:1.4.2")
}

// libhalo.so is gitignored, and an apk without it dies on launch with
// "dlopen failed". fail here, where we can say what to run.
tasks.named("preBuild") {
    doFirst {
        val missing = listOf("arm64-v8a", "armeabi-v7a", "x86_64").filter {
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
        // play builds a bundle and keeps its own code
        if (abiVersionCode != null && !playStore) {
            (output as ApkVariantOutputImpl).versionCodeOverride =
                variant.versionCode * 10 + abiVersionCode
        }
    }
}
