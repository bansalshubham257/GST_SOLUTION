package com.gstsolution.gst_solution

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val VOICE_CHANNEL = "com.gstsolution.gst_solution/voice"
        private const val REQUEST_CODE_SPEECH = 1001
    }

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOICE_CHANNEL
        ).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "startVoiceInput" -> {
                    val prompt = call.argument<String>("prompt") ?: "Speak now..."
                    startVoiceInput(prompt, result)
                }
                "isAvailable" -> {
                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                    val available = intent.resolveActivity(packageManager) != null
                    result.success(available)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startVoiceInput(prompt: String, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("BUSY", "Another voice request is in progress", null)
            return
        }
        try {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "en-IN")
                putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            }
            pendingResult = result
            startActivityForResult(intent, REQUEST_CODE_SPEECH)
        } catch (e: Exception) {
            pendingResult = null
            result.error("UNAVAILABLE", "Voice recognition not available: ${e.message}", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_SPEECH) {
            val result = pendingResult
            pendingResult = null
            when (resultCode) {
                Activity.RESULT_OK -> {
                    val matches = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                    val text = matches?.firstOrNull() ?: ""
                    result?.success(text)
                }
                Activity.RESULT_CANCELED -> result?.success("")
                else -> result?.error("ERROR", "Speech recognition failed", null)
            }
        }
    }
}
