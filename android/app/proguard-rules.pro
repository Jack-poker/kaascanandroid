-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Keep ML Models and Flatbuffers
-keep class com.google.flatbuffers.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep public class org.tensorflow.lite.TFLite { *; }

# Keep Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# AndroidX
-keep class androidx.** { *; }
-dontwarn androidx.**

# Kotlin
-keep class kotlin.** { *; }
# POS Extensions and Mocks
-keep class com.google.appinventor.** { *; }
-keep class com.baztibiza.** { *; }
-keep class com.akg.** { *; }
-keep class com.kaascan.application.PosExtensionBridge { *; }
-dontwarn com.google.appinventor.**
-dontwarn com.baztibiza.**
-dontwarn com.akg.**

