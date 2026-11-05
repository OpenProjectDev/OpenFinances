// Alternate host for Google Maven: dl.google.com (what google() points at) has
// been returning 404 for Maven files (seen 2026-10-18, also from outside our
// network) while dl-ssl.google.com serves the same files. It must come BEFORE
// google(): Gradle downloads a library's files only from the repository that
// supplied its metadata, and stale metadata cached from google() otherwise
// pins the download to the broken host. Added for module dependencies AND each
// module's own buildscript classpath (plugins like android_file_picker pin
// their own AGP there). Remove once google() works again.
val googleMavenFallback = "https://dl-ssl.google.com/dl/android/maven2/"

allprojects {
    buildscript.repositories.maven { url = uri(googleMavenFallback) }
    repositories {
        maven { url = uri(googleMavenFallback) }
        google()
        mavenCentral()
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
// flutter_native_splash 2.4.4 (pinned, see pubspec.yaml) compiles its Android
// module against API 31, but current AndroidX libraries require 34+ and AGP's
// AAR-metadata check fails the build. Lift just that module at finalizeDsl,
// i.e. after its own build.gradle has set 31. Must stay above the
// evaluationDependsOn block below, which starts evaluating subprojects.
subprojects {
    if (name == "flutter_native_splash") {
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension> {
                finalizeDsl { it.compileSdk = 36 }
            }
        }
    }
}

// Plugins live in the pub cache (C:), their build output under this project
// (D:). A plugin whose unit tests include Android resources (e.g.
// flutter_plugin_android_lifecycle) makes AGP's GenerateTestConfig take a
// path from one to the other, which can't exist across drives: "this and
// base files have different roots" as soon as that task is created (the IDE's
// Gradle sync creates every task; `flutter run` doesn't). We never run the
// plugins' own unit tests, so off for modules on another drive.
subprojects {
    if (projectDir.toPath().root != newBuildDir.asFile.toPath().root) {
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension> {
                finalizeDsl { it.testOptions.unitTests.isIncludeAndroidResources = false }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
