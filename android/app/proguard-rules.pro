# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }

# TFLite
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.support.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }

# Preserve ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }

# Image processing
-keep class com.google.android.gms.vision.** { *; }

# Fixing Plugin Specific Issues (TTS, Audioplayers, Camera)
-dontwarn com.eyedeadevelopment.fluttertts.**
-dontwarn xyz.luan.audioplayers.**
-dontwarn io.flutter.plugins.camera.**
-dontwarn com.google.android.play.core.**

# General suppression for missing classes in plugins
-dontwarn **
