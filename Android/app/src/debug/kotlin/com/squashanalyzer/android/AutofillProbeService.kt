package com.squashanalyzer.android

import android.app.assist.AssistStructure
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.util.Log
import android.view.View
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews

/**
 * Debug only: an autofill service that offers "PROBE" on every text field it
 * is shown and logs them, to see which fields take part in autofill without a
 * Google account with a saved password (docs/skip-valkuilen.md).
 *
 *     adb shell settings put secure autofill_service <package>/com.squashanalyzer.android.AutofillProbeService
 *     adb logcat -s AutofillProbe
 */
class AutofillProbeService : AutofillService() {
    override fun onFillRequest(request: FillRequest, cancellationSignal: CancellationSignal, callback: FillCallback) {
        val structure = request.fillContexts.last().structure
        val fields = mutableListOf<Pair<AutofillId, String>>()
        for (i in 0 until structure.windowNodeCount) collect(structure.getWindowNodeAt(i).rootViewNode, fields)
        Log.i("AutofillProbe", "fill request: ${fields.size} text field(s) " + fields.joinToString { it.second })
        if (fields.isEmpty()) {
            callback.onSuccess(null)
            return
        }
        val response = FillResponse.Builder()
        for ((id, _) in fields) {
            val label = RemoteViews(packageName, android.R.layout.simple_list_item_1)
            label.setTextViewText(android.R.id.text1, "PROBE")
            @Suppress("DEPRECATION")
            response.addDataset(Dataset.Builder().setValue(id, AutofillValue.forText("PROBE"), label).build())
        }
        callback.onSuccess(response.build())
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        callback.onSuccess()
    }

    private fun collect(node: AssistStructure.ViewNode, into: MutableList<Pair<AutofillId, String>>) {
        val id = node.autofillId
        if (id != null && node.autofillType == View.AUTOFILL_TYPE_TEXT) {
            into.add(id to "[hints=${node.autofillHints?.joinToString("+") ?: "-"} text=${node.text ?: node.contentDescription ?: ""}]")
        }
        for (i in 0 until node.childCount) collect(node.getChildAt(i), into)
    }
}
