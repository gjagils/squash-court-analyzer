package com.squashanalyzer.android

import android.app.Activity
import android.os.Build
import android.view.View
import android.view.ViewTreeObserver
import android.view.inspector.WindowInspector
import java.util.WeakHashMap

/**
 * Keeps the password manager away from name fields.
 *
 * Compose reports every text field to Android autofill, with or without a
 * content type, and its own view always answers "important for autofill". A
 * password manager then guesses, and offers the saved account password on a
 * player name. Only a parent that excludes its descendants keeps a field out,
 * so every window of the app (a sheet is a window of its own) gets that on its
 * root view. While the sign-in form of Mijn account is on screen the windows
 * take part again; those two fields say what they are (textContentType).
 */
object AutofillGate {
    private var activityRoot: View? = null
    private val watched = WeakHashMap<View, ViewTreeObserver.OnWindowFocusChangeListener>()
    private var loginVisible = false

    fun install(activity: Activity) {
        activityRoot = activity.window.decorView
        apply()
    }

    fun uninstall(activity: Activity) {
        if (activityRoot === activity.window.decorView) activityRoot = null
    }

    /** The sign-in form (e-mail address and password) came on screen or left it */
    fun setLoginVisible(visible: Boolean) {
        loginVisible = visible
        apply()
    }

    private fun apply() {
        val importance = if (loginVisible) View.IMPORTANT_FOR_AUTOFILL_AUTO
            else View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
        for (root in windowRoots()) {
            if (root.importantForAutofill != importance) root.importantForAutofill = importance
            watch(root)
        }
    }

    /** Every window of the app; before Android 10 only the Activity's own */
    private fun windowRoots(): List<View> {
        val roots = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) WindowInspector.getGlobalWindowViews() else emptyList()
        val own = activityRoot
        return if (own != null && !roots.contains(own)) roots + own else roots
    }

    /** A new window (sheet, dialog) takes the focus from one we know: look again then */
    private fun watch(root: View) {
        if (watched.containsKey(root)) return
        val listener = ViewTreeObserver.OnWindowFocusChangeListener { apply() }
        watched[root] = listener
        root.viewTreeObserver.addOnWindowFocusChangeListener(listener)
    }
}
