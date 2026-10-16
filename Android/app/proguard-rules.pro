# R8 keep rules for the release build (docs/android-port.md, "R8 in de
# release-build"). Debug builds are not shrunk; every change here needs a test
# pass of the release APK on the emulator, because a missing rule only shows
# up at runtime (ClassNotFoundException, NoSuchMethodError, an empty screen).
#
# Libraries that ship their own consumer rules inside their AAR are not
# repeated here: Room (the generated AppDatabase_Impl that Room finds by
# name), Firebase Messaging, AndroidX, Compose, OkHttp, Coil and kotlinx.
# R8 applies those automatically.

# --- Skip runtime ----------------------------------------------------------
# The same rules Skip writes into the proguard-rules.pro of a new Skip app
# (skip init, SkipDrive's project template). The Skip libraries reflect on
# themselves and on generated code, and look up resources by package path
# (assets/squash/analyzer/ui/Resources/... via _ModuleBundleAccessor_), so
# package names stay and the skip.* libraries stay whole. Everything else is
# still shrunk and obfuscated (Compose, the material icons, AndroidX, OkHttp,
# Firebase), which is where the size goes.
-keeppackagenames **
-keep class skip.** { *; }
-keep class tools.skip.** { *; }
-keep class kotlin.jvm.functions.** { *; }
-keep class com.sun.jna.** { *; }
-dontwarn java.awt.**
-keep class * implements com.sun.jna.** { *; }
-keep class * implements skip.bridge.** { *; }
-keep class **._ModuleBundleAccessor_* { *; }

# --- Transpiled app code (Packages/SquashAnalyzerCore and SquashAnalyzerUI) --
# Skip's template keeps the app's own package whole too. This is the Kotlin
# that Skip generates from our Swift: Codable types (backups, the live share
# JSON, the competition file) are encoded through generated CodingKeys and
# Skip's reflective helpers, and SwiftUI views are looked up by type. Kept
# whole for correctness; it is our own code, so not obfuscating it costs
# nothing in privacy and little in size.
-keep class squash.analyzer.** { *; }

# --- Attributes ------------------------------------------------------------
# Generic signatures and annotations: Skip and Kotlin reflection read them
# (e.g. the element type of a decoded array), and Room/Compose need them.
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*
# Readable line numbers in Play Console crash reports (with mapping.txt,
# uploaded by scripts/play_upload.py); the source file name is hidden.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
