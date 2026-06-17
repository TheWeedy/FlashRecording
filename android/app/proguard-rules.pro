# Keep Flutter engine/plugin entry points while allowing normal shrinking.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class androidx.lifecycle.DefaultLifecycleObserver

# Keep classes for flutter_local_notifications plugin
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class dexposed.flutterlocalnotifications.** { *; }

-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# RecordMyTime only enables Chinese/Latin OCR by default and optionally Japanese.
# The ML Kit Flutter plugin references every script class, so silence R8 for
# unused OCR model packages that are not bundled.
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.korean.**
