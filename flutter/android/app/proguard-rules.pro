# Keep Go JNI bridge class — R8 cannot detect external/native method usage
-keep class com.example.vrgram.GoBridge { *; }
-keepclassmembers class com.example.vrgram.GoBridge { *; }

# Keep all native/JNI methods in the app
-keepclasseswithmembernames class * {
    native <methods>;
}
