# -- Flutter -------------------------------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# -- Firebase ------------------------------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# -- Firebase Firestore --------------------------------------------------------
-keep class com.google.firestore.** { *; }

# -- Firebase Auth / Google Sign-In --------------------------------------------
-keep class com.google.android.gms.auth.** { *; }

# -- Firebase App Check --------------------------------------------------------
-keep class com.google.firebase.appcheck.** { *; }

# -- Firebase Cloud Messaging --------------------------------------------------
-keep class com.google.firebase.messaging.** { *; }

# -- Kotlin / Coroutines -------------------------------------------------------
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# -- Prevent stripping JSON serialization -------------------------------------
-keepattributes EnclosingMethod
-keepattributes InnerClasses
