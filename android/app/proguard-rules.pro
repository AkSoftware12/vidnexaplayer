# R8 / ProGuard rules for release builds.
#
# Referenced by android/app/build.gradle's release `proguardFiles`. Flutter
# plugins ship their own consumer-rules.txt inside their AARs (Play Core,
# Firebase, media_kit, etc.), so this file only carries what R8 cannot infer.

# ---------------------------------------------------------------------------
# Flutter engine + embedding.
#
# Crash 1: MainActivity.onCreate -> ExecutionException "Could not find
# 'libflutter.so'". The embedding resolves a lot of its own classes
# reflectively (FlutterActivity/FlutterFragmentActivity lookups, the
# JNI <-> Dart plugin registrant, deferred-component handling), and with
# `proguard-android-optimize.txt` R8 was free to rename or strip them. The
# failure then surfaces from native init rather than from a NoClassDefFound,
# which is why the stack trace points at the .so instead of at the real cause.
# ---------------------------------------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Anything reached only from JNI. Without this R8 can strip the Java side of a
# native callback and leave the engine calling into nothing.
-keepclasseswithmembernames class * {
    native <methods>;
}

# The generated plugin registrant is instantiated by name from the engine.
-keep class com.vidnexa.videoplayer.** { *; }

# ---------------------------------------------------------------------------
# Play Core / deferred components. The Flutter embedding references these even
# when the app never uses deferred components; without the -dontwarn R8 fails
# the build (or, with warnings suppressed globally, silently drops them).
# ---------------------------------------------------------------------------
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ---------------------------------------------------------------------------
# Crashlytics: keep line numbers and source file names so the release stack
# traces stay symbolicated and readable in the console.
# ---------------------------------------------------------------------------
-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature,Exceptions,InnerClasses
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Kotlin metadata / coroutines used reflectively by several plugins.
-keep class kotlin.Metadata { *; }
-dontwarn kotlinx.coroutines.**

# ---------------------------------------------------------------------------
# Apache Tika (pulled in transitively for MIME/metadata detection) compiles
# against the full StAX API. Android's runtime ships no `javax.xml.stream`, so
# R8 failed :app:minifyReleaseWithR8 with
#   Missing class javax.xml.stream.XMLStreamException
#     (referenced from org.apache.tika.utils.XMLReaderUtils)
# Tika only reaches that path for XML container formats the app never opens,
# so warning off the whole package is safe -- the classes were never going to
# resolve on any Android device regardless of shrinking.
# ---------------------------------------------------------------------------
-dontwarn javax.xml.stream.**
-dontwarn org.apache.tika.**
