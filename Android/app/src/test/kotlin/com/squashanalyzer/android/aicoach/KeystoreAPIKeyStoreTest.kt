package com.squashanalyzer.android.aicoach

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Robolectric has no Android Keystore, so this is the "Keystore refuses" case
 * of a real phone: saving must not crash, and must not leave an old key behind.
 */
@RunWith(RobolectricTestRunner::class)
class KeystoreAPIKeyStoreTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    @Before fun clean() {
        context.getSharedPreferences(KeystoreAPIKeyStore.PREFS, Context.MODE_PRIVATE).edit().clear().commit()
    }

    @Test fun aRefusedSaveDoesNotCrashAndReadsAsNotSet() {
        val store = KeystoreAPIKeyStore(context)
        store.openAIAPIKey = "sk-test"
        assertNull(store.openAIAPIKey)
    }

    @Test fun aRefusedSaveClearsAnOlderValue() {
        context.getSharedPreferences(KeystoreAPIKeyStore.PREFS, Context.MODE_PRIVATE).edit()
            .putString("openai_api_key", "oude-versleutelde-waarde").commit()
        val store = KeystoreAPIKeyStore(context)
        store.openAIAPIKey = "sk-nieuw"
        assertFalse(context.getSharedPreferences(KeystoreAPIKeyStore.PREFS, Context.MODE_PRIVATE).contains("openai_api_key"))
    }

    @Test fun removingTheKeyWorks() {
        val store = KeystoreAPIKeyStore(context)
        store.openAIAPIKey = null
        assertNull(store.openAIAPIKey)
    }

    /** 4.0: the account's secrets go the same way, under their own key, and leave the OpenAI key alone */
    @Test fun accountSecretsKeepApartFromTheApiKey() {
        val prefs = context.getSharedPreferences(KeystoreAPIKeyStore.PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString("openai_api_key", "versleuteld").commit()
        val secrets = KeystoreAccountSecrets(context)
        secrets.accountSecrets = "{\"session\":null}"
        assertNull(secrets.accountSecrets)
        assertFalse(prefs.contains("account_secrets"))
        assertTrue(prefs.contains("openai_api_key"))
    }
}
