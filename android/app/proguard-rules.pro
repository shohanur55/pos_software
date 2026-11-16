# Suppress missing class warnings for optional Google Play Core & Flutter internal dependencies
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.**

# Flutter Wrapper Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Background Downloader
-keep class com.bbflight.background_downloader.** { *; }

# Sqflite
-keep class com.tekartik.sqflite.** { *; }

# Webview Flutter
-keep class io.flutter.plugins.webviewflutter.** { *; }

# Connectivity Plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }
