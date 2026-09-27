package com.squashanalyzer.android

import android.os.Bundle
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

/**
 * Bare placeholder activity for the Android port's phase 3 (storage). It exists
 * only so the Room persistence layer in `data/` has a real Android application
 * to compile and run inside — no actual screen work happens until phase 4
 * (see docs/android-port.md in the repo root).
 */
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(TextView(this).apply {
            text = "Squash Analyzer — Android (fase 3: opslag)"
            textSize = 18f
            setPadding(48, 96, 48, 48)
        })
    }
}
