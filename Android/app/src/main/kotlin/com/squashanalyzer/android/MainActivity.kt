package com.squashanalyzer.android

import android.app.Application
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.SystemBarStyle
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import skip.foundation.ProcessInfo
import skip.ui.ColorScheme
import skip.ui.ComposeContext
import skip.ui.PresentationRoot
import skip.ui.UIApplication
import squash.analyzer.ui.AndroidHomeView
import com.squashanalyzer.android.data.AppDatabase
import com.squashanalyzer.android.data.RoomPlayerStore

/** Only the Android lifecycle lives here; the screen is shared SwiftUI. */
class SquashApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ProcessInfo.launch(applicationContext)
    }
}

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        UIApplication.launch(this)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
        )
        val playerStore = RoomPlayerStore(AppDatabase.get(this).playerDao())
        setContent {
            val stateHolder = rememberSaveableStateHolder()
            stateHolder.SaveableStateProvider(true) {
                PresentationRoot(defaultColorScheme = ColorScheme.dark, context = ComposeContext()) { context ->
                    Box(modifier = context.modifier.fillMaxSize()) {
                        AndroidHomeView(playerStore = playerStore).Compose(context = context.content())
                    }
                }
                SideEffect { stateHolder.removeState(true) }
            }
        }
    }
}
