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
val uiPackage = file("../Packages/SquashAnalyzerUI")
val swiftBuild = providers.exec {
    commandLine("swift", "build", "--package-path", uiPackage.absolutePath)
    environment("PATH", "${System.getenv("PATH")}:/opt/homebrew/bin")
}
print(swiftBuild.standardOutput.asText.get())
print(swiftBuild.standardError.asText.get())
val skipOutput = uiPackage.resolve(".build/plugins/outputs/squashanalyzerui/SquashAnalyzerUI/destination/skipstone")
// Included builds do not inherit this project's local SDK location.
val localSdk = file("local.properties")
if (localSdk.exists()) {
    localSdk.copyTo(skipOutput.resolve("local.properties"), overwrite = true)
}
includeBuild(skipOutput)
