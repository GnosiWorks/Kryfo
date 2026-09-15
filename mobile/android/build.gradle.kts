import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        mavenLocal()
        google()
        mavenCentral()
    }
}

// two pub packages compile native code with cmake, and what they produce
// depends on where it was built: the linker stamps a gnu build-id derived
// from its inputs, and the compiler bakes absolute source paths into the
// objects. f-droid built 0.2.8 on their own machine and it disagreed with
// ours on lib/armeabi-v7a/libdartjni.so for exactly that reason. our own
// container check could not catch it: it compares our build against our
// build, at the same path.
//
// dropping the build-id and mapping the package root to "." is what
// f-droid's reproducible builds page gives for pub libs, naming jni.
// cFlags and cppFlags are appended by the gradle plugin; CMAKE_C_FLAGS
// through arguments would replace what it sets.
val reproNativeSubprojects = setOf("jni", "flutter_zxing")

subprojects {
    plugins.withId("com.android.library") {
        if (name in reproNativeSubprojects) {
            val pkgRoot = projectDir.parentFile.absolutePath
            extensions.configure<LibraryExtension>("android") {
                defaultConfig {
                    externalNativeBuild {
                        cmake {
                            arguments += "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--build-id=none"
                            cFlags += "-ffile-prefix-map=$pkgRoot=."
                            cppFlags += "-ffile-prefix-map=$pkgRoot=."
                        }
                    }
                }
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
