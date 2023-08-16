# Build the ephemeral app in a module project.
# Prevents: Warning: library class <plugin-package> depends on program class io.flutter.plugin.**
# This is due to plugins (libraries) depending on the embedding (the program jar)

-keep class com.netease.lava.** { *; }

### NIM SDK
-dontwarn com.netease.**
-keep class com.netease.** {*;}
-dontwarn org.apache.lucene.**
-keep class org.apache.lucene.** {*;}
-keep class net.sqlcipher.** {*;}

### 美颜 SDK
-keep class com.faceunity.wrapper.faceunity {*;}
-keep class com.faceunity.wrapper.faceunity$RotatedImage {*;}


### Android 6兼容 androidx
-dontwarn org.xmlpull.v1.XmlPullParser
-dontwarn org.xmlpull.v1.XmlSerializer
-keep class org.xmlpull.v1.* {*;}

### Bugly
-dontwarn com.tencent.bugly.**
-keep public class com.tencent.bugly.**{*;}
