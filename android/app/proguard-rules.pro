## Flutter wrapper — prevent R8 from stripping Flutter engine classes
## used by path_provider_android via JNI (jnigen)
-keep class io.flutter.** { *; }
-keep class io.flutter.util.PathUtils { *; }

## Keep Gson / JSON serialization if used
-keepattributes *Annotation*
-keep class * extends com.google.gson.TypeAdapter

## Google Play Core (deferred components) — not used but referenced by Flutter engine
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
