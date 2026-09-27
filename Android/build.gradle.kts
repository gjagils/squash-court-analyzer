// AGP 9's built-in Kotlin isn't compatible with KSP yet (Room needs KSP), so
// this project opts out via android.builtInKotlin=false in gradle.properties
// and applies the classic org.jetbrains.kotlin.android plugin instead.
plugins {
    id("com.android.application") version "9.2.0" apply false
    id("org.jetbrains.kotlin.android") version "2.3.0" apply false
    id("com.google.devtools.ksp") version "2.3.0" apply false
}
