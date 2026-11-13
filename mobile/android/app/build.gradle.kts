import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // after the android and kotlin plugins
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

// the play build was a dart define once. a script that still passes it would
// get a foss bundle under play's name, so it stops here
if ((project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.any { String(Base64.getDecoder().decode(it)).startsWith("KRYFO_STORE=") } == true
) {
    throw GradleException("KRYFO_STORE is gone. build the play bundle with --flavor play")
}

// linked devices are in every android build (lib/devices/linked_switch.dart).
// a script that passes KRYFO_LINKED=0 would ship a phone that cannot link
if ((project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.map { String(Base64.getDecoder().decode(it)).trim() }
        ?.any { it == "KRYFO_LINKED=0" || it == "KRYFO_LINKED=false" } == true
) {
    throw GradleException("linked devices are in every android build: drop KRYFO_LINKED")
}

// google push in the play build: the firebase project's google-services.json
// lives outside the repo (BUILDING.md), and only its few public values go into
// the play build's resources, which FirebaseApp reads. no google-services
// plugin. a build of foss tasks alone never opens the file
val googleServicesFile: File? = listOfNotNull(
    System.getenv("KRYFO_GOOGLE_SERVICES")?.takeIf { it.isNotEmpty() }?.let { File(it) },
    file("src/play/google-services.json"),
    File(System.getProperty("user.home"), ".kryfo-secrets/play/google-services.json"),
).firstOrNull { it.isFile }
val fossTasksOnly = gradle.startParameter.taskNames.let { t ->
    t.isNotEmpty() && t.all { it.contains("foss", ignoreCase = true) }
}
// the values, or why there are none
val firebaseValues: Result<Map<String, String>> = when (val f = googleServicesFile) {
    null -> if (fossTasksOnly) Result.success(emptyMap()) else Result.failure(GradleException(
        "google-services.json for the play build is missing.\n" +
            "put the firebase project's file at ~/.kryfo-secrets/play/google-services.json\n" +
            "or name it in KRYFO_GOOGLE_SERVICES. it never goes in git, and foss builds do not need it."
    ))
    else -> if (fossTasksOnly) Result.success(emptyMap()) else runCatching { firebaseValuesOf(f, "app.kryfo") }
}

fun firebaseValuesOf(f: File, pkg: String): Map<String, String> {
    @Suppress("UNCHECKED_CAST")
    val j = groovy.json.JsonSlurper().parse(f) as Map<String, Any?>
    @Suppress("UNCHECKED_CAST")
    val info = j["project_info"] as? Map<String, Any?> ?: emptyMap()
    @Suppress("UNCHECKED_CAST")
    val client = (j["client"] as? List<Map<String, Any?>>)?.firstOrNull {
        val ci = it["client_info"] as? Map<String, Any?>
        (ci?.get("android_client_info") as? Map<String, Any?>)?.get("package_name") == pkg
    } ?: throw GradleException("${f.name} has no android app $pkg: download it again from the firebase console")
    val appId = (client["client_info"] as Map<*, *>)["mobilesdk_app_id"] as? String
    val apiKey = (client["api_key"] as? List<*>)?.firstNotNullOfOrNull { (it as? Map<*, *>)?.get("current_key") as? String }
    val out = linkedMapOf(
        "google_app_id" to appId,
        "gcm_defaultSenderId" to info["project_number"] as? String,
        "google_api_key" to apiKey,
        "project_id" to info["project_id"] as? String,
    )
    val missing = out.filterValues { it.isNullOrEmpty() }.keys
    if (missing.isNotEmpty()) throw GradleException("${f.name} lacks ${missing.joinToString(", ")}")
    // what resources take: letters, digits and the few marks fcm's ids use
    out.values.forEach {
        if (!Regex("[A-Za-z0-9:_.-]+").matches(it!!)) throw GradleException("${f.name} holds a value no resource can")
    }
    return out.mapValues { it.value!! }
}

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
            // the shim's build script checks these exact bytes
            keepDebugSymbols += "**/libkryfo_signal.so"
        }
    }
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    // the reliability harness's sender, in debug and profile builds only
    sourceSets {
        getByName("debug").java.srcDir("src/bench/kotlin")
        getByName("profile").java.srcDir("src/bench/kotlin")
    }

    // robolectric tests read the app's strings
    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

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
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // the launcher name, see the label check below
        manifestPlaceholders["appLabel"] = "Kryfo"
    }

    // foss is what f-droid, github and the site ship, with no google code.
    // play is the google play build: its code and dependencies go only in
    // src/play and playImplementation, so foss never sees them. flutter hands
    // the flavor to dart as well (lib/store.dart), so the halves agree
    flavorDimensions += "store"
    productFlavors {
        create("foss") {
            dimension = "store"
        }
        create("play") {
            dimension = "store"
            // play gets one bundle per version, above the per-abi apks
            // (N*10+1 to +3, room left to +8) and below the next version's
            versionCode = flutter.versionCode * 10 + 9
            firebaseValues.getOrNull()?.forEach { (k, v) -> resValue("string", k, v) }
        }
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
        debug {
            // HALO_TEST_ID=1 installs a debug build beside the real app, with
            // its own data and its own name, for tests on a phone that keeps
            // its kryfo
            if (System.getenv("HALO_TEST_ID") == "1") {
                applicationIdSuffix = ".bridgetest"
                manifestPlaceholders["appLabel"] = "Kryfo test"
            }
        }
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

// kotlin puts the module name into internal names, and the flavors turned
// app_release into app_fossRelease. r8's code is the same either way but
// its map id in classes.dex is not, so release builds keep the old name
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    if (name == "compileFossReleaseKotlin" || name == "compilePlayReleaseKotlin") {
        compilerOptions.moduleName.set("app_release")
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // the camera shrink reads the orientation tag. the platform class is
    // banned by lint for old security bugs; this one is the maintained copy
    implementation("androidx.exifinterface:exifinterface:1.4.2")
    // the photo picker check. the version image_picker_android brings
    implementation("androidx.activity:activity:1.12.4")
    // google push, the play build only: firebase's messaging and none of its
    // other parts. foss never sees it (docs/RELEASING.md checks the apk)
    "playImplementation"("com.google.firebase:firebase-messaging:26.0.0")
    // the tip jar, the play build only: google play billing, nothing else
    // of google's. foss never sees it (docs/RELEASING.md checks the apk)
    "playImplementation"("com.android.billingclient:billing:9.1.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.16.1")
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
        checkSignalShim()
    }
}

