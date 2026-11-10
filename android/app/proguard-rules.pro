-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**
# Flutter's optional deferred components, which this app doesn't use.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
# shared_preferences_android and the jni package look these up by name through
# JNI, which R8 can't see: renamed, the app hangs at startup. The list comes from
# those packages' generated bindings: check it when they update.
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
-keep class kotlin.enums.EnumEntries { *; }
-keep class kotlin.jvm.internal.DefaultConstructorMarker { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
