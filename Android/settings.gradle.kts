pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "SquashAnalyzerAndroid"
include(":app")

// Build before Gradle configuration so Android Studio and clean checkouts
// consume fresh Skip output. Kotlin UI is never hand-maintained.
// Only when a Swift source changed since the last run (or the output is
// missing): a sync in Android Studio no longer waits for `swift build` (T22).
val uiPackage = file("../Packages/SquashAnalyzerUI")
val skipOutput = uiPackage.resolve(".build/plugins/outputs/squashanalyzerui/SquashAnalyzerUI/destination/skipstone")
val skipStamp = uiPackage.resolve(".build/gradle-skip-stamp")
val swiftSources = listOf(file("../Packages/SquashAnalyzerUI"), file("../Packages/SquashAnalyzerCore"))
    .flatMap { pkg -> listOf(pkg.resolve("Package.swift"), pkg.resolve("Sources")) }
val newestSource = swiftSources.flatMap { root -> root.walkTopDown().filter { it.isFile }.toList() }
    .maxOfOrNull { it.lastModified() } ?: 0L
if (!skipOutput.exists() || !skipStamp.exists() || skipStamp.lastModified() < newestSource) {
    val swiftBuild = providers.exec {
        commandLine("swift", "build", "--package-path", uiPackage.absolutePath)
        environment("PATH", "${System.getenv("PATH")}:/opt/homebrew/bin")
    }
    print(swiftBuild.standardOutput.asText.get())
    print(swiftBuild.standardError.asText.get())
    skipStamp.parentFile.mkdirs()
    skipStamp.writeText(System.currentTimeMillis().toString())
}
// Included builds do not inherit this project's local SDK location.
val localSdk = file("local.properties")
if (localSdk.exists()) {
    localSdk.copyTo(skipOutput.resolve("local.properties"), overwrite = true)
}
includeBuild(skipOutput)
