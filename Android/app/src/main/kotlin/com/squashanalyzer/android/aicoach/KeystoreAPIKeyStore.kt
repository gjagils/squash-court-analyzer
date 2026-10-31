package com.squashanalyzer.android.aicoach

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import squash.analyzer.core.AccountSecretStore
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
    private val sealed = KeystoreSealedText(context, ALIAS, KEY)

    override var openAIAPIKey: String?
        get() = sealed.value
        set(value) { sealed.value = value }

    companion object {
        private const val ALIAS = "squashanalyzer.openai"
        const val PREFS = KeystoreSealedText.PREFS
        private const val KEY = "openai_api_key"
    }
}

/**
 * 4.0, the player account (Core's `PlayerAccount`): the Firebase refresh token
 * and the device key, sealed the same way as the OpenAI key, under a Keystore
 * key of their own. The counterpart of iOS' `KeychainAccountSecrets`.
 */
class KeystoreAccountSecrets(context: Context) : AccountSecretStore {
    private val sealed = KeystoreSealedText(context, "squashanalyzer.account", "account_secrets")

    override var accountSecrets: String?
        get() = sealed.value
        set(value) { sealed.value = value }
}

/** One text, AES-GCM-sealed with a Keystore key (`alias`), the ciphertext under `key` in SharedPreferences */
class KeystoreSealedText(context: Context, private val alias: String, private val key: String) {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    var value: String?
        get() = synchronized(LOCK) { read() }
        set(value) = synchronized(LOCK) {
            // A failed write empties the value on purpose ("not set", not a stale old value): docs/bewuste-keuzes.md
            if (value.isNullOrEmpty() || !write(value)) prefs.edit().remove(key).apply()
        }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (keyStore.getKey(alias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return generator.generateKey()
    }

    /**
     * False when the Keystore refused (locked, broken or missing, as on some
     * devices and in tests); the caller then clears the old value, so reading
     * back says "not set" and Instellingen shows "Opslaan is niet gelukt"
     * instead of crashing or keeping a stale key.
     */
    private fun write(value: String): Boolean = try {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val sealed = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        prefs.edit().putString(key, Base64.encodeToString(sealed, Base64.NO_WRAP)).apply()
        true
    } catch (e: Exception) {
        false
    }

    /** Nil when nothing is stored or the value cannot be decrypted (e.g. a new Keystore key) */
    private fun read(): String? {
        val stored = prefs.getString(key, null) ?: return null
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
        /** One lock for every instance: they share the same preferences and Keystore entry */
        private val LOCK = Any()
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val IV_LENGTH = 12
        const val PREFS = "squash-analyzer-secure"
    }
}
