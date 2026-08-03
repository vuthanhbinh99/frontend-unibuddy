package com.example.unibuddy

import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
	private val CHANNEL = "unibuddy/local_file"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"readContentUri" -> {
					val uriString = call.argument<String>("uri")
					if (uriString == null) {
						result.error("invalid_args", "Missing uri", null)
						return@setMethodCallHandler
					}

					try {
						val uri = Uri.parse(uriString)
						val input = contentResolver.openInputStream(uri)
						if (input == null) {
							result.error("io_error", "Unable to open input stream for uri", null)
							return@setMethodCallHandler
						}
						val buffer = ByteArrayOutputStream()
						val data = ByteArray(4096)
						var read = input.read(data)
						while (read != -1) {
							buffer.write(data, 0, read)
							read = input.read(data)
						}
						input.close()
						result.success(buffer.toByteArray())
					} catch (e: Exception) {
						result.error("exception", e.message, null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}
}