// the libsignal shim, built in this tree from this tree's crate: the stamp
// build-android.sh leaves names the library's sha256 and the crate's source.
// a library copied from another checkout or built from older code is refused
fun checkSignalShim() {
    val abis = listOf("arm64-v8a", "armeabi-v7a", "x86_64")
    val rebuild = "run mobile/native/kryfo_signal/build-android.sh (see BUILDING.md)"
    val missing = abis.filter { !file("src/main/jniLibs/$it/libkryfo_signal.so").exists() }
    if (missing.isNotEmpty()) {
        throw GradleException(
            "libkryfo_signal.so missing for ${missing.joinToString(", ")}.\n$rebuild"
        )
    }
    // the fetch step of repro/release.sh builds with empty placeholders
    if (System.getenv("HALO_STEP") == "fetch") return
    val crate = rootProject.file("../native/kryfo_signal")
    val tree = ProcessBuilder("bash", File(crate, "build-android.sh").path, "--tree-id")
        .redirectErrorStream(true).start()
    val treeId = tree.inputStream.bufferedReader().readText().trim()
    if (tree.waitFor() != 0) throw GradleException("build-android.sh --tree-id failed: $treeId")
    for (abi in abis) {
        val so = file("src/main/jniLibs/$abi/libkryfo_signal.so")
        val stamp = file("src/main/jniLibs/$abi/libkryfo_signal.stamp")
        val fields = if (stamp.exists()) {
            stamp.readLines().mapNotNull {
                val parts = it.split(" ", limit = 2)
                if (parts.size == 2) parts[0] to parts[1] else null
            }.toMap()
        } else emptyMap()
        val sha = MessageDigest.getInstance("SHA-256")
            .digest(so.readBytes()).joinToString("") { "%02x".format(it) }
        when {
            fields.isEmpty() -> throw GradleException("$abi/libkryfo_signal.so has no stamp.\n$rebuild")
            fields["sha256"] != sha -> throw GradleException(
                "$abi/libkryfo_signal.so is not the library its stamp names.\n$rebuild"
            )
            fields["tree"] != treeId -> throw GradleException(
                "$abi/libkryfo_signal.so was built from other source than this checkout's.\n$rebuild"
            )
        }
    }
}

// a play build without the firebase values stops here, saying where the
// file goes. foss never asks
android.applicationVariants.configureEach {
    val variant = this
    if (variant.flavorName == "play") {
        variant.preBuildProvider.configure {
            doFirst { firebaseValues.getOrThrow() }
        }
    }
    // a play release seals to the gateway's own key, never the development
    // one: with it every endpoint would answer 404. KRYFO_DEV_GATEWAY=1 lets
    // a test release through
    if (variant.flavorName == "play" && variant.buildType.name == "release") {
        variant.preBuildProvider.configure {
            doFirst {
                val src = rootProject.file("../lib/google_push.dart").readText()
                // the values, however they are written: the dev key named, or
                // its literal copied in
                fun value(name: String): String? =
                    Regex("""const\s+$name\s*=\s*(?:'([^']*)'|"([^"]*)"|(\w+))\s*;""")
                        .find(src)?.groupValues?.let { g -> g[1].ifEmpty { g[2] }.ifEmpty { g[3] } }
                val devKey = value("kPushGatewayDevPub")
                var pinned = value("kPushGatewayPub")
                if (pinned == "kPushGatewayDevPub") pinned = devKey
                val dev = pinned == null || pinned == devKey
                if (dev && System.getenv("KRYFO_DEV_GATEWAY") != "1") {
                    throw GradleException(
                        "the play release pins the development push gateway key.\n" +
                            "pin the server's key in mobile/lib/google_push.dart " +
                            "(kPushGatewayPub, from kryfo-push pubkey on the server)."
                    )
                }
            }
        }
    }
}

