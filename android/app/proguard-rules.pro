# Keep Flutter entrypoints and plugin registrant classes used by reflection.
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Preserve generic type signatures and annotations that some libraries inspect.
-keepattributes Signature
-keepattributes *Annotation*

# Flutter embedding references Play Core deferred component APIs. This app
# does not use deferred components, so suppress missing optional classes.
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
