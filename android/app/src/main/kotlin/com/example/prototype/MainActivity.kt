package com.example.prototype

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity: FlutterActivity() {
    private val CHANNEL = "sms_channel"
    private val SMS_PERMISSIONS_REQUEST = 101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestSmsPermissions" -> {
                    requestSmsPermissions()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestSmsPermissions() {
        val permissions = arrayOf(
            Manifest.permission.READ_SMS,
            Manifest.permission.RECEIVE_SMS,
            Manifest.permission.SEND_SMS
        )

        ActivityCompat.requestPermissions(this, permissions, SMS_PERMISSIONS_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        when (requestCode) {
            SMS_PERMISSIONS_REQUEST -> {
                val granted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                // Handle permission result through method channel
                MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger!!, CHANNEL)
                    .invokeMethod("onSmsPermissionsResult", granted)
            }
            else -> super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }
}