// the test engine that acts as if tor were blocked (HALO_TOR_BLOCKED=1) is
// for the bridgetest debug app only. any other build refuses it.
android.applicationVariants.configureEach {
    val variant = this
    variant.preBuildProvider.configure {
        doFirst {
            if (variant.buildType.name != "debug" || System.getenv("HALO_TEST_ID") != "1") {
                val libs = listOf("arm64-v8a", "armeabi-v7a", "x86_64").map {
                    file("src/main/jniLibs/$it/libhalo.so").path
                }
                val scan = rootProject.file("../../engine/censor-scan.sh").path
                val p = ProcessBuilder(listOf("bash", scan) + libs).inheritIO().start()
                if (p.waitFor() != 0) {
                    throw GradleException(
                        "the engine in jniLibs is a test build. rebuild it with\n" +
                            "    cd engine && ./build.sh"
                    )
                }
            }
        }
    }
}

// the launcher shows "Kryfo test" for the bridgetest app and "Kryfo" for
// every other build, so the two are never mixed up on a phone
abstract class LabelCheck : DefaultTask() {
    @get:InputFile
    abstract val manifest: RegularFileProperty

    @get:Input
    abstract val appId: Property<String>

    @TaskAction
    fun check() {
        val want = if (appId.get() == "app.kryfo.bridgetest") "Kryfo test" else "Kryfo"
        val doc = javax.xml.parsers.DocumentBuilderFactory.newInstance()
            .newDocumentBuilder().parse(manifest.get().asFile)
        val app = doc.getElementsByTagName("application").item(0) as org.w3c.dom.Element
        val got = app.getAttribute("android:label")
        if (got != want) {
            throw GradleException("${appId.get()} is labelled \"$got\", want \"$want\"")
        }
    }
}

// kryfo never installs apps, so no build may ask to: a plugin that merges
// in the permission fails the build
abstract class NoInstallCheck : DefaultTask() {
    @get:InputFile
    abstract val manifest: RegularFileProperty

    @TaskAction
    fun check() {
        val doc = javax.xml.parsers.DocumentBuilderFactory.newInstance()
            .newDocumentBuilder().parse(manifest.get().asFile)
        val banned = setOf(
            "android.permission.REQUEST_INSTALL_PACKAGES",
            "android.permission.INSTALL_PACKAGES",
        )
        // the permission can be asked for on every element that asks for one
        for (tag in listOf("uses-permission", "uses-permission-sdk-23", "uses-permission-sdk-m")) {
            val asks = doc.getElementsByTagName(tag)
            for (i in 0 until asks.length) {
                val p = (asks.item(i) as org.w3c.dom.Element).getAttribute("android:name")
                if (p in banned) throw GradleException("the merged manifest asks for $p in $tag")
            }
        }
    }
}

androidComponents {
    onVariants { variant ->
        val name = variant.name.replaceFirstChar { it.uppercase() }
        val merged = variant.artifacts.get(com.android.build.api.artifact.SingleArtifact.MERGED_MANIFEST)
        val labelCheck = tasks.register<LabelCheck>("check${name}Label") {
            manifest.set(merged)
            appId.set(variant.applicationId)
        }
        val noInstall = tasks.register<NoInstallCheck>("check${name}NoInstall") {
            manifest.set(merged)
        }
        tasks.matching { it.name == "assemble$name" || it.name == "bundle$name" }
            .configureEach { dependsOn(labelCheck, noInstall) }
    }
}

// one apk per abi, each with its own version code. f-droid needs to tell
// them apart, and a shared code means only one of them is ever offered.
// the universal apk (no abi filter) is N*10, below the per-abi apks of its
// version, so a phone can always move from it to the smaller one
val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abi = output.filters.find { it.filterType == "ABI" }?.identifier
        val abiVersionCode = if (abi == null) 0 else abiCodes[abi]
        // play builds a bundle and keeps its own code
        if (abiVersionCode != null && variant.flavorName == "foss") {
            (output as ApkVariantOutputImpl).versionCodeOverride =
                variant.versionCode * 10 + abiVersionCode
        }
    }
}

// a universal apk carries only the abis flutter was asked for
// (--target-platform android-arm,android-arm64). flutter's own filter names
// all three, and jniLibs' x86_64 engine and shim would ride along with no
// flutter engine beside them
val platformAbis = mapOf("android-arm" to "armeabi-v7a", "android-arm64" to "arm64-v8a", "android-x64" to "x86_64")
val splitPerAbi = project.findProperty("split-per-abi")?.toString()?.toBoolean() ?: false
val targetAbis = (project.findProperty("target-platform") as String?)
    ?.split(",")
    ?.mapNotNull { platformAbis[it] }
if (!splitPerAbi && !targetAbis.isNullOrEmpty()) {
    android.buildTypes.configureEach {
        ndk.abiFilters.clear()
        ndk.abiFilters.addAll(targetAbis)
    }
}
