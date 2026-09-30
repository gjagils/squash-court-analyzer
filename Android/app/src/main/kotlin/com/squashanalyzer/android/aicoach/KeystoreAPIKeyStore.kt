package com.squashanalyzer.android.aicoach

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import squash.analyzer.core.APIKeyStore
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * The OpenAI API key on Android, the counterpart of iOS' Keychain-backed
 * `APIKeyManager`: encrypted with an AES-GCM key that never leaves the
 * Android Keystore, and only the ciphertext kept in SharedPreferences.
 * (androidx.security-crypto's EncryptedSharedPreferences is deprecated,
 * hence this small class.) The Keystore key never leaves the device, so a
 * ciphertext restored from a backup onto another phone cannot be decrypted;
 * the key then simply reads as not set and can be entered again.
 */
class KeystoreAPIKeyStore(context: Context) : APIKeyStore {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    override var openAIAPIKey: String?
        get() = synchronized(this) { read() }
        set(value) = synchronized(this) {
            if (value.isNullOrEmpty()) prefs.edit().remove(KEY).apply() else write(value)
        }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (keyStore.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return generator.generateKey()
    }

    private fun write(value: String) {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val sealed = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        prefs.edit().putString(KEY, Base64.encodeToString(sealed, Base64.NO_WRAP)).apply()
    }

    /** Nil when nothing is stored or the value cannot be decrypted (e.g. a new Keystore key) */
    private fun read(): String? {
        val stored = prefs.getString(KEY, null) ?: return null
        return try {
            val sealed = Base64.decode(stored, Base64.NO_WRAP)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, sealed, 0, IV_LENGTH))
            String(cipher.doFinal(sealed, IV_LENGTH, sealed.size - IV_LENGTH), Charsets.UTF_8)
        } catch (e: Exception) {
            null
        }
    }

    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val ALIAS = "squashanalyzer.openai"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val IV_LENGTH = 12
        const val PREFS = "squash-analyzer-secure"
        private const val KEY = "openai_api_key"
    }
}
