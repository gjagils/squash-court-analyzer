plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.devtools.ksp")
}

// Version and build: edited by scripts/version.py (docs/opleveren-en-hosting.md),
// not by hand. squashCode = 1.000.000 * major + 10.000 * minor + 100 * build;
// an internal delivery to a phone adds -PsquashInternal=N (3.1 build 4.1) and
// so counts up from the last upload, which the versionCode needs.
val squashVersion = "3.0"
val squashBuild = 1
val squashCode = 3000100
val squashInternal = (findProperty("squashInternal") as String?)?.toInt() ?: 0

// Google Play upload key: never in the repo. The keystore lives in
// ~/.android-keys (backed up in 1Password), the passwords in
// ~/.gradle/gradle.properties. Google Play App Signing re-signs with the real
// app key; see docs/google-play.md.
val uploadStoreFile = file(
    providers.gradleProperty("SQUASH_UPLOAD_STORE_FILE")
        .getOrElse("${System.getProperty("user.home")}/.android-keys/squashanalyzer-upload.jks")
)
val uploadStorePassword = providers.gradleProperty("SQUASH_UPLOAD_STORE_PASSWORD").orNull
val uploadKeyPassword = providers.gradleProperty("SQUASH_UPLOAD_KEY_PASSWORD").orNull
val hasUploadKey = uploadStoreFile.exists() && uploadStorePassword != null && uploadKeyPassword != null

// Room writes the database schema per version into schemas/ (committed), so
// a future migration (9 -> 10) can be tested with MigrationTestHelper
ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}

android {
    namespace = "com.squashanalyzer.android"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.squashanalyzer.android"
        minSdk = 28
        targetSdk = 36
        // versionCode must go up with every upload to Google Play; versionName
        // is what testers see ("3.1 (4)", internal "3.1 (4.1)")
        versionCode = squashCode + squashInternal
        versionName = if (squashInternal == 0) "$squashVersion ($squashBuild)" else "$squashVersion ($squashBuild.$squashInternal)"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = uploadStoreFile
                storePassword = uploadStorePassword
                keyAlias = providers.gradleProperty("SQUASH_UPLOAD_KEY_ALIAS").getOrElse("upload")
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // No R8 yet: Skip's runtime reflects on generated classes, so
            // shrinking needs its own keep rules and a test pass first.
            isMinifyEnabled = false
            // Without the upload key a release build is debug-signed, so it can
            // be tried locally; Google Play refuses debug-signed uploads.
            signingConfig = if (hasUploadKey) signingConfigs.getByName("upload") else signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }
    // The exported Room schemas (schemas/<version>.json) are assets of the debug
    // build and of the instrumented tests (never of release): MigrationTestHelper,
    // also under Robolectric, reads them there to build a database at an old version
    sourceSets {
        getByName("debug").assets.srcDir("$projectDir/schemas")
        getByName("androidTest").assets.srcDir("$projectDir/schemas")
    }
    buildFeatures {
        compose = true
    }
}

// Task-level config, not the deprecated android.kotlinOptions DSL: the JDK
// on this machine is 27, which Kotlin doesn't know yet and silently targets
// 25 instead, which then conflicts with javac's target 17 above.
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("squash.analyzer.ui:SquashAnalyzerUI") {
        // Skip exports its test runner transitively. Keep it out of the app:
        // otherwise instrumentation strips these classes from the test APK,
        // breaking ActivityScenario's separate bootstrap activity process.
        exclude(group = "androidx.test")
        exclude(group = "androidx.test.ext")
        exclude(group = "androidx.test.espresso")
    }
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    // Automatic backups write into a folder the user picks (Storage Access Framework)
    implementation("androidx.documentfile:documentfile:1.0.1")

    val roomVersion = "2.8.5"
    implementation("androidx.room:room-runtime:$roomVersion")
    implementation("androidx.room:room-ktx:$roomVersion")
    ksp("androidx.room:room-compiler:$roomVersion")

    testImplementation("junit:junit:4.13.2")
    testImplementation("androidx.room:room-testing:$roomVersion")
    testImplementation("org.robolectric:robolectric:4.16.1")
    // Local HTTP server for HttpLeaguePageLoaderTest (same OkHttp version as Skip)
    testImplementation("com.squareup.okhttp3:mockwebserver3:5.3.2")
    testImplementation("androidx.test:core:1.7.0")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")

    androidTestImplementation(platform("androidx.compose:compose-bom:2026.05.01"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    // createComposeRule() (no host Activity, used by CourtViewTest to mount a
    // view in isolation) needs a plain ComponentActivity to launch into; this
    // pulls in the generated test-only manifest that declares one.
    debugImplementation("androidx.compose.ui:ui-test-manifest")
    // Compose's older transitive Espresso uses a removed InputManager API on API 36.
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")
    androidTestImplementation("androidx.test.espresso:espresso-intents:3.7.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}
