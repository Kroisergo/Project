package com.example.encryvault

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val screenProtectionChannel = "encryvault/screen_protection"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenProtectionChannel)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "enableProtection" -> {
            runOnUiThread {
              window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
            result.success(null)
          }

          "disableProtection" -> {
            runOnUiThread {
              window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
            result.success(null)
          }

          else -> result.notImplemented()
        }
      }
  }
}
