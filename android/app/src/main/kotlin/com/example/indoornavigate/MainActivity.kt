package com.example.indoornavigate

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
	private val ROTATION_CHANNEL = "com.example.indoornavigate/rotation"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		val stream = RotationVectorStream(this)
		EventChannel(flutterEngine.dartExecutor.binaryMessenger, ROTATION_CHANNEL).setStreamHandler(stream)
	}
}
