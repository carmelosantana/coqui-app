package dev.ibrahimcetin.reins

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.system.exitProcess

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "coqui/app")
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"isRestartSupported" -> result.success(true)
					"restartApplication" -> {
						result.success(true)
						restartApplication()
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun restartApplication() {
		val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
		} ?: return

		startActivity(launchIntent)
		finishAffinity()
		exitProcess(0)
	}
}
