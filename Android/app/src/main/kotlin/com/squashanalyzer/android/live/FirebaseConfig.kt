package com.squashanalyzer.android.live

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.squashanalyzer.android.BuildConfig
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * Firebase for the live score pushes only. The values come from
 * ~/.android-keys/google-services.json at build time (app/build.gradle.kts);
 * a build without that file has empty values and no pushes.
 */
object FirebaseConfig {
    val isAvailable: Boolean
        get() = BuildConfig.FIREBASE_APP_ID.isNotEmpty() && BuildConfig.FIREBASE_API_KEY.isNotEmpty()

    /** In Application.onCreate, before a FirebaseMessagingService can run */
    fun initialize(context: Context) {
        if (!isAvailable || FirebaseApp.getApps(context).isNotEmpty()) return
        val options = FirebaseOptions.Builder()
            .setProjectId(BuildConfig.FIREBASE_PROJECT_ID)
            .setApplicationId(BuildConfig.FIREBASE_APP_ID)
            .setApiKey(BuildConfig.FIREBASE_API_KEY)
            .setGcmSenderId(BuildConfig.FIREBASE_SENDER_ID)
            .build()
        try {
            FirebaseApp.initializeApp(context, options)
        } catch (e: Exception) {
            android.util.Log.w("LiveFollow", "Firebase niet gestart", e)
        }
    }

    /** This device's FCM token, or null (no Firebase, no Google Play services, no network) */
    suspend fun token(): String? {
        if (!isAvailable) return null
        return try {
            suspendCancellableCoroutine { continuation ->
                FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                    continuation.resume(if (task.isSuccessful) task.result else null)
                }
            }
        } catch (e: Exception) {
            null
        }
    }
}
